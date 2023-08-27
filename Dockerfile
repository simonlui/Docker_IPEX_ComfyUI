// SPDX-License-Identifier: Apache-2.0 
ARG UBUNTU_VERSION=22.04
FROM ubuntu:${UBUNTU_VERSION} AS oneapi-lib-installer

RUN apt-get update && \
    apt-get install -y --no-install-recommends --fix-missing \
    ca-certificates \
    gnupg2 \
    gpg-agent \
    unzip \
    wget

# oneAPI packages
RUN no_proxy=$no_proxy wget -O- https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB \
   | gpg --dearmor | tee /usr/share/keyrings/oneapi-archive-keyring.gpg > /dev/null && \
   echo "deb [signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main" \
   | tee /etc/apt/sources.list.d/oneAPI.list

ARG DPCPP_VER=2023.2.1-16
ARG MKL_VER=2023.2.0-49495
# intel-oneapi-compiler-shared-common provides `sycl-ls`
ARG CMPLR_COMMON_VER=2023.2.1
# Install runtime libs to reduce image size
RUN apt-get update && \
    apt-get install -y --no-install-recommends --fix-missing \
    intel-oneapi-runtime-dpcpp-cpp=${DPCPP_VER} \
    intel-oneapi-runtime-mkl=${MKL_VER} \
    intel-oneapi-compiler-shared-common-${CMPLR_COMMON_VER}=${DPCPP_VER}

# Prepare Intel Graphics driver index
ARG DEVICE=flex
RUN no_proxy=$no_proxy wget -qO - https://repositories.intel.com/graphics/intel-graphics.key | \
    gpg --dearmor --output /usr/share/keyrings/intel-graphics.gpg
RUN printf 'deb [arch=amd64 signed-by=/usr/share/keyrings/intel-graphics.gpg] https://repositories.intel.com/graphics/ubuntu jammy %s\n' "$DEVICE" | \
    tee /etc/apt/sources.list.d/intel.gpu.jammy.list

ARG UBUNTU_VERSION=22.04
FROM ubuntu:${UBUNTU_VERSION}

RUN mkdir /oneapi-lib
COPY --from=oneapi-lib-installer /opt/intel/oneapi/lib /oneapi-lib/
ARG CMPLR_COMMON_VER=2023.2.1
COPY --from=oneapi-lib-installer /opt/intel/oneapi/compiler/${CMPLR_COMMON_VER}/linux/bin/sycl-ls /bin/
COPY --from=oneapi-lib-installer /usr/share/keyrings/intel-graphics.gpg /usr/share/keyrings/intel-graphics.gpg
COPY --from=oneapi-lib-installer /etc/apt/sources.list.d/intel.gpu.jammy.list /etc/apt/sources.list.d/intel.gpu.jammy.list

# Set oneAPI lib env
ENV LD_LIBRARY_PATH=/oneapi-lib:/oneapi-lib/intel64:$LD_LIBRARY_PATH

RUN apt-get update && \
    apt-get install -y --no-install-recommends --fix-missing \
    ca-certificates && \
    apt-get clean && \
    rm -rf  /var/lib/apt/lists/*

ARG PYTHON=python3.10
RUN apt-get update && apt-get install -y --no-install-recommends --fix-missing \
    ${PYTHON} lib${PYTHON} python3-pip && \
    apt-get clean && \
    rm -rf  /var/lib/apt/lists/*

RUN pip --no-cache-dir install --upgrade \
    pip \
    setuptools

RUN ln -sf $(which ${PYTHON}) /usr/local/bin/python && \
    ln -sf $(which ${PYTHON}) /usr/local/bin/python3 && \
    ln -sf $(which ${PYTHON}) /usr/bin/python && \
    ln -sf $(which ${PYTHON}) /usr/bin/python3

ARG ICD_VER=23.17.26241.33-647~22.04
ARG LEVEL_ZERO_GPU_VER=1.3.26241.33-647~22.04
ARG LEVEL_ZERO_VER=1.11.0-647~22.04
ARG LEVEL_ZERO_DEV_VER=1.11.0-647~22.04
ARG ALLOCATOR=tcmalloc
ENV ALLOCATOR=${ALLOCATOR}
ARG ALLOCATOR_PACKAGE=libgoogle-perftools-dev
ARG ALLOCATOR_LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libtcmalloc.so
RUN if [ "${ALLOCATOR}" = "jemalloc" ] ; then \
       ${ALLOCATOR_PACKAGE}=libjemalloc-dev; \
       ${ALLOCATOR_LD_PRELOAD}=/usr/lib/x86_64-linux-gnu/libjemalloc.so; \
    fi

RUN apt-get update && \
    apt-get install -y --no-install-recommends --fix-missing \
    intel-opencl-icd=${ICD_VER} \
    intel-level-zero-gpu=${LEVEL_ZERO_GPU_VER} \
    level-zero=${LEVEL_ZERO_VER} \
    level-zero-dev=${LEVEL_ZERO_DEV_VER} && \
    apt-get clean && \
    rm -rf  /var/lib/apt/lists/*

# Comfy UI/Pytorch dependencies for runtime or speedup
RUN apt-get update && \
    apt-get install -y --no-install-recommends --fix-missing \
    ${ALLOCATOR_PACKAGE} \
    libgl1 \
    libglib2.0-0 \
    libgomp1 \
    python3-venv \
    git \
    numactl && \
    apt-get clean && \
    rm -rf  /var/lib/apt/lists/*

COPY startup.sh /bin/
RUN chmod 755 /bin/startup.sh

VOLUME [ "/deps" ]
VOLUME [ "/ComfyUI" ]
VOLUME [ "/models" ]
VOLUME [ "/root/.cache/huggingfacetest" ]

ENV VENVDir=/deps/venv
ENV LD_PRELOAD=${ALLOCATOR_LD_PRELOAD}

# Force 100% available VRAM size for compute-runtime
# See https://github.com/intel/compute-runtime/issues/586
ENV NEOReadDebugKeys=1
ENV ClDeviceGlobalMemSizeAvailablePercent=100

# Enable double precision emulation just in case.
# See https://github.com/intel/compute-runtime/blob/master/opencl/doc/FAQ.md#feature-double-precision-emulation-fp64
ENV OverrideDefaultFP64Settings=1
ENV IGC_EnableDPEmulation=1

# Set to false if CPU is to be used to launch ComfyUI. XPU is default.
ARG UseXPU=true
ENV UseXPU=${UseXPU}

# Set to true if ipexrun is to be used to launch ComfyUI. Off by default.
ARG UseIPEXRUN=false
ENV UseIPEXRUN=${UseIPEXRUN}

# Pass in ComfyUI arguments as an environment variable so it can be used in startup.sh
ARG ComfyArgs=""
ENV ComfyArgs=${ComfyArgs}

WORKDIR /ComfyUI
ENTRYPOINT [ "startup.sh" ]
