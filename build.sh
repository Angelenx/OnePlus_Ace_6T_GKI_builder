#!/bin/bash
# =============================================================================
# GKI 内核本地编译脚本
# 与 .github/workflows/gki-kernel.yaml 保持一致的构建逻辑
# 用法: ./build.sh [选项...]
#       或直接设置环境变量后执行: SU_TYPE=ReSukiSU ./build.sh
# =============================================================================

set -euo pipefail

# ====================== 颜色输出 ======================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC}   $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERR]${NC}  $*" >&2; exit 1; }
step()    { CURRENT_STEP="$*"; echo -e "\n${BLUE}====== $* ======${NC}"; }

# ====================== 配置项（可通过环境变量覆盖） ======================
SUKISU_BRANCH="${SUKISU_BRANCH:-builtin}"
FEIL="${FEIL:-gki}"
ANDROID_VERSION="${ANDROID_VERSION:-android16}"
KERNEL_VERSION="${KERNEL_VERSION:-6.12}"
KPM="${KPM:-On}"
PROXY="${PROXY:-On}"
APPLY_ADIOS="${APPLY_ADIOS:-On}"
ADIOS_URL="${ADIOS_URL:-https://github.com/firelzrd/adios/raw/refs/heads/main/patches/stable/0001-linux6.12.44-ADIOS-3.1.9.patch}"
KERNEL_MANIFEST="${KERNEL_MANIFEST:-common-android16-6.12-2025-09}"
SU_TYPE="${SU_TYPE:-SukiSU}"

# ====================== 路径配置 ======================
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 与 GitHub Actions 一致：在仓库根目录下创建 kernel_workspace / AnyKernel3
BUILD_DIR="${BUILD_DIR:-${REPO_ROOT}}"

# ====================== 全局状态追踪 ======================
CURRENT_STEP="初始化"
BUILD_START=0
BUILD_END=0

# ====================== 全局 trap：错误兜底 ======================
on_error() {
    local lineno="$1"
    echo ""
    echo -e "${RED}══════════════════════════════════════════${NC}"
    echo -e "${RED}  构建失败！${NC}"
    echo -e "${RED}  出错阶段 : ${CURRENT_STEP}${NC}"
    echo -e "${RED}  出错行号 : 第 ${lineno} 行${NC}"
    if [[ -n "${LOG_FILE:-}" && -f "${LOG_FILE}" ]]; then
        echo -e "${RED}  完整日志 : ${LOG_FILE}${NC}"
        echo ""
        echo -e "${YELLOW}  最后 20 行日志:${NC}"
        tail -n 20 "${LOG_FILE}" | sed 's/^/    /'
    fi
    echo -e "${RED}══════════════════════════════════════════${NC}"
}
trap 'on_error $LINENO' ERR

# ====================== 解析命令行参数 ======================
usage() {
    cat <<EOF
用法: $(basename "$0") [选项]

选项:
  --su-type       <SukiSU|ReSukiSU>     KSU 集成类型     (默认: ${SU_TYPE})
  --branch        <分支名>              SukiSU 分支      (默认: ${SUKISU_BRANCH})
  --manifest      <manifest分支>        内核 manifest    (默认: ${KERNEL_MANIFEST})
  --android       <android版本>         Android 版本     (默认: ${ANDROID_VERSION})
  --kernel        <内核版本>            内核版本         (默认: ${KERNEL_VERSION})
  --feil          <前缀>                产物文件名前缀   (默认: ${FEIL})
  --kpm           <On|Off>              启用 KPM 补丁    (默认: ${KPM})
  --proxy         <On|Off>              代理优化 CONFIG  (默认: ${PROXY})
  --adios         <On|Off>              应用 ADIOS 补丁  (默认: ${APPLY_ADIOS})
  --adios-url     <URL>                 ADIOS 补丁地址
  --build-dir     <路径>                指定编译工作目录 (默认: ${BUILD_DIR})
  -h, --help                            显示此帮助信息

示例:
  ./build.sh --su-type ReSukiSU --kpm Off
  SU_TYPE=ReSukiSU KPM=Off ./build.sh
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --su-type)    SU_TYPE="$2";         shift 2 ;;
        --branch)     SUKISU_BRANCH="$2";   shift 2 ;;
        --manifest)   KERNEL_MANIFEST="$2"; shift 2 ;;
        --android)    ANDROID_VERSION="$2"; shift 2 ;;
        --kernel)     KERNEL_VERSION="$2";  shift 2 ;;
        --feil)       FEIL="$2";            shift 2 ;;
        --kpm)        KPM="$2";             shift 2 ;;
        --proxy)      PROXY="$2";           shift 2 ;;
        --adios)      APPLY_ADIOS="$2";     shift 2 ;;
        --adios-url)  ADIOS_URL="$2";       shift 2 ;;
        --build-dir)  BUILD_DIR="$2";       shift 2 ;;
        -h|--help)    usage ;;
        *) error "未知参数: $1，使用 --help 查看帮助" ;;
    esac
