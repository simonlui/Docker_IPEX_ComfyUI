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
ARG DPCPP_VER=2024.2.1-1079
ARG MKL_VER=2024.2.2-15
ARG CMPLR_COMMON_VER=2024.2
# intel-oneapi-compiler-shared-common provides `sycl-ls` and other utilities like the compiler
RUN apt-get update && \
    apt-get install -y --no-install-recommends --fix-missing \
    intel-oneapi-dpcpp-cpp-${CMPLR_COMMON_VER}=${DPCPP_VER} \
    intel-oneapi-compiler-shared-common-${CMPLR_COMMON_VER}=${DPCPP_VER} \
    intel-oneapi-runtime-dpcpp-cpp=${DPCPP_VER} \
    intel-oneapi-runtime-mkl=${MKL_VER} && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Add and prepare Intel Graphics driver index. This is dependent on being able to pass your GPU with a working driver on the host side where the image will run.
# hadolint ignore=DL4006
RUN wget --progress=dot:giga -qO - https://repositories.intel.com/graphics/intel-graphics.key | \
    gpg --dearmor --output /usr/share/keyrings/intel-graphics.gpg
# hadolint ignore=DL4006
RUN echo "deb [arch=amd64 signed-by=/usr/share/keyrings/intel-graphics.gpg] https://repositories.intel.com/graphics/ubuntu jammy unified" | \
    tee /etc/apt/sources.list.d/intel.gpu.jammy.list

ARG UBUNTU_VERSION=22.04
FROM ubuntu:${UBUNTU_VERSION}

# Copy all the files from the oneAPI runtime libraries image into the actual final image.
RUN mkdir -p /opt/intel
COPY --from=oneapi-lib-installer /opt/intel/ /opt/intel/
COPY --from=oneapi-lib-installer /usr/share/keyrings/intel-graphics.gpg /usr/share/keyrings/intel-graphics.gpg
COPY --from=oneapi-lib-installer /etc/apt/sources.list.d/intel.gpu.jammy.list /etc/apt/sources.list.d/intel.gpu.jammy.list

# Set apt install to not be interactive for some packages that require it.
ENV DEBIAN_FRONTEND=noninteractive

# Set oneAPI library environment variable
ENV LD_LIBRARY_PATH=/opt/intel/oneapi/redist/lib:/opt/intel/oneapi/redist/lib/intel64:$LD_LIBRARY_PATH

# Install certificate authorities to get access to secure connections to other places for downloads and other packages.
# hadolint ignore=DL3008
RUN apt-get update && \
    apt-get install -y --no-install-recommends --fix-missing \
    build-essential \
    ca-certificates \
    fonts-noto \
    git \
    gnupg2 \
    gpg-agent \
    software-properties-common \
    wget && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Sets versions of Level-Zero, OpenCL and memory allocator chosen.
ARG ICD_VER=23.17.26241.33-647~22.04
ARG LEVEL_ZERO_GPU_VER=1.3.26241.33-647~22.04
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
    intel-level-zero-gpu=${LEVEL_ZERO_GPU_VER} && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Python and other associated packages from PPA since default is 3.10
ARG PYTHON=python3.11
# hadolint ignore=DL3008
RUN add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y --no-install-recommends --fix-missing \
    ${PYTHON} \
    ${PYTHON}-dev \
    lib${PYTHON} \
    python3-pip \
    ${PYTHON}-venv && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Update pip
# hadolint ignore=DL3013
RUN python3 -m pip install -U \
    pip \
    setuptools

# Softlink Python to make it default.
RUN ln -sf "$(which ${PYTHON})" /usr/local/bin/python && \
    ln -sf "$(which ${PYTHON})" /usr/local/bin/python3 && \
    ln -sf "$(which ${PYTHON})" /usr/bin/python && \
    ln -sf "$(which ${PYTHON})" /usr/bin/python3

# Install Comfy UI/Pytorch dependencies.
# hadolint ignore=DL3008
RUN apt-get update && \
    apt-get install -y --no-install-recommends --fix-missing \
    ${ALLOCATOR_PACKAGE} \
    libgl1 \
    libglib2.0-0 \
    libgomp1 \
    numactl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Getting the latest versions of Intel's Compute Runtime and associated packages on Github and installing it will update everything we installed before.
RUN mkdir neo
WORKDIR /neo
RUN wget --progress=dot:giga https://github.com/intel/intel-graphics-compiler/releases/download/v2.5.6/intel-igc-core-2_2.5.6+18417_amd64.deb && \
    wget --progress=dot:giga https://github.com/intel/intel-graphics-compiler/releases/download/v2.5.6/intel-igc-opencl-2_2.5.6+18417_amd64.deb && \
    wget --progress=dot:giga https://github.com/intel/compute-runtime/releases/download/24.52.32224.5/intel-level-zero-gpu_1.6.32224.5_amd64.deb && \
    wget --progress=dot:giga https://github.com/intel/compute-runtime/releases/download/24.52.32224.5/intel-opencl-icd_24.52.32224.5_amd64.deb && \
    wget --progress=dot:giga https://github.com/intel/compute-runtime/releases/download/24.52.32224.5/libigdgmm12_22.5.5_amd64.deb && \
    wget --progress=dot:giga https://github.com/oneapi-src/level-zero/releases/download/v1.19.2/level-zero_1.19.2+u22.04_amd64.deb && \
    wget --progress=dot:giga https://github.com/oneapi-src/level-zero/releases/download/v1.19.2/level-zero-devel_1.19.2+u22.04_amd64.deb && \
    dpkg -i -- *.deb
WORKDIR /

# Make sure everything is up to date.
# hadolint ignore=DL3008
RUN apt-get update && \
    apt-get upgrade -y --no-install-recommends --fix-missing && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf  /var/lib/apt/lists/*

# Remove linux-libc-dev for security reasons without disturbing anything else.
RUN dpkg -r --force-depends linux-libc-dev

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

# Enable double precision emulation. Turned on by default to enable torch.compile to work for various kernels. Turn this off if you need to enable attention
# slicing to address the 4GB single allocation limit with Intel Xe GPUs and lower and don't use torch.compile.
# See https://github.com/intel/compute-runtime/blob/master/opencl/doc/FAQ.md#feature-double-precision-emulation-fp64
ENV OverrideDefaultFP64Settings=1
ENV IGC_EnableDPEmulation=1

# Enable SYCL variables for cache reuse and single threaded mode.
# See https://github.com/intel/llvm/blob/sycl/sycl/doc/EnvironmentVariables.md
ENV SYCL_CACHE_PERSISTENT=1
ENV SYCL_PI_LEVEL_ZERO_SINGLE_THREAD_MODE=1

# Setting to turn on for Intel Xe GPUs that do not have XMX cores which include any iGPUs from Intel Ice Lake to Meteor Lake.
#ENV BIGDL_LLM_XMX_DISABLED=1
# Linux only setting that speeds up compute workload submissions allowing them to run concurrently on a single hardware queue. Turned off by default since
# this was only introduced recently with the Xe graphics driver you need to turn on by default manually and development focus has been on using this feature
# with Data Center GPU Max Series. Only also seems to benefit LLMs mostly when Intel encourages turning it on on Intel Arc cards. Also need kernel 6.2 or up.
# See https://www.intel.com/content/www/us/en/developer/articles/guide/level-zero-immediate-command-lists.html
#ENV SYCL_PI_LEVEL_ZERO_USE_IMMEDIATE_COMMANDLISTS=1
# Only use if something with Intel's low level libraries aren't working, see https://github.com/intel/xetla/tree/main for more details on what this affects.
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
