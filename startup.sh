#!/bin/sh
# Clone repository if we have an empty space available.
git rev-parse --git-dir > /dev/null 2>&1 || git clone https://github.com/comfyanonymous/ComfyUI.git .
git config core.filemode false
# Setup Python virtual environment if we don't see anything there as in a first launch run.
if [ ! -d "${VENVDir}" ]
then
    python3 -m venv "${VENVDir}"
    FirstLaunch="true"
fi
# Activate the virtual environment to use for ComfyUI
if [ -f ${VENVDir}/bin/activate ]
then
    . ${VENVDir}/bin/activate
else
    echo "Error: Cannot activate python venv. Check installation. Exiting immediately."
    exit 1
fi
# Install pip requirements if launching for the first time.
if [ "${FirstLaunch}" = "true" ]
then
    pip install torch==2.0.1a0 torchvision==0.15.2a0 intel_extension_for_pytorch==2.0.110+xpu -f https://developer.intel.com/ipex-whl-stable-xpu
    pip install -r requirements.txt
fi
# Launch ComfyUI based on whether ipexrun is set to be used or not.
if [ "${UseIPEXRUN}" = "true" ] && [ "${UseXPU}" = "true"]
then
    echo "Using ipexrun xpu to launch ComfyUI."
    exec ipexrun xpu --convert-fp64-to-fp32 main.py ${ComfyArgs}
elif [ "${UseXPU}" = "true" ]
then
    echo "Using ipexrun cpu to launch ComfyUI."
    exec ipexrun --multi-task-manager 'taskset' --memory-allocator ${ALLOCATOR} main.py ${ComfyArgs}
else
    echo "No command to use ipexrun to launch ComfyUI. Launching normally."
    python3 main.py ${ComfyArgs}
fi
