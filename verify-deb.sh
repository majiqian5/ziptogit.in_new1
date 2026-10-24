#!/usr/bin/env bash
# 检查打出来的 .deb 是否结构正常(不装设备也能验个八九成)
# 用法: bash verify-deb.sh [dist/xxx.deb]

set -uo pipefail
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SRC_DIR"

if [ "$#" -ge 1 ]; then
    DEBS=("$1")
else
    shopt -s nullglob
    DEBS=(dist/*.deb packages/*.deb)
fi
[ "${#DEBS[@]}" -gt 0 ] || { echo "没找到 .deb,先跑 bash build-deb.sh"; exit 1; }
command -v dpkg-deb >/dev/null 2>&1 || { echo "缺 dpkg-deb(apt install dpkg-dev)"; exit 1; }

fails=0
for deb in "${DEBS[@]}"; do
    echo "=============================================="
    echo "检查: $deb  ($(du -h "$deb" | cut -f1))"
    echo "=============================================="
    dpkg-deb -I "$deb"

    fields="$(dpkg-deb -f "$deb")"
    arch="$(printf '%s\n' "$fields" | sed -n 's/^Architecture: *//p')"
    pkg="$(printf '%s\n' "$fields" | sed -n 's/^Package: *//p')"
    echo "--- 包名: $pkg   架构: $arch"
    case "$arch" in
        iphoneos-arm|iphoneos-arm64|iphoneos-arm64e) echo "  [OK] 架构字段正常" ;;
        *) echo "  [注意] 架构字段是 $arch,老设备装得上、新设备可能被 Sileo 拦" ; fails=$((fails+1)) ;;
    esac

    list="$(dpkg-deb -c "$deb" | awk '{print $6}')"

    echo "--- 关键文件"
    check_file() {
        if printf '%s\n' "$list" | grep -qx "$1"; then
            echo "  [OK]   $1"
        else
            echo "  [缺失] $1"
            fails=$((fails+1))
        fi
    }
    check_any() {  # 两种路径任一存在即可(有根 / 无根)
        if printf '%s\n' "$list" | grep -qx "$1" || printf '%s\n' "$list" | grep -qx "$2"; then
            echo "  [OK]   $1  (或 $2)"
        else
            echo "  [缺失] $1 / $2"
            fails=$((fails+1))
        fi
    }

    check_any "/Library/MobileSubstrate/DynamicLibraries/AxsPlayerPulse.dylib" \
              "/var/jb/Library/MobileSubstrate/DynamicLibraries/AxsPlayerPulse.dylib"
    check_any "/Library/MobileSubstrate/DynamicLibraries/AxsPlayerPulse.plist" \
              "/var/jb/Library/MobileSubstrate/DynamicLibraries/AxsPlayerPulse.plist"
    check_any "/Library/PreferenceLoader/Preferences/AxsPlayerPulsePrefs.plist" \
              "/var/jb/Library/PreferenceLoader/Preferences/AxsPlayerPulsePrefs.plist"
    check_any "/Library/PreferenceBundles/AxsPlayerPulsePrefs.bundle" \
              "/var/jb/Library/PreferenceBundles/AxsPlayerPulsePrefs.bundle"

    echo "--- 包内文件清单"
    printf '%s\n' "$list" | sed 's/^/    /'
    echo
done

echo "=============================================="
if [ "$fails" -eq 0 ]; then
    echo "结论: 结构检查通过,可以拷到设备上用 Sileo/Zebra/Filza 安装。"
else
    echo "结论: 有 $fails 处需要留意(见上面 [缺失]/[注意])。"
fi
echo "提醒: 无根(rootless)设备只能装 /var/jb 前缀的包;有根设备只能装 /Library 前缀的包。"
