# OnePlus Ace 6T GKI 内核构建器

**[English](README.md) | [中文](README_ZH.md)**

一个基于 GitHub Actions 的自动化 GKI 内核构建流水线，适用于一加 Ace 6T（KMI：`android16-6.12`）。

支持 [SukiSU Ultra](https://github.com/SukiSU-Ultra/SukiSU-Ultra)、[ReSukiSU](https://github.com/ReSukiSU/ReSukiSU)、[SUSFS](https://gitlab.com/simonpunk/susfs4ksu)、[KPM](https://github.com/SukiSU-Ultra/SukiSU_KernelPatch_patch)、[ADIOS 调度器](https://github.com/firelzrd/adios) 等特性集成。

---

## 功能特性

| 功能 | 说明 |
|------|------|
| **SukiSU Ultra** | 基于 KernelSU 的 Root 方案，使用 `builtin` 分支（稳定，兼容 GKI 6.12） |
| **ReSukiSU** | SukiSU 的另一实现，可通过 `SU_TYPE` 参数切换 |
| **SUSFS** | 内核级文件系统伪装，增强 Root 隐藏能力 |
| **KPM** | Kernel Patch Module，允许在内核运行时动态加载补丁 |
| **ADIOS 调度器** | 面向 Android 优化的 I/O 调度器，提升响应速度 |
| **代理网络优化** | 注入 BPF / iptables 相关 CONFIG，支持透明代理场景 |

---

## 使用说明

### 手动触发构建

1. 前往 GitHub 仓库 → **Actions** → **Build SukiSU Kernel**
2. 点击 **Run workflow**，按需填写参数：

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `SUKISU_BRANCH` | SukiSU Ultra 分支/Tag（仅 SukiSU_Ultra 生效，`builtin` 表示最新稳定 Tag） | `builtin` |
| `FEIL` | 产物文件名前缀 | `gki` |
| `ANDROID_VERSION` | Android 版本 | `android16` |
| `KERNEL_VERSION` | 内核版本 | `6.12` |
| `KERNEL_MANIFEST` | 内核 manifest 分支 | `common-android16-6.12-2025-09` |
| `SU_TYPE` | 集成类型：`SukiSU_Ultra` 或 `ReSukiSU` | `SukiSU_Ultra` |
| `KPM` | 是否启用 KPM | `On` |
| `APPLY_ADIOS` | 是否应用 ADIOS 补丁 | `On` |
| `ADIOS_URL` | ADIOS 补丁下载链接 | 最新稳定版链接 |
| `proxy` | 是否注入代理优化 CONFIG | `On` |

3. 构建完成后，在 **Artifacts** 里下载 zip 刷机包（AnyKernel3 格式）。

---

## SU_TYPE 说明

| 类型 | 说明 |
|------|------|
| `SukiSU_Ultra` | 使用官方 [SukiSU Ultra builtin 分支](https://github.com/SukiSU-Ultra/SukiSU-Ultra) 集成，稳定，适合日常使用 |
| `ReSukiSU` | 使用 [ReSukiSU](https://github.com/ReSukiSU/ReSukiSU) 实现，需要 `KALLSYMS`、`KPROBES` 等额外 CONFIG |

> **注意**：SukiSU Ultra 请务必使用 `builtin` 分支（而非 `main`）。  
> `main` 分支是 SukiSU Ultra 的完整开发主线（含用户态 App、ksud 等），**不能用于内核编译**，强行使用会因 KPM 代码依赖新内核 ABI 而导致编译报错。  
> `builtin` 分支是官方专为内核集成提供的稳定分支，对 GKI 6.12 做了完整适配。

---

## 补丁说明

| 补丁文件 | 说明 |
|----------|------|
| `patch/sukisu_fix.patch` | 修复 LSM 计数溢出（扩展 `COUNT_ARGS` 上限，为 KSU 预留 LSM slot，防止 "Too many LSMs registered" Panic） |
| `patch/unicode_bypass_fix.patch` | 修复 Android 内核中的零宽字符问题 |
| `patch/resukisu_kbuild_bazel_fix.patch` | ReSukiSU 专用：移除 `drivers/kernelsu/Kbuild` 中因缺少 git submodule 而中止 Bazel 构建的 `$(error ...)` 检查 |

---

## 其他 KMI 版本兼容性说明

本项目主要针对 `android16-6.12` 进行开发和测试，理论上可通过调整参数支持其他 KMI 版本，但存在以下限制：

| 场景 | 可行性 | 说明 |
|------|--------|------|
| `android16-6.12` 不同月份快照（如 `2025-12`、`2026-03`） | ✅ 基本可行 | 主要风险是 `patch/` 目录的三个补丁在新快照上是否还能干净应用 |
| `android15-6.6` | ⚠️ 有一定可行性 | 需确认 SUSFS 有对应分支，且替换或跳过不兼容的补丁文件 |
| `android14-6.1` 及更早 | ⚠️ 需较多适配 | SUSFS 分支、patch 文件均需替换，Bazel 版本也可能不同 |
| 非 arm64 架构（如 x86_64） | ❌ 不支持 | 编译目标 `kernel_aarch64_dist` 和 defconfig 路径均硬编码为 arm64 |

> `patch/` 目录下的三个补丁均基于 `android16-6.12` 编写，切换 KMI 时需自行验证兼容性。

---

## 风险说明

- 这是实验性内核，仅供了解内核级修改风险的开发者和高级用户使用。
- 修改内核系统调用具有侵入性，可能导致 Kernel Panic 或系统不稳定。
- 刷入前请备份重要数据，并确认设备已解锁 Bootloader。
- 本项目不对任何设备损坏或数据丢失负责。

---

## 鸣谢

- [SukiSU-Ultra](https://github.com/SukiSU-Ultra/SukiSU-Ultra) — KernelSU 的 SukiSU 实现
- [ReSukiSU](https://github.com/ReSukiSU/ReSukiSU) — ReSukiSU 实现
- [susfs4ksu](https://gitlab.com/simonpunk/susfs4ksu) — SUSFS 内核补丁
- [SukiSU_KernelPatch_patch](https://github.com/SukiSU-Ultra/SukiSU_KernelPatch_patch) — KPM 修补工具
- [ADIOS](https://github.com/firelzrd/adios) — Android 优化 I/O 调度器
- [AnyKernel3](https://github.com/WildKernels/AnyKernel3) — 刷机包打包工具
- [superturtlee/HymoFS](https://github.com/superturtlee/HymoFS) — 原始 workflow 参考来源