done

# ====================== 交互式确认 / 补充参数 ======================
step "交互式参数确认"

ask_with_default() {
    local var_name="$1" prompt="$2" current="$3"
    local input
    read -r -p "${prompt} [${current}]: " input
    if [[ -n "${input}" ]]; then
        printf -v "${var_name}" '%s' "${input}"
    fi
}

echo "按回车将采用当前默认值，输入新值可覆盖。"
echo ""

ask_with_default SU_TYPE         "选择 KSU 类型 (SukiSU / ReSukiSU)"        "${SU_TYPE}"
ask_with_default SUKISU_BRANCH   "SukiSU Ultra 分支"                        "${SUKISU_BRANCH}"
ask_with_default KERNEL_MANIFEST "内核 manifest 分支"                       "${KERNEL_MANIFEST}"
ask_with_default ANDROID_VERSION "Android 版本"                             "${ANDROID_VERSION}"
ask_with_default KERNEL_VERSION  "内核版本"                                 "${KERNEL_VERSION}"
ask_with_default FEIL            "产物文件名前缀"                           "${FEIL}"
ask_with_default KPM             "是否启用 KPM (On/Off)"                    "${KPM}"
ask_with_default PROXY           "是否启用代理优化 CONFIG (On/Off)"        "${PROXY}"
ask_with_default APPLY_ADIOS     "是否应用 ADIOS 补丁 (On/Off)"            "${APPLY_ADIOS}"
ask_with_default ADIOS_URL       "ADIOS 补丁链接"                           "${ADIOS_URL}"
ask_with_default BUILD_DIR       "编译工作目录"                             "${BUILD_DIR}"

# ====================== 参数合法性校验 ======================
step "参数校验"

validate_onoff() {
    local val="$1" name="$2"
    [[ "${val}" == "On" || "${val}" == "Off" ]] \
        || error "${name} 必须是 On 或 Off，当前值: '${val}'"
}

[[ "${SU_TYPE}" == "SukiSU" || "${SU_TYPE}" == "ReSukiSU" ]] \
    || error "SU_TYPE 必须是 SukiSU 或 ReSukiSU，当前值: '${SU_TYPE}'"
validate_onoff "${KPM}"         "KPM"
validate_onoff "${PROXY}"       "PROXY"
validate_onoff "${APPLY_ADIOS}" "APPLY_ADIOS"

[[ -n "${KERNEL_MANIFEST}" ]]  || error "KERNEL_MANIFEST 不能为空"
[[ -n "${ANDROID_VERSION}" ]]  || error "ANDROID_VERSION 不能为空"
[[ -n "${KERNEL_VERSION}" ]]   || error "KERNEL_VERSION 不能为空"

success "参数校验通过"

# ====================== 初始化工作目录 & 日志 ======================
mkdir -p "${BUILD_DIR}"
LOG_FILE="${BUILD_DIR}/build_$(date +%Y%m%d_%H%M%S).log"
# 同时输出到终端和日志文件
exec > >(tee -a "${LOG_FILE}") 2>&1
info "构建日志: ${LOG_FILE}"

