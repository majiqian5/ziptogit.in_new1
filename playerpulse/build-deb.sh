#!/usr/bin/env bash
# PlayerPulse / 律动播放器 —— 一键出 .deb (Theos)
#
# 用法(在本目录下执行):
#   bash build-deb.sh              # 默认打 rootless(越狱主流:Dopamine / palera1n rootless)
#   bash build-deb.sh rootful      # 有根越狱(老 unc0ver / checkra1n)
#   bash build-deb.sh roothide     # RootHide 环境
#   bash build-deb.sh all          # 三套全打
#
# 产物: ./packages/*.deb,并复制一份到 ./dist/
#
# 环境要求: Linux(Debian/Ubuntu) 或 macOS; 首次运行会自动装依赖、拉 Theos 和 iPhoneOS 16.5 SDK。
# 需要联网(拉 Theos / SDK / 装包)。

set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SRC_DIR"

log() { printf '\033[1;36m>>> %s\033[0m\n' "$*"; }
die() { printf '\033[1;31m[错误] %s\033[0m\n' "$*" >&2; exit 1; }

# ---------- 0. 参数 ----------
if [ "$#" -eq 0 ]; then
    set -- rootless
fi
if [ "$#" -eq 1 ] && [ "$1" = "all" ]; then
    set -- rootful rootless roothide
fi
for scheme in "$@"; do
    case "$scheme" in
        rootful|rootless|roothide) ;;
        *) die "未知方案: $scheme (只能是 rootful / rootless / roothide / all)" ;;
    esac
done

# ---------- 1. 依赖 ----------
install_deps_linux() {
    local SUDO=""
    if [ "$(id -u)" -ne 0 ]; then
        command -v sudo >/dev/null 2>&1 && SUDO="sudo"
    fi
    local pkgs="build-essential git curl make perl clang ldid dpkg-dev fakeroot xz-utils libssl-dev libplist-dev libc6-dev unzip ca-certificates"
    if command -v apt-get >/dev/null 2>&1; then
        log "安装编译依赖 (apt)"
        $SUDO apt-get update -qq
        $SUDO apt-get install -y -qq $pkgs
    elif command -v dnf >/dev/null 2>&1; then
        log "安装编译依赖 (dnf)"
        $SUDO dnf install -y gcc gcc-c++ git curl make perl clang ldid dpkg-devel fakeroot xz openssl-devel libplist-devel unzip
    elif command -v pacman >/dev/null 2>&1; then
        log "安装编译依赖 (pacman)"
        $SUDO pacman -Sy --noconfirm --needed base-devel git curl make perl clang ldid dpkg fakeroot xz openssl libplist unzip
    else
        die "没认出来的发行版,请手动装: clang ldid dpkg-dev fakeroot xz-utils libssl-dev libplist-dev git make perl"
    fi
}

install_deps_macos() {
    command -v brew >/dev/null 2>&1 || die "没装 Homebrew,先装: https://brew.sh"
    command -v xcodebuild >/dev/null 2>&1 || die "缺 Xcode 命令行工具,先执行: xcode-select --install"
    log "安装编译依赖 (brew)"
    brew install ldid dpkg xz make 2>/dev/null || true
    command -v ldid >/dev/null 2>&1 || die "ldid 安装失败"
}

need=0
command -v git   >/dev/null 2>&1 || need=1
command -v make  >/dev/null 2>&1 || need=1
command -v clang >/dev/null 2>&1 || need=1
command -v ldid  >/dev/null 2>&1 || need=1
command -v dpkg-deb >/dev/null 2>&1 || need=1

if [ "$need" -eq 1 ]; then
    case "$(uname -s)" in
        Darwin) install_deps_macos ;;
        Linux)  install_deps_linux ;;
        *) die "不支持的系统: $(uname -s) (需要 macOS 或 Linux)" ;;
    esac
fi

# ---------- 2. Theos ----------
# 注意: roothide 方案必须用 roothide/theos 这个 fork,上游 theos 不认 roothide。
if [ -n "${THEOS:-}" ]; then
    log "使用已有的 THEOS=$THEOS"
else
    THEOS="$SRC_DIR/.theos"
    if [ ! -d "$THEOS/makefiles" ]; then
        log "拉取 Theos 工具链 (roothide/theos)"
        rm -rf "$THEOS"
        git clone --recursive --depth 1 https://github.com/roothide/theos.git "$THEOS"
    fi
    export THEOS
fi
[ -d "$THEOS/makefiles" ] || die "Theos 目录不完整: $THEOS"
export PATH="$THEOS/bin:$PATH"
export THEOS_IGNORE_PARALLEL_BUILDING_NOTICE=yes

# ---------- 3. iOS SDK ----------
SDK_NAME="iPhoneOS16.5.sdk"
if [ -d "$THEOS/sdks/$SDK_NAME" ]; then
    log "SDK 已存在: $SDK_NAME"
else
    log "下载 $SDK_NAME"
    mkdir -p "$THEOS/sdks"
    STAGE="$(mktemp -d)"
    trap 'rm -rf "$STAGE"' EXIT
    git clone --depth 1 --filter=blob:none --sparse https://github.com/theos/sdks.git "$STAGE/sdks"
    git -C "$STAGE/sdks" sparse-checkout set "$SDK_NAME"
    cp -R "$STAGE/sdks/$SDK_NAME" "$THEOS/sdks/"
    rm -rf "$STAGE"
    trap - EXIT
fi

# ---------- 4. 编译打包 ----------
mkdir -p "$SRC_DIR/dist"
# 如果 clang 不支持 arm64e,可以用 ARCHS_OVERRIDE=arm64 跑
ARCH_ARG=""
[ -n "${ARCHS_OVERRIDE:-}" ] && ARCH_ARG="ARCHS=$ARCHS_OVERRIDE"
for scheme in "$@"; do
    pkg_scheme="$scheme"
    [ "$scheme" = "rootful" ] && pkg_scheme=""
    log "编译打包: $scheme"
    # shellcheck disable=SC2086
    make clean     THEOS_PACKAGE_SCHEME="$pkg_scheme" $ARCH_ARG >/dev/null
    # shellcheck disable=SC2086
    make package   THEOS_PACKAGE_SCHEME="$pkg_scheme" $ARCH_ARG FINALPACKAGE=1 DEBUG=0
    echo
done

log "收集产物"
found=0
for f in "$SRC_DIR"/packages/*.deb; do
    [ -f "$f" ] || continue
    cp -f "$f" "$SRC_DIR/dist/"
    found=1
done
[ "$found" -eq 1 ] || die "没找到 .deb,上面 make 是不是报错了?"

echo
log "完成,产物:"
ls -lh "$SRC_DIR/dist/"*.deb
echo
echo "建议接着跑:  bash verify-deb.sh      # 检查包结构/架构/路径是否对"
