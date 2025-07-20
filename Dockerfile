# syntax=docker/dockerfile:1.7   # ensures we are using BuildKit
FROM ubuntu:22.04

# Accept arguments for UID and GID
ARG USER_ID=1000
ARG GROUP_ID=1000
ARG USER_NAME
ARG CONTAINER_NAME
ARG HHB_VERSION
ARG SHL_PYTHON_VERSION

# Setting timezone non-interactively
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Madrid

# Don't install recommended or suggested packages
RUN echo 'APT::Get::Assume-Yes "true";' > /etc/apt/apt.conf.d/00-docker
# RUN echo 'APT::Get::Install-Suggests "0";' >> /etc/apt/apt.conf.d/00-docker
# RUN echo 'APT::Get::Install-Recommends "0";' >> /etc/apt/apt.conf.d/00-docker
# RUN echo 'APT::Install-Suggests "0";' >> /etc/apt/apt.conf.d/00-docker
# RUN echo 'APT::Install-Recommends "0";' >> /etc/apt/apt.conf.d/00-docker

# Installation of basic packages
RUN apt update && apt install -y --no-install-recommends \
    aptitude \
    build-essential \
    clang-15 \
    cmake \
    curl \
    git \
    less \
    libedit-dev \
    libjpeg-dev \
    libgl1 libglib2.0-0 libsm6 libxext6 \
    libncurses5-dev \
    libtinfo5 \
    libxml2-dev \
    libz-dev \
    libzstd-dev \
    llvm-15 \
    locales \
    lsb-release \
    mc \
    ninja-build \
    p7zip-full \
    pkg-config \
    python3 \
    python3-dev \
    python3-pip \
    python3-setuptools \
    rsync \
    sudo \
    tree \
    vim \
    wget \
    zlib1g-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Generation and configuration of locales
RUN locale-gen en_US.UTF-8 ru_RU.UTF-8 && \
    update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 && \
    echo "export LANG=en_US.UTF-8" >> /etc/bash.bashrc && \
    echo "export LC_ALL=en_US.UTF-8" >> /etc/bash.bashrc

# Setting environment variables for locales
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV LANGUAGE=en_US:en

# Add symbolic link python -> python3
RUN ln -sf /usr/bin/python3 /usr/bin/python

# Install Python dependencies
RUN pip3 install --no-cache-dir "numpy<2.0" && \
    pip3 install --no-cache-dir \
    cython \
    gradio \
    gradio_imageslider \
    hhb==${HHB_VERSION} \
    hhb-tvm==${HHB_VERSION} \
    matplotlib \
    ml_dtypes \
    onnx \
    onnxruntime \
    onnxscript \
    onnx-simplifier \
    onnxslim \
    packaging \
    psutil \
    scipy \
    shl-python==${SHL_PYTHON_VERSION} \
    sympy \
    torch \
    torchvision \
    tqdm \
    typer \
    typing_extensions

# Create working directory
WORKDIR /data


ENV ZSTD_LIB_DIR=/usr/lib/x86_64-linux-gnu
ENV TOOLROOT=/opt/riscv
# ENV RISCV_CFLAGS="-march=rv64gcv0p7_zfh_xtheadc -mabi=lp64d -O3"
ENV RISCV_CFLAGS="-march=rv64gcv0p7_zfh_xtheadc -mabi=lp64d -O3"

# Download and install RISC-V Xuantie toolchain
# The toolchain is downloaded from the official Aliyun OSS repository.
# The version can be changed to the latest one available at the time of building the image.
# Available versions can be found at https://www.xrvm.cn/community/download?id=4433353576298909696
# The following versions are available:
    # GCC V3.1.0 -  https://occ-oss-prod.oss-cn-hangzhou.aliyuncs.com/resource//1749714096626/Xuantie-900-gcc-linux-6.6.0-glibc-x86_64-V3.1.0-20250522.tar.gz
    # MUSL V3.1.0 - https://occ-oss-prod.oss-cn-hangzhou.aliyuncs.com/resource//1749713312767/Xuantie-900-gcc-linux-5.10.4-musl64-x86_64-V3.1.0-20250522.tar.gz
    # GCC V3.0.2 -  https://occ-oss-prod.oss-cn-hangzhou.aliyuncs.com/resource//1744884682896/Xuantie-900-gcc-linux-5.10.4-glibc-x86_64-V3.0.2-20250410.tar.gz
    # GCC V2.10.2 - https://occ-oss-prod.oss-cn-hangzhou.aliyuncs.com/resource/1836682/1725612383347/Xuantie-900-gcc-linux-6.6.0-glibc-x86_64-V2.10.2-20240904.tar.gz
    # GCC V2.8.1 -  https://occ-oss-prod.oss-cn-hangzhou.aliyuncs.com/resource//1705395627867/Xuantie-900-gcc-linux-5.10.4-glibc-x86_64-V2.8.1-20240115.tar.gz
    # GCC V2.8.0 -  https://occ-oss-prod.oss-cn-hangzhou.aliyuncs.com/resource//1698113812618/Xuantie-900-gcc-linux-5.10.4-glibc-x86_64-V2.8.0-20231018.tar.gz
    # GCC V2.6.1 -  https://occ-oss-prod.oss-cn-hangzhou.aliyuncs.com/resource//1695015316167/Xuantie-900-gcc-linux-5.10.4-glibc-x86_64-V2.6.1-20220906.tar.gz
    # LLVM V2.1.0 - https://occ-oss-prod.oss-cn-hangzhou.aliyuncs.com/resource//1749717040975/Xuantie-900-llvm-elf-newlib-x86_64-V2.1.0-20250522.tar.gz
    # LLVM V2.1.0 - https://occ-oss-prod.oss-cn-hangzhou.aliyuncs.com/resource//1749717539068/Xuantie-900-llvm-linux-6.6.0-glibc-x86_64-V2.1.0-20250522.tar.gz
    # LLVM V2.0.1 - https://occ-oss-prod.oss-cn-hangzhou.aliyuncs.com/resource//1732891447157/Xuantie-900-llvm-linux-5.10.4-glibc-x86_64-V2.0.1-20241121.tar.gz