# ====================== 打印当前配置 ======================
step "编译配置"
cat <<EOF
  SU_TYPE         : ${SU_TYPE}
  SUKISU_BRANCH   : ${SUKISU_BRANCH}
  KERNEL_MANIFEST : ${KERNEL_MANIFEST}
  ANDROID_VERSION : ${ANDROID_VERSION}
  KERNEL_VERSION  : ${KERNEL_VERSION}
  FEIL            : ${FEIL}
  KPM             : ${KPM}
  PROXY           : ${PROXY}
  APPLY_ADIOS     : ${APPLY_ADIOS}
  BUILD_DIR       : ${BUILD_DIR}
  REPO_ROOT       : ${REPO_ROOT}
  LOG_FILE        : ${LOG_FILE}
EOF

# ====================== 网络重试工具函数 ======================
# 用法: retry <最大次数> <延迟秒> <命令...>
retry() {
    local max="$1" delay="$2"
    shift 2
    local count=0
    until "$@"; do
        count=$(( count + 1 ))
        if [[ ${count} -ge ${max} ]]; then
            error "命令在重试 ${max} 次后仍然失败: $*"
        fi
        warn "第 ${count}/${max} 次重试（${delay}s 后）: $*"
        sleep "${delay}"
    done
}

# ====================== 磁盘空间检查 ======================
step "磁盘空间检查"
# 先确保目录存在再查
mkdir -p "${BUILD_DIR}"
AVAIL_KB=$(df -k "${BUILD_DIR}" 2>/dev/null | awk 'NR==2{print $4}' || echo "0")
AVAIL_GB=$(( AVAIL_KB / 1024 / 1024 ))
info "可用磁盘空间: ${AVAIL_GB}G（挂载点: $(df -k "${BUILD_DIR}" | awk 'NR==2{print $1}')）"
if [[ "${AVAIL_GB}" -lt 60 ]]; then
    warn "剩余磁盘空间不足 60G（当前: ${AVAIL_GB}G），编译可能失败（推荐 80G+）"
    warn "如确认空间足够请忽略，脚本将继续"
fi

# ====================== 检查本地 patch 文件 ======================
step "检查补丁文件"
PATCH_DIR="${REPO_ROOT}/patch"
for f in sukisu_fix.patch unicode_bypass_fix.patch; do
    if [[ ! -f "${PATCH_DIR}/${f}" ]]; then
        error "缺少必要补丁文件: ${PATCH_DIR}/${f}"
    fi
done
success "补丁文件检查通过"

# ====================== 安装系统依赖 ======================
step "安装构建依赖"
DEPS=(python3 git curl libelf-dev build-essential flex bison
      libssl-dev libncurses-dev liblz4-tool zlib1g-dev
      libxml2-utils rsync unzip gawk dos2unix wget)

MISSING=()
for pkg in "${DEPS[@]}"; do
    dpkg -s "${pkg}" &>/dev/null || MISSING+=("${pkg}")
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
    info "安装缺失依赖: ${MISSING[*]}"
    retry 3 5 sudo apt-get update -qq
    retry 3 5 sudo apt-get install -y "${MISSING[@]}"
else
    success "所有依赖已满足"
fi

# ====================== 配置 git 用户（避免 repo 某些操作报错） ======================
step "配置 Git 用户信息"
git config --global user.name  "build"          2>/dev/null || true
git config --global user.email "build@local"    2>/dev/null || true
success "Git 用户配置完成"

# ====================== 安装 repo 工具 ======================
step "安装 repo 工具"
if ! command -v repo &>/dev/null; then
    info "正在下载 repo..."
    retry 3 5 curl -fsSL https://storage.googleapis.com/git-repo-downloads/repo \
        -o /tmp/repo
    chmod a+x /tmp/repo
    sudo mv /tmp/repo /usr/local/bin/repo
    success "repo 工具安装完成"
else
    success "repo 工具已存在: $(repo --version 2>&1 | head -1)"
fi

# ====================== 进入工作目录 ======================
cd "${BUILD_DIR}"
info "工作目录: $(pwd)"

