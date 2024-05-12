# SPDX-License-Identifier: Apache-2.0
ARG UBUNTU_VERSION=22.04
FROM ubuntu:${UBUNTU_VERSION} AS oneapi-lib-installer

# Make sure Dockerfile doesn't succeed if there are errors.
RUN ["/bin/sh", "-c", "/bin/bash", "-o", "pipefail", "-c"]

# Install prerequisites to install oneAPI runtime libraries.
# hadolint ignore=DL3008
RUN apt-get update && \
    apt-get install -y --no-install-recommends --fix-missing \
    ca-certificates \
    gnupg2 \
    gpg-agent \
    unzip \
    wget

# hadolint ignore=DL4006
RUN wget --progress=dot:giga -O- https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB \
   | gpg --dearmor | tee /usr/share/keyrings/oneapi-archive-keyring.gpg > /dev/null && \
   echo 'deb [signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main' \
   | tee /etc/apt/sources.list.d/oneAPI.list

# Define and install oneAPI runtime libraries for less space.
ARG DPCPP_VER=2024.1.0-963
ARG MKL_VER=2024.1.0-691
ARG CMPLR_COMMON_VER=2024.1
# intel-oneapi-compiler-shared-common provides `sycl-ls`
RUN apt-get update && \
    apt-get install -y --no-install-recommends --fix-missing \
    intel-oneapi-runtime-dpcpp-cpp=${DPCPP_VER} \
    intel-oneapi-runtime-mkl=${MKL_VER} \
    intel-oneapi-compiler-shared-common-${CMPLR_COMMON_VER}=${DPCPP_VER} &&\
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Add and prepare Intel Graphics driver index. This is dependent on being able to pass your GPU with a working driver on the host side where the image will run.
# hadolint ignore=DL4006
RUN wget --progress=dot:giga -qO - https://repositories.intel.com/graphics/intel-graphics.key | \
    gpg --dearmor --output /usr/share/keyrings/intel-graphics.gpg
# hadolint ignore=DL4006
RUN echo "deb [arch=amd64 signed-by=/usr/share/keyrings/intel-graphics.gpg] https://repositories.intel.com/gpu/ubuntu jammy/lts/2350 unified" | \
    tee /etc/apt/sources.list.d/intel.gpu.jammy.list

ARG UBUNTU_VERSION=22.04
FROM ubuntu:${UBUNTU_VERSION}

# Copy all the files from the oneAPI runtime libraries image into the actual final image.
RUN mkdir -p /oneapi-lib
COPY --from=oneapi-lib-installer /opt/intel/oneapi/redist/lib/ /oneapi-lib/
ARG CMPLR_COMMON_VER=2024.1
COPY --from=oneapi-lib-installer /opt/intel/oneapi/compiler/${CMPLR_COMMON_VER}/bin/sycl-ls /bin/
COPY --from=oneapi-lib-installer /usr/share/keyrings/intel-graphics.gpg /usr/share/keyrings/intel-graphics.gpg
COPY --from=oneapi-lib-installer /etc/apt/sources.list.d/intel.gpu.jammy.list /etc/apt/sources.list.d/intel.gpu.jammy.list

# Set apt install to not be interactive for things like tzdata
ENV DEBIAN_FRONTEND=noninteractive

# Set oneAPI library environment variable
ENV LD_LIBRARY_PATH=/oneapi-lib:/oneapi-lib/intel64:$LD_LIBRARY_PATH

# Install certificate authorities to get access to secure connections to other places for downloads and other packages.
# hadolint ignore=DL3008
RUN apt-get update && \
    apt-get install -y --no-install-recommends --fix-missing \
    ca-certificates \
    fonts-noto \
    git \
    gnupg2 \
    gpg-agent \
    software-properties-common \
    wget

# Install Python and other associated packages from PPA since default is 3.10
ARG PYTHON=python3.11
# hadolint ignore=DL3008
RUN add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y --no-install-recommends --fix-missing \
    ${PYTHON} \
    lib${PYTHON} \
    python3-pip \
    ${PYTHON}-venv

# Update pip
# hadolint ignore=DL3013
RUN pip --no-cache-dir install --upgrade \
    pip \
    setuptools

# Softlink Python to make it default.
RUN ln -sf "$(which ${PYTHON})" /usr/local/bin/python && \
    ln -sf "$(which ${PYTHON})" /usr/local/bin/python3 && \
    ln -sf "$(which ${PYTHON})" /usr/bin/python && \
    ln -sf "$(which ${PYTHON})" /usr/bin/python3

# Sets versions of Level-Zero, OpenCL and memory allocator chosen.
ARG ICD_VER=23.43.27642.40-803~22.04
ARG LEVEL_ZERO_GPU_VER=1.3.27642.40-803~22.04
ARG LEVEL_ZERO_VER=1.14.0-744~22.04
ARG LEVEL_ZERO_DEV_VER=1.14.0-744~22.04
ARG ALLOCATOR=tcmalloc
ENV ALLOCATOR=${ALLOCATOR}
ARG ALLOCATOR_PACKAGE=libgoogle-perftools-dev
ARG ALLOCATOR_LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libtcmalloc.so
RUN if [ "${ALLOCATOR}" = "jemalloc" ] ; then \
       ALLOCATOR_PACKAGE=libjemalloc-dev; \
       ALLOCATOR_LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so; \
    fi

