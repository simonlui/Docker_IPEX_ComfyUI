#!/bin/sh
CONTAINER_ALREADY_STARTED=/tmp/CONTAINER_ALREADY_STARTED_PLACEHOLDER
# Setup Python virtual environment if we don't see anything there as in a first launch run or if the repository does not exist.
if [ ! -e $CONTAINER_ALREADY_STARTED ]
then
    echo "First time launching container, setting things up."
    python3 -m venv "$VENVDir"
    # Clone repository if we have an empty space available.
    git rev-parse --git-dir > /dev/null 2>&1 || git clone https://github.com/comfyanonymous/ComfyUI.git .
    git config core.filemode false
    FirstLaunch=true
    # Make a file in /tmp/ to indicate the first launch step has been executed.
    touch "$CONTAINER_ALREADY_STARTED"
fi

# Activate the virtual environment to use for ComfyUI
if [ -f "$VENVDir"/bin/activate ]
then
    echo "Activating python venv."
    . "$VENVDir"/bin/activate
    . /opt/intel/oneapi/pytorch-gpu-dev-0.5/oneapi-vars.sh
    . /opt/intel/oneapi/pti/latest/env/vars.sh
else
    echo "Error: Cannot activate python venv. Check installation. Exiting immediately."
    exit 1
fi

# Install pip requirements if launching for the first time.
if [ "$FirstLaunch" = "true" ]
then
    echo "Installing ComfyUI Python dependencies."
    python -m pip install torch==2.5.0.dev20240912+xpu torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/xpu
    pip install -r requirements.txt
fi

# Launch ComfyUI based on whether ipexrun is set to be used or not. Explicit string splitting is done by the shell here so shellcheck warning is ignored.
if [ "$UseIPEXRUN" = "true" ] && [ "$UseXPU" = "true" ]
then
    echo "Using ipexrun xpu to launch ComfyUI."
    # shellcheck disable=SC2086
    exec ipexrun xpu $IPEXRUNArgs main.py $ComfyArgs
elif [ "$UseIPEXRUN" = "true" ] && [ "$UseXPU" = "false" ]
then
    echo "Using ipexrun cpu to launch ComfyUI."
    # shellcheck disable=SC2086
    exec ipexrun $IPEXRUNArgs main.py $ComfyArgs
else
    echo "No command to use ipexrun to launch ComfyUI. Launching normally."
    # shellcheck disable=SC2086
    python3 main.py $ComfyArgs
fi