# ====================== 克隆 AnyKernel3 ======================
step "克隆 AnyKernel3"
if [[ ! -d AnyKernel3 ]]; then
    retry 3 10 git clone https://github.com/WildKernels/AnyKernel3 --depth=1
    rm -rf ./AnyKernel3/.git
    success "AnyKernel3 克隆完成"
else
    warn "AnyKernel3 目录已存在，跳过克隆"
fi

# ====================== 同步内核源码 ======================
step "同步内核源码"
mkdir -p kernel_workspace/kernel_platform
cd kernel_workspace/kernel_platform

if [[ ! -d .repo ]]; then
    info "初始化内核仓库 (manifest: ${KERNEL_MANIFEST})..."
    retry 3 15 repo init \
        -u https://android.googlesource.com/kernel/manifest \
        -b "${KERNEL_MANIFEST}" \
        --depth=1
else
    warn ".repo 目录已存在，跳过 repo init（若需切换 manifest 请先手动删除 .repo）"
fi

NPROC=4
info "同步代码库（使用 ${NPROC} 线程，已写死为 4）..."
retry 3 30 repo sync -c -j"${NPROC}" --no-tags --no-clone-bundle --force-sync

cd ../
success "内核源码同步完成"

# 验证关键目录
[[ -d "kernel_platform/common" ]] \
    || error "同步后未找到 kernel_platform/common，repo sync 可能不完整"

# ====================== 提醒备份源码 ======================
step "备份源码确认（可选但强烈建议）"
echo "内核源码已同步到:"
echo "  ${BUILD_DIR}/kernel_workspace/kernel_platform"
echo ""
echo "建议现在先备份一份原始源码，例如："
echo "  cd \"${BUILD_DIR}\""
echo "  tar czf kernel_platform_backup.tgz kernel_workspace/kernel_platform"
echo ""
read -r -p "是否已完成备份，继续后续打补丁 / 集成 KSU / SUSFS？ [y/N]: " CONFIRM_BACKUP
case "${CONFIRM_BACKUP}" in
    y|Y)
        success "用户已确认备份，继续构建流程。"
        ;;
    *)
        warn "用户未确认备份，构建流程在此安全退出。源码保持同步后的原始状态。"
        exit 0
        ;;
esac

# 删除 protected_module_names_list 限制
if grep -q 'protected_module_names_list' kernel_platform/common/BUILD.bazel 2>/dev/null; then
    sed -i '/protected_module_names_list = ":gki_aarch64_protected_module_names",/d' \
        kernel_platform/common/BUILD.bazel
    info "已移除 protected_module_names_list 限制"
fi

# 去除 -dirty 版本标记
info "清理 -dirty 版本标记..."
for f in kernel_platform/common/scripts/setlocalversion \
          kernel_platform/external/dtc/scripts/setlocalversion; do
    if [[ -f "$f" ]]; then
        sed -i 's/ -dirty//g' "$f" || true
        sed -i '$i res=$(echo "$res" | sed '\''s/-dirty//g'\'')' "$f" || true
    fi
done
if [[ -f kernel_platform/msm-kernel/scripts/setlocalversion ]]; then
    sed -i 's/ -dirty//g' \
        kernel_platform/msm-kernel/scripts/setlocalversion || true
    sed -i '$i res=$(echo "$res" | sed '\''s/-dirty//g'\'')' \
        kernel_platform/msm-kernel/scripts/setlocalversion || true
fi
success "内核版本配置完成"

# ====================== 集成 KernelSU ======================
step "集成 KernelSU (${SU_TYPE})"
cd "${BUILD_DIR}/kernel_workspace/kernel_platform"

if [[ "${SU_TYPE}" == "ReSukiSU" ]]; then
    info "正在设置 ReSukiSU..."
    # 下载 setup.sh 到临时文件，避免 curl 失败时 bash 空执行
    TMP_SETUP=$(mktemp /tmp/resukisu_setup_XXXXXX.sh)
    retry 3 10 curl -LSs \
        "https://raw.githubusercontent.com/ReSukiSU/ReSukiSU/main/kernel/setup.sh" \
        -o "${TMP_SETUP}"
    bash "${TMP_SETUP}"
    rm -f "${TMP_SETUP}"
    success "ReSukiSU 配置完成"
