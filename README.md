# Stable Diffusion ComfyUI Docker/OCI Image for Intel Arc GPUs

This Docker/OCI image is designed to run [ComfyUI](https://github.com/comfyanonymous/ComfyUI) inside a Docker container for Intel Arc GPUs. This work was based in large part on the work done by a Docker image made by nuullll [here](https://github.com/Nuullll/ipex-sd-docker-for-arc-gpu) for a different Stable Diffusion UI.

The Docker/OCI image includes
- Intel oneAPI DPC++ runtime libs _(Note: compiler executables are not included)_
- Intel oneAPI MKL runtime libs
- Intel oneAPI compiler common tools like `sycl-ls`
- Intel Graphics driver
- Basic Python virtual environment

Intel Extension for Pytorch (IPEX) and other python packages and dependencies will be installed upon first launch of the container. They will be installed in a Python virtual environment in a seperate volume to allow for reuse between containers.

## Prerequisites

* Intel GPU which has support for Intel's oneAPI AI toolkit. According to their support link [here](https://www.intel.com/content/www/us/en/developer/articles/system-requirements/intel-oneapi-ai-analytics-toolkit-system-requirements.html), the following GPUs are supported.
    - Intel® Data Center GPU Flex Series
    - Intel® Data Center GPU Max Series
    - Intel® Arc™ A-Series Graphics
* Docker (Desktop) or podman
* Linux or Windows.

## Build and run the image

Instructions will assume Docker but replace with podman since it should have command compatibility. Run the following command in terminal to checkout the repository and build the image.
```
git clone https://github.com/simonlui/Docker_IPEX_ComfyUI
cd Docker_IPEX_ComfyUI
docker build -t ipex-arc-comfy:latest -f Dockerfile .
```
Once this complete, then run the following if using Linux in terminal or Docker Desktop.
```
docker run -it `
--device /dev/dri `
-e ComfyArgs="<ComfyUI command line arguments>" `
--name comfy-server`  
--network=host `
-p 8188:8188 `
--security-opt=label=disable `
-v <Directory to mount ComfyUI>:/ComfyUI:Z `
-v deps:/deps `
-v huggingface:/root/.cache/huggingface `
-e ComfyArgs="<ComfyUI command line arguments>" `
ipex-arc-comfy:latest

```
For Windows, run the following in terminal or Docker Desktop.
```
docker run -it `
--device /dev/dxg `
-e ComfyArgs="<ComfyUI command line arguments>" `
--name comfy-server`
--network=host `
-p 8188:8188 `
-v /usr/lib/wsl:/usr/lib/wsl `
-v <Directory to mount ComfyUI>:/ComfyUI:Z `
-v deps:/deps `
-v huggingface:/root/.cache/huggingface `
ipex-arc-comfy:latest
```
<b>You must replace the <> text in the above commands with your own text. Copying the commands without modification will not run.</b>

Below is an explanation on what the above commands mean so one will know how to modify the command correctly to run the image if you are not familar with Docker or podman. The arguments can be ordered in any way as long as `docker run` and `ipex-arc-comfy:latest` stay in the locations specified.

* docker run creates and runs a new container from an image. No modification needed here.
* On Linux, `--device /dev/dri` passes in your GPU to the container as is required to enable container access to your GPU to run ComfyUI. On Windows, `--device /dev/dxg` and `-v /usr/lib/wsl:/usr/lib/wsl` are the equivalent commands to do the same thing through WSL2.
* `-e ComfyArgs="<ComfyUI command line arguments>"` specifies the ComfyUI arguments that you can pass to ComfyUI to use. At minimum as of this writing, you need to specify `--highvram`. `--highvram` keeps the model in GPU memory which is needed to stop a source of crashing but it can also include anything else you specify.
* `-it` will let you launch the container with an interactive command line. This is highly recommended, but not mandatory, since we may need to monitor ComfyUI's output for any status changes or errors which would be made availble easily by including this option.
* `--name comfy-server` assigns a meaningful name (e.g. comfy-server) to the newly created container. This option is useful but not mandatory to reference your container for later uses.
* `--network=host` allows the container access to your host computer's network which is needed to access ComfyUI without specifying the `--listen` argument.
* `-p 8188:8188` specifies the computer network port to pass into the container to expose access to. By default, ComfyUI uses port 8188 so inside the container , this port will be forwarded to http://localhost:<host_port> on your host system. This can be changed but is not recommended for most users.
* On Linux,`--security-opt=label=disable` will disable SELinux blocking access to the Docker socket in case it is configured by the distribution.
* `-v <Directory to mount ComfyUI>:/ComfyUI:Z` specifies a directory on host to be bind-mounted to /ComfyUI directory inside the container. When you launch the container for the first time, you should specify an empty or non-existent directory on your host computer running Docker or podman, replacing `<Directory to mount ComfyUI>`, so that the container can pull the ComfyUI source code into the directory specified. The `:Z` option at the end indicates that the bind mount content is private and unshared between containers at any one time. This does limit flexibility on the image's usage but is necessary to avoid usage issues with your GPU and ComfyUI output of images. If you want to launch another container (e.g. overriding the docker or podman entrypoint) that shares the initialized Web UI folder, you should specify the same directory location but again, it can not be launched at the same time.
* `-v <volume_name>:/deps` specifies a volume managed by Docker or podman (e.g. a volume named as deps), to be mounted as /deps directory inside the container. /deps is configured as the Python virtual environment root directory (see Dockerfile: ENV venv_dir), to store all dynamic Python dependencies (e.g. Python dependency packages needed by ComfyUI or Intel's oneAPI runtime) that are referenced by ComfyUI when it starts. You can mount the deps volume to multiple containers so that those dynamic dependencies would be downloaded and installed only once. This is useful for users who want to run containers with different ComfyUI arguments (e.g. --gpu-only), and for those who actually build local images for experimenting.
* The last argument `ipex-arc-comfy:latest` specifies the image, in format of <image_name>:\<tag> to use for creating the container.

Afterwards, one should be able to see that everything runs. To stop a container, you can run `docker stop comfy-server` to stop the container. To resume, you should run `docker start -ai comfy-server`.

Refer to [Dockerfile](./Dockerfile) for all available build arguments and environment variables.
