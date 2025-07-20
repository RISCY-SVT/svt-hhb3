# RISC-V Xuantie C920 Development Environment

A Docker-based development environment for building and testing the [csi-nn2](https://github.com/RISCY-SVT/csi-nn2) neural network library with focus on RISC-V Xuantie C920 processor and RVV 0.7.1 support.

## Overview

This project provides a containerized build environment with:
- **RISC-V Xuantie toolchain** (GCC V3.1.0 + LLVM V2.1.0)
- **HHB (Heterogeneous Honey Badger)** framework v3.2.3
- **SHL-Python** v3.2.2
- Pre-configured build flags for C920 optimization
- Python ML/AI development tools

## Prerequisites

- Docker Engine (20.10+)
- Docker Compose (V2 preferred, V1 supported)
- Linux/macOS host system
- At least 10GB free disk space

## Quick Start

1. **Clone the repository**
   ```bash
   git clone https://github.com/RISCY-SVT/svt-hhb3.git
   cd svt-hhb3
   ```

2. **Build the Docker image**
   ```bash
   ./build-docker.sh
   ```
   This script will:
   - Auto-detect your user/group IDs
   - Update `.env` with your system settings
   - Build the Docker image with all dependencies
   - Create a `data/` directory for persistent storage

3. **Run the container**
   ```bash
   ./run-docker.sh
   ```
   This will start the container and drop you into an interactive bash shell.

## Project Structure

```
.
├── .env                 # Environment variables (auto-generated)
├── build-docker.sh      # Build script
├── docker-compose.yml   # Docker Compose configuration
├── Dockerfile          # Container definition
├── run-docker.sh       # Run script
└── data/               # Persistent data directory (mounted as /data)
```

## Environment Details

### Base System
- **OS**: Ubuntu 22.04 LTS
- **Timezone**: Europe/Madrid (configurable in Dockerfile)
- **Locale**: en_US.UTF-8 (with ru_RU.UTF-8 support)

### RISC-V Toolchain
- **GCC**: Xuantie-900 V3.1.0 (Linux 6.6.0, glibc, x86_64)
- **LLVM**: Xuantie-900 V2.1.0 (Linux 6.6.0, glibc, x86_64)
- **Target**: `riscv64-unknown-linux-gnu`
- **Default CFLAGS**: `-march=rv64gcv0p7_zfh_xtheadc -mabi=lp64d -O3`

### Development Tools
- Build essentials (gcc, g++, make)
- CMake, Ninja build
- Clang-15, LLVM-15
- Python 3 with pip
- Version control (git)
- Editors (vim, mc)

### Python Packages
Core ML/AI libraries:
- NumPy (<2.0)
- PyTorch & TorchVision
- ONNX ecosystem (onnx, onnxruntime, onnx-simplifier, onnxslim)
- HHB framework (v3.2.3)
- SHL-Python (v3.2.2)
- Gradio for demos
- Scientific computing (scipy, matplotlib, sympy)

## Usage

### Basic Workflow

1. **Place your source code in `data/`**
   ```bash
   cd /data/
   gcrs https://github.com/RISCY-SVT/csi-nn2.git
   ```

2. **Inside the container, navigate to your project**
   ```bash
   cd /data/csi-nn2
   ```

3. **Build with C920 optimizations**
   ```bash
   make clean nn2_c920
   ```

### Environment Variables

Pre-configured in the container:
- `CC`: `/opt/riscv/bin/riscv64-unknown-linux-gnu-gcc`
- `CXX`: `/opt/riscv/bin/riscv64-unknown-linux-gnu-g++`
- `CROSS_PREFIX`: `/opt/riscv/bin/riscv64-unknown-linux-gnu`
- `TOOLROOT`: `/opt/riscv`
- `ZSTD_LIB_DIR`: `/usr/lib/x86_64-linux-gnu`

### Build Flags for C920

The recommended build flags for Xuantie C920:
```make
TOOLS_PREFIX = riscv64-unknown-linux-gnu
CFLAGS = -march=rv64gcv0p7_zfh_xtheadc_xtheadvdot -mabi=lp64d -mtune=c920 -fopenmp
```

### Useful Aliases

The container includes helpful bash aliases:
- `ll` - Detailed file listing
- `gcrs` - Git clone with submodules
- `gprs` - Git pull with submodules
- `hcg` - Search bash history
- `7zip` - High compression 7z archiving
- `path` - Display PATH entries
- `libs` - Display LD_LIBRARY_PATH entries

## Advanced Configuration

### Modifying the Environment

1. **Change toolchain version**: Edit the URLs in the Dockerfile's toolchain installation section
2. **Add Python packages**: Modify the `pip3 install` section in Dockerfile
3. **Change timezone**: Update `ENV TZ=` in Dockerfile
4. **Adjust build flags**: Modify `ENV RISCV_CFLAGS=` in Dockerfile

### Persistent Storage

The `./data` directory is mounted as `/data` inside the container. All files placed here will persist between container restarts.

## Troubleshooting

### Common Issues

1. **Permission errors**
   - The build script automatically detects your UID/GID
   - If issues persist, manually set in `.env`:
     ```
     USER_ID=1000
     GROUP_ID=1000
     ```

2. **Out of space during build**
   ```bash
   docker system prune -a
   ```

3. **Container already exists**
   ```bash
   docker rm svt-hhb3-310
   ./run-docker.sh
   ```

### Rebuilding

To force a complete rebuild:
```bash
docker compose down
docker rmi custler/svt-hhb3-310:latest
./build-docker.sh
```

## Technical Notes

### Security Considerations
- Container runs as non-root user (your host UID/GID)
- Sudo access configured with NOPASSWD for development convenience
- Network isolation enabled by default

### Performance Optimization
- OpenMP enabled in default CFLAGS
- Multi-threaded build support (`-j$(nproc)`)
- Optimized for C920 microarchitecture

## Contributing

When contributing to this project:
1. Test your changes in a clean build
2. Document any new dependencies in the README
3. Follow the existing code style
4. Update version numbers in `.env` when upgrading tools

## License

All original files in this repository are released under the Apache 2.0 license. Third‑party components retain their respective licenses – see their individual projects for details.

## Acknowledgments

- RISC-V Xuantie toolchain by T-Head/Alibaba
- HHB framework for heterogeneous computing
- csi-nn2 neural network library

---

For issues and questions, please open a GitHub issue or contact the maintainers.
