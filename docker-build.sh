#!/usr/bin/env bash
# 用 Docker 在任意机器上出 deb(结果和 macOS + Theos 一致)
# 用法: bash docker-build.sh [rootless|rootful|roothide|all]
set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SRC_DIR"

command -v docker >/dev/null 2>&1 || { echo "没装 docker。装了再来,或者直接用 build-deb.sh"; exit 1; }

SCHEME="${1:-rootless}"

echo ">>> 构建镜像 playerpulse-theos (第一次会拉几百 MB,耐心等)"
docker build -t playerpulse-theos .

echo ">>> 容器内编译: $SCHEME"
docker run --rm -v "$SRC_DIR":/src -w /src playerpulse-theos \
    bash -lc "sh build.sh $SCHEME && mkdir -p dist && cp -f packages/*.deb dist/ 2>/dev/null || true"

echo ">>> 产物:"
ls -lh "$SRC_DIR"/packages/*.deb 2>/dev/null || { echo "没产物,把上面容器里的报错贴给我"; exit 1; }