#    tar -xzf Xuantie-900-llvm-linux-5.10.4-glibc-x86_64-V2.0.1-20241121.tar.gz -C /opt/riscv --strip-components=1 && \
#    /opt/riscv/bin/llvm-objdump --version

# Install RISC-V toolchain  
RUN mkdir -p /tmp/toolchain && \
    cd /tmp/toolchain && \
    wget -q https://occ-oss-prod.oss-cn-hangzhou.aliyuncs.com/resource//1749714096626/Xuantie-900-gcc-linux-6.6.0-glibc-x86_64-V3.1.0-20250522.tar.gz && \
    wget -q https://occ-oss-prod.oss-cn-hangzhou.aliyuncs.com/resource//1749717539068/Xuantie-900-llvm-linux-6.6.0-glibc-x86_64-V2.1.0-20250522.tar.gz && \
    mkdir -p /opt/riscv && \
    tar -xzf Xuantie-900-gcc-linux-6.6.0-glibc-x86_64-V3.1.0-20250522.tar.gz -C /opt/riscv --strip-components=1 && \
    tar -xzf Xuantie-900-llvm-linux-6.6.0-glibc-x86_64-V2.1.0-20250522.tar.gz -C /opt/riscv --strip-components=1 && \
    rm -rf /tmp/toolchain && \
    /opt/riscv/bin/riscv64-unknown-linux-gnu-gcc --version && \
    /opt/riscv/bin/llvm-objdump --version

# Create user and group with the specified UID/GID if they do not exist,
# or reuse existing ones
RUN set -eux; \
    # If the group does not exist — create it
    if ! getent group ${GROUP_ID} >/dev/null; then \
        groupadd -g ${GROUP_ID} ${USER_NAME}; \
    fi; \
    # If the user does not exist — create it
    if ! getent passwd ${USER_ID} >/dev/null; then \
        useradd -u ${USER_ID} -g ${GROUP_ID} -m -s /bin/bash ${USER_NAME}; \
    else \
        # If the user already exists, determine its name
        EXISTING_USER=$(getent passwd ${USER_ID} | cut -d: -f1); \
        usermod -d /home/${USER_NAME} -m $EXISTING_USER || true; \
        usermod -l ${USER_NAME} $EXISTING_USER || true; \
    fi; \
    mkdir -p /home/${USER_NAME} /data; \
    chown -R ${USER_ID}:${GROUP_ID} /home/${USER_NAME} /data; \
    echo "${USER_NAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USER_NAME}; \
    chmod 0440 /etc/sudoers.d/${USER_NAME}; 

# Make hhb executable
RUN cat <<'EOF' >> /usr/local/bin/hhb
#!/usr/bin/python3
# -*- coding: utf-8 -*-
import re
import sys
from hhb.main import main
if __name__ == '__main__':
    sys.argv[0] = re.sub(r'(-script\.pyw|\.exe)?$', '', sys.argv[0])
    sys.exit(main())
EOF
RUN chmod +x /usr/local/bin/hhb

# Configure .bashrc for the user
# --- add everything that should be in ~/.bashrc ---
RUN cat <<'EOF' >> /home/${USER_NAME}/.bashrc
# цветная подсказка и алиасы
export PS1="\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "
alias la='ls -A'
alias l='ls -CF'
alias ll='ls -alhFp'
alias hcg='cat ~/.bash_history | grep '
alias 7zip='7za a -t7z -m0=lzma2:d1536m:fb273:mf=bt4:lc4:pb2 -mx=9 -myx=9 -ms=4g -mqs=on -mmt=8 '
alias cls='clear;clear'
alias gcrs='git clone --recurse-submodules '
alias gprs='git pull  --recurse-submodules '

# User specific environment
LD_LIBRARY_PATH=/opt/riscv/lib:


if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]; then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
PATH="/opt/riscv/bin:$PATH"
export PATH
export CC=/opt/riscv/bin/riscv64-unknown-linux-gnu-gcc
export CXX=/opt/riscv/bin/riscv64-unknown-linux-gnu-g++
export CROSS_PREFIX=/opt/riscv/bin/riscv64-unknown-linux-gnu

# ========================================
path() {
    local old=$IFS
    IFS=:
    printf '%s\n' $PATH
    IFS=$old
}
# ---------------------------------
libs() {
    echo "LD_LIBRARY_PATH contents:"
    local old=$IFS
    IFS=:
    printf '%s\n' $LD_LIBRARY_PATH
    IFS=$old
}
EOF

# --- Rights for .bashrc ---
RUN chown ${USER_ID}:${GROUP_ID} /home/${USER_NAME}/.bashrc

# Working directory
WORKDIR /data

# Script to run when the container starts
CMD ["/bin/bash"]
