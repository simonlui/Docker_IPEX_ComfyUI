#!/bin/sh
# Setup Python virtual environment if we don't see anything there as in a first launch run.
if [ ! -d "$VENVDir" ]
then
    python3 -m venv "$VENVDir"
    FirstLaunch="true"
fi
# Activate the virtual environment to use for ComfyUI
if [ -f "$VENVDir"/bin/activate ]
then
    # shellcheck disable=SC1091
    . "$VENVDir"/bin/activate
else
    echo "Error: Cannot activate python venv. Check installation. Exiting immediately."
    exit 1
fi
# Install pip requirements if launching for the first time.
if [ "$FirstLaunch" = "true" ]
then
    #pip install torch==2.0.1a0 torchvision==0.15.2a0 intel_extension_for_pytorch==2.0.110+xpu -f https://developer.intel.com/ipex-whl-stable-xpu
    pip install https://intel-extension-for-pytorch.s3.amazonaws.com/ipex_stable/xpu/torch-2.0.1a0%2Bcxx11.abi-cp310-cp310-linux_x86_64.whl https://intel-extension-for-pytorch.s3.amazonaws.com/ipex_stable/xpu/torchvision-0.15.2a0%2Bcxx11.abi-cp310-cp310-linux_x86_64.whl https://intel-extension-for-pytorch.s3.amazonaws.com/ipex_stable/xpu/intel_extension_for_pytorch-2.0.110%2Bxpu-cp310-cp310-linux_x86_64.whl
    pip install -r requirements.txt
fi
# Launch ComfyUI based on whether ipexrun is set to be used or not. Explicit string splitting is done by the shell here.
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
