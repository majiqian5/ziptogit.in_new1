# 可复现的 Theos 构建环境(不需要 macOS)
# 构建: docker build -t playerpulse-theos .
# 使用: bash docker-build.sh          (在源码目录里跑,产物落在 ./dist)
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential git curl make perl clang ldid dpkg-dev fakeroot \
      xz-utils libssl-dev libplist-dev libc6-dev unzip ca-certificates \
 && rm -rf /var/lib/apt/lists/*

ENV THEOS=/opt/theos
RUN git clone --recursive --depth 1 https://github.com/roothide/theos.git "$THEOS"

RUN mkdir -p "$THEOS/sdks" \
 && cd /tmp \
 && git clone --depth 1 --filter=blob:none --sparse https://github.com/theos/sdks.git sdks \
 && git -C /tmp/sdks sparse-checkout set iPhoneOS16.5.sdk \
 && cp -R /tmp/sdks/iPhoneOS16.5.sdk "$THEOS/sdks/" \
 && rm -rf /tmp/sdks

ENV PATH=$THEOS/bin:$PATH
ENV THEOS_IGNORE_PARALLEL_BUILDING_NOTICE=yes

WORKDIR /src
CMD ["bash", "-lc", "sh build.sh rootless"]
