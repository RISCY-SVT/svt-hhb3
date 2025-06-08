FROM ubuntu:22.04

# Accept arguments for UID and GID
ARG USER_ID=1000
ARG GROUP_ID=1000
ARG USER_NAME
ARG HHB_VERSION

# Setting timezone non-interactively
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Madrid

# Installation of basic packages
RUN apt update && apt install -y --no-install-recommends \
    aptitude \
    build-essential \
    clang-15 \
    cmake \
    curl \
    git \
    libedit-dev \
    libgl1 libglib2.0-0 libsm6 libxext6 \
    libncurses5-dev \
    libxml2-dev \
    libz-dev \
    libzstd-dev \
    llvm-15 \
    locales \
    mc \
    ninja-build \
    p7zip-full \
    python3 \
    python3-dev \
    python3-pip \
    python3-setuptools \
    rsync \
    sudo \
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
    shl-python==3.0.3b0 \
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
ENV RISCV_CFLAGS="-march=rv64gcv_zfh_xtheadc -mabi=lp64d -O3"

# Скачивание и установка RISC-V тулчейна Xuantie
RUN mkdir -p /tmp/toolchain && \
    cd /tmp/toolchain && \
    wget -q https://occ-oss-prod.oss-cn-hangzhou.aliyuncs.com/resource//1698113812618/Xuantie-900-gcc-linux-5.10.4-glibc-x86_64-V2.8.0-20231018.tar.gz && \
    mkdir -p /opt/riscv && \
    tar -xzf Xuantie-900-gcc-linux-5.10.4-glibc-x86_64-V2.8.0-20231018.tar.gz -C /opt/riscv --strip-components=1 && \
    rm -rf /tmp/toolchain && \
    /opt/riscv/bin/riscv64-unknown-linux-gnu-gcc --version

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
