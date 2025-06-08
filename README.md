# svt-hhb3 – Dockerized HHB 3 (beta) tool‑chain for TH1520 / LicheePi 4A

> **Status:** Experimental – HHB 3 β API may change without notice.

## 1. Project Goals

* **One‑command setup** of an Ubuntu 22.04 image containing:

  * HHB ≥ 3.0 β – TVM‑based compiler for CSI‑NN/TH1520 (fork of Xuantie).
  * Xuantie RISC‑V GCC V2.8 (rv64gcv + th extensions) tool‑chain.
  * Full Python/ONNX/TVM stack, common ML libs and CLI niceties.
* **User‑mirrored UID/GID** – generated at build time so files created inside the container remain writable on the host.
* **Zero‑friction workflow** for converting models (e.g. YOLOv5n, MiDaS, Depth‑Anything V2…) to HHB binaries and running them on LicheePi 4A.

## 2. Repository Layout

```
.
├── build-docker.sh      # Build image & inject host UID/GID into .env
├── run-docker.sh        # Launch (or enter) the container via docker‑compose
├── docker-compose.yml   # Compose service definition (svt-hhb3)
├── Dockerfile           # Full image recipe (500+ MiB)
├── .env                 # Auto‑generated – stores USER_ID / GROUP_ID / HHB_VERSION
└── data/                # Mounted as /data inside the container
```

Additional helper scripts for model export / conversion live in the repo root (e.g. `01-export_to_onnx.py`, `03-convert_to_hhb.sh`).

## 3. Prerequisites

| Requirement       | Minimum Version      | Notes                                |
| ----------------- | -------------------- | ------------------------------------ |
| Docker Engine     |  23.0                | Buildx & BuildKit enabled by default |
| Docker Compose \* | CLI plugin v2        | Or standalone `docker‑compose` v1.x  |
| Host OS           | Linux / macOS / WSL2 | Tested primarily on RHEL 9.5        |

\* `build-docker.sh` / `run-docker.sh` will autodetect which binary is available.

## 4. Quick‑Start

```bash
# 1. Clone repository
git clone https://github.com/RISCY-SVT/svt-hhb3.git
cd svt-hhb3

# 2. (optional) pin HHB version
echo "HHB_VERSION=3.0.3b0" >> .env   # default is latest PyPI beta

# 3. Build the image (≈10‑15 minutes on first run)
./build-docker.sh

# 4. Enter the container (re‑uses image; restarts if stopped)
./run-docker.sh

hhb@container:/data$ hhb --version
HHB version: 3.0.3b0, build 20240512
```

All work should be done inside **/data** – which is bind‑mounted to `./data` on the host.

## 5. Typical Workflow

1. **Export your model to ONNX** (if it isn’t already).  Example:

   ```bash
   python 01-export_to_onnx.py --checkpoint weights.pth --output depth_anything_v2_vits.onnx
   ```
2. **Convert to HHB** using the provided helper script:

   ```bash
   bash 03-convert_to_hhb.sh \
        -m depth_anything_v2_vits.onnx \
        -b th1520 \
        --pixel-format BGR --quant int8_asym
   ```
3. Copy the generated `*.hhb` / compiled C code to the LicheePi 4A and build with CSI‑NN SDK or cross‑compiler.

## 6. Environment Variables (Docker ARG/ENV)

| Variable               | Default                                      | Purpose                                       |
| ---------------------- | -------------------------------------------- | --------------------------------------------- |
| `HHB_VERSION`          | latest                                       | HHB β package to install from PyPI            |
| `USER_ID` / `GROUP_ID` | host IDs                                     | Propagated automatically by `build-docker.sh` |
| `TOOLROOT`             | /opt/riscv                                   | Install prefix of Xuantie GCC tool‑chain      |
| `RISCV_CFLAGS`         | `-march=rv64gcv_zfh_xtheadc -mabi=lp64d -O3` | Sample flags                                  |

## 7. Updating the Image

If you change *Dockerfile* or wish to bump HHB, re‑run `./build-docker.sh`; it invalidates the build‑cache automatically.

## 8. Troubleshooting

| Symptom                       | Fix / Cause                                                |
| ----------------------------- | ---------------------------------------------------------- |
| `ModuleNotFoundError: tvm`    | Ensure the build completed successfully – rebuild          |
| `Permission denied` on /data  | Verify USER\_ID/GROUP\_ID in .env match your host user     |
| Slow download from Aliyun     | Mirror the Xuantie GCC URL locally and adjust Dockerfile   |
| HHB segfault inside container | Try a different HHB β tag; report upstream if reproducible |

## 9. Security Notes

* The container runs as *your* UID, not root, mitigating host file‑permission issues.
* `sudo` is pre‑installed **without password** *inside* the container; do **NOT** mount sensitive host paths unless required.

## 10. License

All original files in this repository are released under the Apache 2.0 license.  Third‑party components retain their respective licenses – see their individual projects for details.

## 11. Acknowledgements

* [T-Head / Xuantie CSI‑NN](https://github.com/THead-Semi/csi-nn2)
* [HHB TVM fork](https://github.com/RISCY-SVT/tvm)
* \[T-Head TH1520 NPU documentation]
