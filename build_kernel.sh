#!/bin/bash

export PATH=$(pwd)/prebuilts/clang/host/linux-x86/clang-r416183b/bin:$PATH
export PATH=$(pwd)/prebuilts/build-tools/linux-x86/bin:$PATH
export CROSS_COMPILE=$(pwd)/prebuilts/clang/host/linux-x86/clang-r416183b/bin/aarch64-linux-gnu-
export CC=$(pwd)/prebuilts/clang/host/linux-x86/clang-r416183b/bin/clang
export CLANG_TRIPLE=aarch64-linux-gnu-
export ARCH=arm64
export PLATFORM_VERSION=12

export KCFLAGS=-w
export CONFIG_SECTION_MISMATCH_WARN_ONLY=y

make -C $(pwd) O=$(pwd)/out KCFLAGS=-w CONFIG_SECTION_MISMATCH_WARN_ONLY=y LLVM=1 LLVM_IAS=1 a15_defconfig
make -C $(pwd) O=$(pwd)/out KCFLAGS=-w CONFIG_SECTION_MISMATCH_WARN_ONLY=y LLVM=1 LLVM_IAS=1 -j16

cp out/arch/arm64/boot/Image $(pwd)/arch/arm64/boot/Image