# Install Level-Zero and OpenCL backends.
RUN apt-get update && \
    apt-get install -y --no-install-recommends --fix-missing \
    intel-opencl-icd=${ICD_VER} \
    intel-level-zero-gpu=${LEVEL_ZERO_GPU_VER} \
    level-zero=${LEVEL_ZERO_VER} \
    level-zero-dev=${LEVEL_ZERO_DEV_VER}

# Update Compute Runtime to latest version
RUN mkdir neo && \
    cd neo && \
    wget https://github.com/intel/intel-graphics-compiler/releases/download/igc-1.0.16510.2/intel-igc-core_1.0.16510.2_amd64.deb && \
    wget https://github.com/intel/intel-graphics-compiler/releases/download/igc-1.0.16510.2/intel-igc-opencl_1.0.16510.2_amd64.deb && \
    wget https://github.com/intel/compute-runtime/releases/download/24.13.29138.7/intel-level-zero-gpu_1.3.29138.7_amd64.deb && \
    wget https://github.com/intel/compute-runtime/releases/download/24.13.29138.7/intel-opencl-icd_24.13.29138.7_amd64.deb && \
    wget https://github.com/intel/compute-runtime/releases/download/24.13.29138.7/libigdgmm12_22.3.18_amd64.deb && \
    dpkg -i *.deb && \
    cd ..

# Install Comfy UI/Pytorch dependencies.
# hadolint ignore=DL3008
RUN apt-get update && \
    apt-get install -y --no-install-recommends --fix-missing \
    ${ALLOCATOR_PACKAGE} \
    libgl1 \
    libglib2.0-0 \
    libgomp1 \
    numactl
    
# Make sure everything is up to date.
# hadolint ignore=DL3008
RUN apt-get update && \
    apt-get upgrade -y --no-install-recommends --fix-missing && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf  /var/lib/apt/lists/*

# Copy the startup script to the /bin/ folder and make executable.
COPY startup.sh /bin/
RUN chmod 755 /bin/startup.sh

# Volumes that can be used by the image when making containers.
VOLUME [ "/deps" ]
VOLUME [ "/ComfyUI" ]
VOLUME [ "/models" ]
VOLUME [ "/root/.cache/huggingface" ]

# Setup location of Python virtual environment and make sure LD_PRELOAD contains the path of the allocator chosen.
ENV VENVDir=/deps/venv
ENV LD_PRELOAD=${ALLOCATOR_LD_PRELOAD}

# Enable Level Zero system management
# See https://spec.oneapi.io/level-zero/latest/sysman/PROG.html
ENV ZES_ENABLE_SYSMAN=1

# Force 100% available VRAM size for compute-runtime.
# See https://github.com/intel/compute-runtime/issues/586
ENV NEOReadDebugKeys=1
ENV ClDeviceGlobalMemSizeAvailablePercent=100

# Enable double precision emulation just in case.
# See https://github.com/intel/compute-runtime/blob/master/opencl/doc/FAQ.md#feature-double-precision-emulation-fp64
ENV OverrideDefaultFP64Settings=1
ENV IGC_EnableDPEmulation=1

# Enable SYCL variables for cache reuse and single threaded mode.
# See https://github.com/intel/llvm/blob/sycl/sycl/doc/EnvironmentVariables.md
ENV SYCL_CACHE_PERSISTENT=1
ENV SYCL_PI_LEVEL_ZERO_SINGLE_THREAD_MODE=1

# FIXME: Does this need to be turned on for Stable Diffusion or only with ipex-llm?
#ENV BIGDL_LLM_XMX_DISABLED=1
# FIXME: The below variables are optimal for running LLMs but not Stable Diffusion which setting these makes it slower. Figure out why.
#ENV SYCL_PI_LEVEL_ZERO_USE_IMMEDIATE_COMMANDLISTS=1
#ENV USE_XETLA=OFF

# Set variable for better training performance in case.
# See https://github.com/intel/intel-extension-for-pytorch/issues/296#issuecomment-1461118993
ENV IPEX_XPU_ONEDNN_LAYOUT=1

# Set to false if CPU is to be used to launch ComfyUI. XPU is default.
ARG UseXPU=true
ENV UseXPU=${UseXPU}

# Set to true if ipexrun is to be used to launch ComfyUI. Off by default.
ARG UseIPEXRUN=false
ENV UseIPEXRUN=${UseIPEXRUN}

# Set to the arguments you want to pass to ipexrun.
# Example for CPU: --multi-task-manager 'taskset' --memory-allocator ${ALLOCATOR}
# Example for XPU: --convert-fp64-to-fp32
ARG IPEXRUNArgs=""
ENV IPEXRUNArgs=${IPEXRUNArgs}

# Pass in ComfyUI arguments as an environment variable so it can be used in startup.sh which passes it on.
ARG ComfyArgs=""
ENV ComfyArgs=${ComfyArgs}

# Set location and entrypoint of the image to the ComfyUI directory and the startup script.
WORKDIR /ComfyUI
ENTRYPOINT [ "startup.sh" ]
