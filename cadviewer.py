"""
nicegui cadviewer

name: cadviewer.py
by:   jdegenstein
date: January 24, 2025

desc:

This module creates a graphical window with a text editor and CAD viewer (based on ocp_vscode). 
The graphical user interface is based on nicegui and spawns the necessary subprocess and allows
for re-running the user-supplied script and displaying the results.

Key Features:
  - Has a run button for executing user code
  - Has a keyboard shortcut of CTRL-Enter to run the user code

license:

    Copyright 2025 jdegenstein

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

"""

# Set environment variable before any imports
import os
os.environ['OCP_VSCODE_LOCK_DIR'] = '/tmp/ocpvscode'

import logging
import time

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Log environment setup
logger.info(f"Using lock directory: {os.environ['OCP_VSCODE_LOCK_DIR']}")
logger.info(f"Current working directory: {os.getcwd()}")
logger.info(f"Directory contents of lock dir parent: {os.listdir(os.path.dirname(os.environ['OCP_VSCODE_LOCK_DIR']))}")
logger.info(f"Lock dir exists: {os.path.exists(os.environ['OCP_VSCODE_LOCK_DIR'])}")
if os.path.exists(os.environ['OCP_VSCODE_LOCK_DIR']):
    logger.info(f"Lock dir permissions: {oct(os.stat(os.environ['OCP_VSCODE_LOCK_DIR']).st_mode)[-3:]}")

from nicegui import app, ui
from nicegui.events import KeyEventArguments
import subprocess

app.native.window_args["resizable"] = True
app.native.start_args["debug"] = True
# app.native.settings['ALLOW_DOWNLOADS'] = True # export "downloads" ?
app.native.settings["MATPLOTLIB"] = False

editor_fontsize = 18
# TODO: consider separate editor execution thread from nicegui thread

# Global variables to track viewer and connection state
viewer_initialized = False
viewer_ready = False

# run ocp_vscode in a subprocess
def startup_all():
    global ocpcv_proc, viewer_initialized
    try:
        logger.info("Starting ocp_vscode subprocess")
        # spawn separate viewer process
        env = os.environ.copy()  # Copy current environment
        logger.info(f"Subprocess environment OCP_VSCODE_LOCK_DIR: {env['OCP_VSCODE_LOCK_DIR']}")
        ocpcv_proc = subprocess.Popen(["python", "-m", "ocp_vscode", "--host", "0.0.0.0"], env=env)
        logger.info("ocp_vscode subprocess started")
        
        # pre-import build123d and ocp_vscode in main thread
        logger.info("Importing build123d and ocp_vscode in main thread")
        exec("from build123d import *\nfrom ocp_vscode import *")
        logger.info("Imports completed")
        
        # Wait for viewer to initialize
        logger.info("Waiting for viewer to initialize...")
        time.sleep(3)  # Give more time for the viewer to start
        viewer_initialized = True
        logger.info("Viewer initialization complete")
    except Exception as e:
        logger.error(f"Error in startup: {str(e)}", exc_info=True)
        raise

def check_viewer_ready():
    """Check if the viewer is ready by attempting a test connection"""
    try:
        import requests
        response = requests.get('http://0.0.0.0:3939/viewer')
        return response.status_code == 200
    except:
        return False

def button_run_callback():
    try:
        if not viewer_initialized:
            logger.warning("Viewer not initialized yet, please wait...")
            return
            
        # Add a check for viewer readiness
        if not check_viewer_ready():
            logger.warning("Viewer not ready yet, please wait a moment and try again...")
            return

        # Add a delay to ensure WebSocket connection is established
        time.sleep(1)  # Increased delay for WebSocket setup
        
        logger.info("Executing user code")
        # Create a clean namespace for execution
        namespace = {}
        exec("from build123d import *\nfrom ocp_vscode import *", namespace)
        exec("set_defaults(reset_camera=Camera.KEEP)\nset_port(3939)", namespace)
        
        # Wrap the user code execution in a try-except block
        try:
            exec(code.value, namespace)
            logger.info("User code execution completed successfully")
        except Exception as e:
            logger.error(f"Error in user code: {str(e)}")
            raise
            
    except Exception as e:
        logger.error(f"Error executing user code: {str(e)}", exc_info=True)
        raise


def shutdown_all():
    try:
        logger.info("Shutting down ocp_vscode subprocess")
        ocpcv_proc.kill()
        logger.info("ocp_vscode subprocess terminated")
        app.shutdown()
    except Exception as e:
        logger.error(f"Error in shutdown: {str(e)}", exc_info=True)
        raise


app.on_startup(startup_all)

button_frac = 0.05


with ui.splitter().classes(
    "w-full h-[calc(100vh-2rem)] no-wrap items-stretch border"
) as splitter:
    with splitter.before:
        with ui.column().classes("w-full items-stretch border"):
            with ui.row():
                with ui.column().classes("w-1/3"):
                    ui.button(
                        "Run Code", icon="send", on_click=lambda: button_run_callback()
                    ).classes(f"h-[calc(100vh*{button_frac}-3rem)]")
            # ui.button('shutdown', on_click=lambda: shutdown_all()) # just close the window
            code = (
                ui.codemirror(
                    'print("Edit me!")\nprint("hello world")',
                    language="Python",
                    theme="vscodeLight",
                )
                .classes(f"h-[calc(100vh*{1-button_frac}-3rem)]")
                .style(f"font-size: {editor_fontsize}px")
            )
    with splitter.after:
        with ui.column().classes("w-full items-stretch border"):
            # Add a small delay before loading the iframe
            ui.timer(3.0, lambda: None, once=True)  # Wait for viewer to be ready
            ocpcv = (
                ui.element("iframe")
                .props('src="http://0.0.0.0:3939/viewer"')
                .classes("h-[calc(100vh-3rem)]")
            )


# handle the CTRL + Enter run shortcut:
def handle_key(e: KeyEventArguments):
    if e.modifiers.ctrl and e.action.keydown:
        if e.key.enter:
            button_run_callback()


keyboard = ui.keyboard(on_key=handle_key)
# TODO: consider separating this module and how best to organize it (if name == main, etc.)
app.on_shutdown(shutdown_all)  # register shutdown handler
ui.run(
    native=False,  # Changed from True to False for web deployment
    host='0.0.0.0',  # Listen on all interfaces
    port=7860,  # Use port 7860 for Spaces
    title="nicegui-cadviewer",
    reload=False
)
# ui.run(native=True, window_size=(1800, 900), fullscreen=False, reload=True) #use reload=True when developing rapidly, False helps exit behavior

# layout info https://github.com/zauberzeug/nicegui/discussions/1937
