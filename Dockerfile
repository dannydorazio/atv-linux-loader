#
# PURPOSE: Linux build environment for the Apple TV loader, usable from macOS or Linux via docker-make.sh
# SPDX-License-Identifier: GPL-2.0-only
#

FROM debian:bookworm

# clang + cctools-port build deps, plus tools for fetching boot files and building USB images
RUN apt-get update && apt-get install -y --no-install-recommends \
      clang llvm autoconf automake libtool make git xxd ca-certificates wget \
      p7zip-full parted dosfstools mtools uuid-dev \
 && rm -rf /var/lib/apt/lists/*

# Apple's linker; current Xcode refuses to link i386
RUN git clone --depth 1 -b 986-ld64-711 https://github.com/tpoechtrager/cctools-port.git /tmp/cctools \
 && cd /tmp/cctools/cctools \
 && ./configure --prefix=/opt/cross --target=i386-apple-darwin8 \
 && make -j$(nproc) && make install && rm -rf /tmp/cctools

# parted calls udevadm after writing; there's no udev in the container and images don't need it
RUN ln -s /bin/true /usr/local/bin/udevadm

WORKDIR /src
