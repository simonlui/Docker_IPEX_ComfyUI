# Stable Diffusion ComfyUI Docker/OCI Image for Intel Arc GPUs

This Docker/OCI image is designed to run [ComfyUI](https://github.com/comfyanonymous/ComfyUI) inside a Docker/OCI container for Intel Arc GPUs. This work was based in large part on the work done by a Docker image made by nuullll [here](https://github.com/Nuullll/ipex-sd-docker-for-arc-gpu) for a different Stable Diffusion UI and the official Docker images from the Intel® Extension for PyTorch* xpu-main branch Docker images [here](https://github.com/intel/intel-extension-for-pytorch/tree/xpu-main/docker).

The Docker/OCI image includes
- Intel oneAPI DPC++ runtime libs _(Note: compiler executables are not included)_
- Intel oneAPI MKL runtime libs
- Intel oneAPI compiler common tools like `sycl-ls`
- Intel Graphics driver
- Basic Python virtual environment

Intel Extension for Pytorch (IPEX) and other python packages and dependencies will be installed upon first launch of the container. They will be installed in a Python virtual environment in a separate volume to allow for reuse between containers and to make rebuilding images in between changes a lot faster.

## Prerequisites

* Intel GPU which has support for Intel's oneAPI AI toolkit. According to Intel's support link [here](https://www.intel.com/content/www/us/en/developer/articles/system-requirements/intel-oneapi-ai-analytics-toolkit-system-requirements.html), the following GPUs are supported.
    - Intel® Data Center GPU Flex Series
    - Intel® Data Center GPU Max Series
    - Intel® Arc™ A-Series Graphics

There are reports that Intel® Xe GPUs (iGPU and dGPU) in Tiger Lake (11th generation) and newer Intel processors are also capable of running oneAPI but this has not been tested and it seems to rely on custom compilation of the software yourself. Feel free to file any issues if this is the case as the infrastructure is there for support to be implemented, it seems. Otherwise, any other Intel GPUs are unfortunately not supported and will need to have its support enabled by Intel for oneAPI. If you are in such a position and want to run Stable Diffusion with an older Intel GPU, ComfyUI and this repository won't be able to do that for you at this time but please take a look at Intel's OpenVINO fork of stable-diffusion-webui located [here](https://github.com/openvinotoolkit/stable-diffusion-webui/wiki/Installation-on-Intel-Silicon) for a way to possibly do that.
* Docker (Desktop) or podman
* Linux or Windows, with the latest drivers installed.

Windows should work, but it is highly not recommended to run this unless you have a specific reason to do so i.e. needing a Linux host/userspace to run custom nodes or etc. For most purposes, doing a native install will give better speeds and less headaches. Please follow the install instructions listed in the [ComfyUI README.md](https://github.com/comfyanonymous/ComfyUI/?tab=readme-ov-file#intel-gpus)
* If using Windows, you must have WSL2 set up via [this link](https://learn.microsoft.com/en-us/windows/wsl/install) in addition to Docker to be able to pass through your GPU.

## Build and run the image

Instructions will assume Docker but podman has command compatibility so it should be easy to replace docker in these commands to run also. Run the following command in a terminal to checkout the repository and build the image.
```sh
git clone https://github.com/simonlui/Docker_IPEX_ComfyUI
cd Docker_IPEX_ComfyUI
docker build -t ipex-arc-comfy:latest -f Dockerfile .
```

Once the image build is complete, then run the following if using Linux in terminal or Docker Desktop.
```sh
docker run -it `
--device /dev/dri `
-e ComfyArgs="<ComfyUI command line arguments>" `
--name comfy-server`  
--network=host `
--security-opt=label=disable `
-v <Directory to mount ComfyUI>:/ComfyUI:Z `
-v deps:/deps `
-v huggingface:/root/.cache/huggingface `
-e ComfyArgs="<ComfyUI command line arguments>" `
ipex-arc-comfy:latest
```
For Windows, run the following in terminal or Docker Desktop.
```sh
docker run -it `
--device /dev/dxg `
-e ComfyArgs="<ComfyUI command line arguments>" `
--name comfy-server`
-p 8188:8188 `
-v /usr/lib/wsl:/usr/lib/wsl `
-v <Directory to mount ComfyUI>:/ComfyUI:Z `
-v deps:/deps `
-v huggingface:/root/.cache/huggingface `
ipex-arc-comfy:latest
```
<b>You must replace the <> text in the above commands with your own text. Copying the commands without modification will not run.</b>

Below is an explanation on what the above commands mean so one will know how to modify the command correctly to run the image if you are not familiar with Docker or podman. The arguments can be ordered in any way as long as `docker run` and `ipex-arc-comfy:latest` stay in the locations specified.

* docker run creates and runs a new container from an image. No modification needed here.
* On Linux, `--device /dev/dri` passes in your GPU from your host computer to the container as is required to enable container access to your GPU to run ComfyUI. On Windows, `--device /dev/dxg` and `-v /usr/lib/wsl:/usr/lib/wsl` are the equivalent commands to do the same thing through WSL2.
* `-e ComfyArgs="<ComfyUI command line arguments>"` specifies the ComfyUI arguments that you can pass to ComfyUI to use. You can take a look at the options you can pass [here](https://github.com/comfyanonymous/ComfyUI/blob/21a563d385ff520e1f7fdaada722212b35fb8d95/comfy/cli_args.py#L36). Things like Pytorch Cross Attention and BF16 are already turned on by default. Options that may help speed but impact accuracy and stability as a result include `--fp8_e4m3fn-text-enc`, `--fp8_e4m3fn-unet` and `--gpu-only`. Be aware that with the last option, offloading everything to VRAM may not be that great given that Intel Arc DG2 series cards and similar have a limitation of any one allocation being maximum 4GB in size due to hardware limitations as discussed in [here](https://github.com/oneapi-src/oneDNN/issues/1638) and one may need to use various VRAM reduction methods to actually work around this for higher resolution image generation.
* `-it` will let you launch the container with an interactive command line. This is highly recommended, but not mandatory, since we may need to monitor ComfyUI's output for any status changes or errors which would be made available easily by including this option.
* `--name comfy-server` assigns a meaningful name (e.g. comfy-server) to the newly created container. This option is useful but not mandatory to reference your container for later uses.
* `--network=host` allows the container access to your host computer's network which is needed to access ComfyUI without specifying the `--listen` argument on Linux hosts only, not Windows.
* `-p 8188:8188` specifies the computer network port to pass into the container to expose access to. This needs to be used alongside the `--listen` argument on Windsows. By default, ComfyUI uses port 8188 so inside the container, this port will be forwarded to http://localhost:<host_port> on your host system. This can be changed but is not recommended for most users.
* On Linux,`--security-opt=label=disable` will disable SELinux blocking access to the Docker socket in case it is configured by the Linux distribution used. It can be left out if you know your distribution doesn't use SELinux.
* `-v <Directory to mount ComfyUI>:/ComfyUI:Z` specifies a directory on host to be bind-mounted to /ComfyUI directory inside the container. When you launch the container for the first time, you should specify an empty or non-existent directory on your host computer running Docker or podman, replacing `<Directory to mount ComfyUI>`, so that the container can pull the ComfyUI source code into the directory specified. The `:Z` option at the end indicates that the bind mount content is private and unshared between containers at any one time. This does limit flexibility on the image's usage but is necessary to avoid usage issues with your GPU and ComfyUI output of images. If you want to launch another container (e.g. overriding the docker or podman entrypoint) that shares the initialized ComfyUI folder, you should specify the same directory location but again, it can not be launched at the same time.
* `-v <volume_name>:/deps` specifies a volume managed by Docker or podman (e.g. a volume named as I don't deps), to be mounted as /deps directory inside the container. /deps is configured as the Python virtual environment root directory (see Dockerfile: ENV venv_dir), to store all dynamic Python dependencies (e.g. Python dependency packages needed by ComfyUI or Intel's oneAPI runtime) that are referenced by ComfyUI when it starts. You can mount the deps volume to multiple containers so that those dynamic dependencies would be downloaded and installed only once. This is useful for users who want to run containers with different ComfyUI arguments (e.g. --gpu-only), and for those who actually build local images for experimenting.
* The last argument `ipex-arc-comfy:latest` specifies the image, in format of <image_name>:\<tag> to use for creating the container.

Afterwards, one should be able to see that everything runs. To stop a container, you can run `docker stop comfy-server` to stop the container. To resume, you should run `docker start -ai comfy-server`.

## Additional Options
* You can specify an optional `-v <volume_name>:/models` inside the argument list to point to an external model location. A valid `extra_model_paths.yaml` file must be provided in the root folder of the ComfyUI location. Please refer to ComfyUI's [example .yaml file](https://github.com/comfyanonymous/ComfyUI/blob/master/extra_model_paths.yaml.example) for guidance on how to specify your model locations. But you will need the following lines at minimum inside to point to the docker location:
```yaml
docker:
    base_path: /
...
```
* `ipexrun` is a launcher script to use Intel's Extension For Pytorch without code changes with optimizations enabled. GPU is still not supported and running ComfyUI through the launcher with some of the arguments you can use will be unsupported by Intel themselves so it is not enabled by default. To use the XPU path that uses your GPU, add in `-e UseIPEXRUN=true` to the argument string above. If CPU mode is to be used, you should additionally add in `-e UseXPU=false` to that list. You should also then set the environment variable for passing arguments to `ipexrun` adding `-e IPEXRUNArgs=<Your arguments here>`. A reference to all the `ipexrun` arguments can be found [here](https://intel.github.io/intel-extension-for-pytorch/xpu/latest/tutorials/performance_tuning/launch_script.html)
* You can change between `tcmalloc` (default) and `jemalloc` if using CPU `ipexrun`, add in `--build-arg="ALLOCATOR=jemalloc"` when building the image in the first step to switch between the two allocators for `ipexrun`.

Please refer to the [Dockerfile](./Dockerfile) for all available build arguments and environment variables not mentioned here and documented.