else
    info "正在设置 SukiSU Ultra (branch: ${SUKISU_BRANCH})..."
    TMP_SETUP=$(mktemp /tmp/sukisu_setup_XXXXXX.sh)
    retry 3 10 curl -LSs \
        "https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU-Ultra/builtin/kernel/setup.sh" \
        -o "${TMP_SETUP}"
    bash "${TMP_SETUP}" "${SUKISU_BRANCH}"
    rm -f "${TMP_SETUP}"
    success "SukiSU Ultra 配置完成"
fi

# 验证 KernelSU 是否真正注入成功
if [[ ! -d "common/drivers/kernelsu" ]]; then
    error "KernelSU 集成失败：common/drivers/kernelsu 目录不存在，请检查 setup.sh 执行结果"
fi
success "KernelSU 注入验证通过"

# ====================== 配置 SUSFS ======================
step "配置 SUSFS"
cd "${BUILD_DIR}/kernel_workspace"

SUSFS_BRANCH="gki-${ANDROID_VERSION}-${KERNEL_VERSION}"
SUSFS_PATCH="50_add_susfs_in_gki-${ANDROID_VERSION}-${KERNEL_VERSION}.patch"

if [[ ! -d susfs4ksu ]]; then
    info "克隆 susfs4ksu (branch: ${SUSFS_BRANCH})..."
    retry 3 10 git clone https://gitlab.com/simonpunk/susfs4ksu.git \
        -b "${SUSFS_BRANCH}"
else
    warn "susfs4ksu 目录已存在，跳过克隆"
fi

# 验证补丁文件存在
[[ -f "susfs4ksu/kernel_patches/${SUSFS_PATCH}" ]] \
    || error "SUSFS 补丁文件不存在: susfs4ksu/kernel_patches/${SUSFS_PATCH}"
[[ -d "susfs4ksu/kernel_patches/fs" ]] \
    || error "SUSFS fs 目录不存在: susfs4ksu/kernel_patches/fs/"
[[ -d "susfs4ksu/kernel_patches/include/linux" ]] \
    || error "SUSFS include 目录不存在: susfs4ksu/kernel_patches/include/linux/"

