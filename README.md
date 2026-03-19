# OnePlus Ace 6T GKI Kernel Builder

**[English](README.md) | [中文](README_ZH.md)**

An automated GKI kernel build pipeline based on GitHub Actions, targeting the OnePlus Ace 6T (KMI: `android16-6.12`).

Supports integration of [SukiSU Ultra](https://github.com/SukiSU-Ultra/SukiSU-Ultra), [ReSukiSU](https://github.com/ReSukiSU/ReSukiSU), [SUSFS](https://gitlab.com/simonpunk/susfs4ksu), [KPM](https://github.com/SukiSU-Ultra/SukiSU_KernelPatch_patch), and the [ADIOS I/O scheduler](https://github.com/firelzrd/adios).

---

## Features

| Feature | Description |
|---------|-------------|
| **SukiSU Ultra** | KernelSU-based root solution using the `builtin` branch (stable, GKI 6.12 compatible) |
| **ReSukiSU** | Alternative SukiSU implementation, switchable via `SU_TYPE` parameter |
| **SUSFS** | Kernel-level filesystem spoofing for enhanced root hiding |
| **KPM** | Kernel Patch Module — dynamically load patches at runtime |
| **ADIOS Scheduler** | Android-optimized I/O scheduler for improved responsiveness |
| **Proxy Network Config** | Injects BPF / iptables-related CONFIGs for transparent proxy support |

---

## Usage

### Trigger a Build Manually

1. Go to your GitHub repository → **Actions** → **Build SukiSU Kernel**
2. Click **Run workflow** and fill in the parameters as needed:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `SUKISU_BRANCH` | SukiSU Ultra branch/tag (only applies to `SukiSU_Ultra`; `builtin` = latest stable tag) | `builtin` |
| `FEIL` | Output filename prefix | `gki` |
| `ANDROID_VERSION` | Android version | `android16` |
| `KERNEL_VERSION` | Kernel version | `6.12` |
| `KERNEL_MANIFEST` | Kernel manifest branch | `common-android16-6.12-2025-09` |
| `SU_TYPE` | Integration type: `SukiSU_Ultra` or `ReSukiSU` | `SukiSU_Ultra` |
| `KPM` | Enable KPM patching | `On` |
| `APPLY_ADIOS` | Apply ADIOS scheduler patch | `On` |
| `ADIOS_URL` | ADIOS patch download URL | Latest stable link |
| `proxy` | Inject proxy optimization CONFIGs | `On` |

3. Once the build completes, download the flashable zip (AnyKernel3 format) from **Artifacts**.

---

## SU_TYPE Explained

| Type | Description |
|------|-------------|
| `SukiSU_Ultra` | Integrates via the official [SukiSU Ultra `builtin` branch](https://github.com/SukiSU-Ultra/SukiSU-Ultra). Stable, recommended for daily use. |
| `ReSukiSU` | Integrates via [ReSukiSU](https://github.com/ReSukiSU/ReSukiSU). Requires additional CONFIGs: `KALLSYMS`, `KALLSYMS_ALL`, `KPROBES`. |

> **Important:** Always use the `builtin` branch for SukiSU Ultra — **never `main`**.  
> The `main` branch is the full development mainline (including the userspace App, ksud, etc.) and **cannot be used for kernel compilation**.  
> Using `main` will cause build failures because its KPM code depends on kernel ABI changes not yet adapted for GKI 6.12.  
> The `builtin` branch is the officially maintained kernel-integration branch, fully compatible with GKI 6.12.

---

## Patch Overview

| Patch File | Description |
|------------|-------------|
| `patch/sukisu_fix.patch` | Fixes LSM count overflow — extends `COUNT_ARGS` limit and reserves an LSM slot for KSU, preventing "Too many LSMs registered" kernel panic |
| `patch/unicode_bypass_fix.patch` | Fixes a compile issue in `fs/unicode/utf8-norm.c` |
| `patch/resukisu_kbuild_bazel_fix.patch` | ReSukiSU only: removes the `$(error ...)` abort in `drivers/kernelsu/Kbuild` that triggers when a git submodule is missing during Bazel builds |

---

## Other KMI Version Compatibility

This project is developed and tested primarily against `android16-6.12`. Other KMI versions may work with parameter adjustments, but with the following limitations:

| Scenario | Feasibility | Notes |
|----------|-------------|-------|
| `android16-6.12` different monthly snapshots (e.g. `2025-12`, `2026-03`) | ✅ Generally works | Main risk is whether the patches in `patch/` still apply cleanly on newer snapshots |
| `android15-6.6` | ⚠️ Partially feasible | Requires confirming SUSFS has the corresponding branch and replacing/skipping incompatible patches |
| `android14-6.1` and earlier | ⚠️ Requires significant adaptation | SUSFS branch, patch files, and possibly Bazel version all need adjustment |
| Non-arm64 architectures (e.g. x86_64) | ❌ Not supported | Build target `kernel_aarch64_dist` and defconfig path are hardcoded for arm64 |

> All three patches in `patch/` are written for `android16-6.12`. Please verify compatibility when switching KMI versions.

---

## Disclaimer

- This is an experimental kernel intended for developers and advanced users who understand the risks of kernel-level modifications.
- Modifying kernel syscalls is highly intrusive and may cause kernel panics or system instability.
- Back up your important data before flashing, and ensure your bootloader is unlocked.
- This project is not responsible for any device damage or data loss.

---

## Credits

- [SukiSU-Ultra](https://github.com/SukiSU-Ultra/SukiSU-Ultra) — SukiSU implementation of KernelSU
- [ReSukiSU](https://github.com/ReSukiSU/ReSukiSU) — ReSukiSU implementation
- [susfs4ksu](https://gitlab.com/simonpunk/susfs4ksu) — SUSFS kernel patches
- [SukiSU_KernelPatch_patch](https://github.com/SukiSU-Ultra/SukiSU_KernelPatch_patch) — KPM patching tool
- [ADIOS](https://github.com/firelzrd/adios) — Android-optimized I/O scheduler
- [AnyKernel3](https://github.com/WildKernels/AnyKernel3) — Flashable zip packaging tool
- [superturtlee/HymoFS](https://github.com/superturtlee/HymoFS) — Original workflow reference