cd kernel_platform
info "复制 SUSFS 补丁文件..."
# 目录结构与 gki-kernel.yaml 保持一致：
# REPO_ROOT/
#   kernel_workspace/
#     susfs4ksu/
#     kernel_platform/
cp "../susfs4ksu/kernel_patches/${SUSFS_PATCH}" ./common/
cp ../susfs4ksu/kernel_patches/fs/*             ./common/fs/
cp ../susfs4ksu/kernel_patches/include/linux/*  ./common/include/linux/

cd common
info "应用 SUSFS 补丁..."
patch -p1 < "${SUSFS_PATCH}" || true
success "SUSFS 补丁应用完成"

# ====================== 应用修复补丁 ======================
step "应用 Fix 补丁"
cd "${BUILD_DIR}/kernel_workspace/kernel_platform/common"

info "应用 sukisu_fix.patch..."
patch -p1 --forward < "${PATCH_DIR}/sukisu_fix.patch" || true

info "应用 unicode_bypass_fix.patch..."
patch -p1 --forward < "${PATCH_DIR}/unicode_bypass_fix.patch" || true

if [[ "${SU_TYPE}" == "ReSukiSU" ]]; then
    info "应用 resukisu_kbuild_bazel_fix.patch..."
    patch -p1 --forward --fuzz=6 --ignore-whitespace < "${PATCH_DIR}/resukisu_kbuild_bazel_fix.patch" || true
fi

success "Fix 补丁应用完成"

# ====================== 应用 ADIOS 补丁（可选） ======================
if [[ "${APPLY_ADIOS}" == "On" ]]; then
    step "应用 ADIOS 补丁"
    cd "${BUILD_DIR}/kernel_workspace/kernel_platform/common"
    ADIOS_PATCH="0001-adios.patch"
    info "下载 ADIOS 补丁..."
    retry 3 10 wget -q "${ADIOS_URL}" -O "${ADIOS_PATCH}"

    [[ -s "${ADIOS_PATCH}" ]] \
        || error "ADIOS 补丁下载为空: ${ADIOS_URL}"

    patch -p1 -F 3 < "${ADIOS_PATCH}" \
        || error "ADIOS 补丁应用失败，请确认补丁与当前内核版本兼容"
    success "ADIOS 补丁应用完成"
fi

# ====================== 写入内核配置 ======================
step "写入内核配置 (gki_defconfig)"
cd "${BUILD_DIR}/kernel_workspace/kernel_platform"
DEFCONFIG="./common/arch/arm64/configs/gki_defconfig"

[[ -f "${DEFCONFIG}" ]] \
    || error "gki_defconfig 不存在: ${DEFCONFIG}，内核源码可能不完整"

append_cfg() { echo "$1" >> "${DEFCONFIG}"; }

info "启用 KSU 支持..."
append_cfg "CONFIG_KSU=y"

if [[ "${KPM}" == "On" ]]; then
    info "启用 KPM..."
    append_cfg "CONFIG_KPM=y"
fi

info "启用 SUSFS 功能..."
for cfg in \
    CONFIG_KSU_SUSFS \
    CONFIG_KSU_SUSFS_SUS_PATH \
    CONFIG_KSU_SUSFS_SUS_MOUNT \
    CONFIG_KSU_SUSFS_SUS_KSTAT \
    CONFIG_KSU_SUSFS_SPOOF_UNAME \
    CONFIG_KSU_SUSFS_ENABLE_LOG \
    CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS \
    CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG \
    CONFIG_KSU_SUSFS_OPEN_REDIRECT \
    CONFIG_KSU_SUSFS_SUS_MAP; do
    append_cfg "${cfg}=y"
done

info "添加 Mountify 支持..."
append_cfg "CONFIG_TMPFS_XATTR=y"
append_cfg "CONFIG_TMPFS_POSIX_ACL=y"

if [[ "${PROXY}" == "On" ]]; then
    info "加入代理优化 CONFIG..."
    for cfg in \
        CONFIG_BPF_STREAM_PARSER \
        CONFIG_NETFILTER_XT_MATCH_ADDRTYPE \
        CONFIG_NETFILTER_XT_SET \
        CONFIG_IP_SET \
        CONFIG_IP_SET_BITMAP_IP \
        CONFIG_IP_SET_BITMAP_IPMAC \
        CONFIG_IP_SET_BITMAP_PORT \
        CONFIG_IP_SET_HASH_IP \
        CONFIG_IP_SET_HASH_IPMARK \
        CONFIG_IP_SET_HASH_IPPORT \
        CONFIG_IP_SET_HASH_IPPORTIP \
        CONFIG_IP_SET_HASH_IPPORTNET \
        CONFIG_IP_SET_HASH_IPMAC \
        CONFIG_IP_SET_HASH_MAC \
        CONFIG_IP_SET_HASH_NETPORTNET \
        CONFIG_IP_SET_HASH_NET \
        CONFIG_IP_SET_HASH_NETNET \
        CONFIG_IP_SET_HASH_NETPORT \
        CONFIG_IP_SET_HASH_NETIFACE \
        CONFIG_IP_SET_LIST_SET \
        CONFIG_IP6_NF_NAT \
        CONFIG_IP6_NF_TARGET_MASQUERADE; do
        append_cfg "${cfg}=y"
    done
    # 数值型配置单独处理
    append_cfg "CONFIG_IP_SET_MAX=65534"
fi

if [[ "${APPLY_ADIOS}" == "On" ]]; then
    info "启用 ADIOS 调度器..."
    append_cfg "CONFIG_MQ_IOSCHED_ADIOS=y"
    append_cfg "CONFIG_MQ_IOSCHED_DEFAULT_ADIOS=y"
fi

# 绕过 defconfig 严格检查
[[ -f "./common/build.config.gki" ]] \
    && sed -i 's/check_defconfig//' ./common/build.config.gki || true
[[ -f "./build/kernel/_setup_env.sh" ]] \
    && sed -i 's|echo ERROR: savedefconfig does not match "${source_config}" >&2|return 0|' \
        ./build/kernel/_setup_env.sh || true

success "内核配置更新完成"

# ====================== 开始编译 ======================
step "开始内核编译 (Bazel)"
cd "${BUILD_DIR}/kernel_workspace/kernel_platform"
BUILD_START=$(date +%s)

tools/bazel run //common:kernel_aarch64_dist

BUILD_END=$(date +%s)
BUILD_TIME=$(( BUILD_END - BUILD_START ))
success "内核编译完成，耗时 $((BUILD_TIME/60)) 分 $((BUILD_TIME%60)) 秒"

# ====================== 验证编译产物 ======================
step "验证编译产物"
DIST_DIR="${BUILD_DIR}/kernel_workspace/kernel_platform/out/kernel_aarch64/dist"
[[ -d "${DIST_DIR}" ]] \
    || error "编译产物目录不存在: ${DIST_DIR}，Bazel 构建可能未正常产出"
[[ -f "${DIST_DIR}/Image" ]] \
    || error "Image 文件不存在于: ${DIST_DIR}，内核编译可能失败"
success "编译产物验证通过：$(ls -lh "${DIST_DIR}/Image")"

# ====================== KPM 镜像修补（可选） ======================
if [[ "${KPM}" == "On" ]]; then
    step "KPM 修补内核镜像"
    cd "${DIST_DIR}"
    info "下载 patch_linux 工具..."
    retry 3 10 curl -LO \
        https://github.com/SukiSU-Ultra/SukiSU_KernelPatch_patch/releases/download/0.12.2/patch_linux
    chmod +x patch_linux

    info "运行 KPM 补丁..."
    ./patch_linux

    [[ -f oImage ]] \
        || error "patch_linux 未生成 oImage，KPM 修补可能失败"
    rm -f Image
    mv oImage Image
    success "KPM 补丁应用完成"
fi

# ====================== 打包 AnyKernel3 ======================
step "打包 AnyKernel3"

if [[ "${SU_TYPE}" == "ReSukiSU" ]]; then
    SUFFIX="ReSukiSU"
else
    SUFFIX="SukiSU_Ultra"
fi
ARTIFACT_NAME="${FEIL}_${SUFFIX}_${KERNEL_MANIFEST}"

cd "${BUILD_DIR}"
IMAGE_PATH=$(find "kernel_workspace/kernel_platform/out/kernel_aarch64/dist" \
    -maxdepth 1 -name "Image" | head -n 1)

[[ -n "${IMAGE_PATH}" && -f "${IMAGE_PATH}" ]] \
    || error "无法找到 Image 文件，打包中止"

info "Image 文件: ${IMAGE_PATH}"
cp "${IMAGE_PATH}" ./AnyKernel3/Image

[[ -d AnyKernel3 ]] || error "AnyKernel3 目录不存在，无法打包"

cd AnyKernel3
zip -r9 "../${ARTIFACT_NAME}.zip" ./*
cd ..

[[ -f "${ARTIFACT_NAME}.zip" ]] \
    || error "zip 打包失败，产物不存在: ${ARTIFACT_NAME}.zip"

success "打包完成: ${BUILD_DIR}/${ARTIFACT_NAME}.zip"

# ====================== 全部完成 ======================
step "构建成功"
echo ""
echo -e "  ${GREEN}产物路径 :${NC} ${BUILD_DIR}/${ARTIFACT_NAME}.zip"
echo -e "  ${GREEN}文件大小 :${NC} $(du -sh "${BUILD_DIR}/${ARTIFACT_NAME}.zip" | cut -f1)"
echo -e "  ${GREEN}编译耗时 :${NC} $((BUILD_TIME/60)) 分 $((BUILD_TIME%60)) 秒"
echo -e "  ${GREEN}日志文件 :${NC} ${LOG_FILE}"
echo ""
