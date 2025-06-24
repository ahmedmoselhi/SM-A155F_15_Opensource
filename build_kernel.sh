#!/bin/bash

#get kerneldir ready

STARTPATH=$(pwd)
[ ! -f ./certificate.pem ] && openssl req -new -x509 -newkey rsa:4096 -keyout private_key.pk8 -out certificate.pem -days 824 -nodes -sha256 -config samsung_cert.conf
[ -d ./ksu_patched ] && rm -rf ./ksu_patched/
mkdir ./ksu_patched
cd ksu_patched
../github.com-topjohnwu/x86_64/magiskboot unpack ../samsungbootimg/boot.img
rm kernel

#do ksun
cd ..
find . -type f ! -perm -u=w -exec chmod u+w {} +
curl -LSs "https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/next/kernel/setup.sh" | bash -s v1.0.8

#do susfs stuff
if [ ! -f "./syscall_hooks.patch" ]; then
        cp ./gitlab.com-simonpunk/kernel_patches/fs/* ./fs/
	cp ./gitlab.com-simonpunk/kernel_patches/include/linux/* ./include/linux/
	cp ./gitlab.com-simonpunk/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch ./KernelSU-Next/
	cp ./gitlab.com-simonpunk/kernel_patches/50_add_susfs_in_gki-android12-5.10.patch ./
	cp ./wildplus/next/syscall_hooks.patch ./
	cp ./wildplus/next/157susfs4ksun107.patch ./KernelSU-Next/kernel/
	#copy stupid fix for namespace c hunk 1 for different define infront insert and hunk 13 for different code after insert
	cp ./wildplus/next/hotfixsamsungnamespace.patch ./
	cd ./KernelSU-Next/
	patch -p1 --forward < 10_enable_susfs_for_ksu.patch
 	cd ./kernel/
  	sed -i '89s/ \t/ /' 157susfs4ksun107.patch
	patch -p1 --forward < 157susfs4ksun107.patch
	cd ../..
	patch -p1 < 50_add_susfs_in_gki-android12-5.10.patch
	#do stupid fix for namespace c
	patch -p1 < hotfixsamsungnamespace.patch
	patch -p1 -F 3 < syscall_hooks.patch
fi

#build kernel
CONFIG_FILE="./arch/arm64/configs/a15_defconfig"
CONFIGS=(
  "CONFIG_KSU=y"
  "CONFIG_KSU_KPROBES_HOOK=n"
  "CONFIG_KSU_SUSFS=y"
  "CONFIG_KSU_SUSFS_HAS_MAGIC_MOUNT=y"
  "CONFIG_KSU_SUSFS_SUS_PATH=y"
  "CONFIG_KSU_SUSFS_SUS_MOUNT=y"
  "CONFIG_KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT=y"
  "CONFIG_KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT=y"
  "CONFIG_KSU_SUSFS_SUS_KSTAT=y"
  "CONFIG_KSU_SUSFS_SUS_OVERLAYFS=n"
  "CONFIG_KSU_SUSFS_TRY_UMOUNT=y"
  "CONFIG_KSU_SUSFS_AUTO_ADD_TRY_UMOUNT_FOR_BIND_MOUNT=y"
  "CONFIG_KSU_SUSFS_SPOOF_UNAME=y"
  "CONFIG_KSU_SUSFS_ENABLE_LOG=y"
  "CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS=y"
  "CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y"
  "CONFIG_KSU_SUSFS_OPEN_REDIRECT=y"
  "CONFIG_KSU_SUSFS_SUS_SU=n"
  "CONFIG_TMPFS_XATTR=y"
  "CONFIG_TMPFS_POSIX_ACL=y"
  "CONFIG_IP_NF_TARGET_TTL=y"
  "CONFIG_IP6_NF_TARGET_HL=y"
  "CONFIG_IP6_NF_MATCH_HL=y"
)
for config in "${CONFIGS[@]}"; do
  key=$(echo "$config" | cut -d= -f1)
  if grep -q "^$key=" "$CONFIG_FILE"; then
    sed -i "s|^$key=.*|$config|" "$CONFIG_FILE"
  else
    echo "$config" >> "$CONFIG_FILE"
  fi
done
sed -i -E '/^CONFIG_(SECURITY_DEFEX|PROCA|FIVE|UH|RKP|KDP|KDP_CRED|KDP_NS|KDP_TEST|RKP_TEST)=y$/s/=y/=n/' ./arch/arm64/configs/a15_defconfig

#configure the Kernel metadata
sed -i '$s|echo "\$res"|echo "-android12-9-31117096"|' ./scripts/setlocalversion
perl -pi -e 's{UTS_VERSION="\$\(echo \$UTS_VERSION \$CONFIG_FLAGS \$TIMESTAMP \| cut -b -\$UTS_LEN\)"}{UTS_VERSION="#1 SMP PREEMPT Thu May 29 08:03:09 UTC 2025"}' ./scripts/mkcompile_h
sed -i 's/-dirty//' ./scripts/setlocalversion

#do kernelbuilding
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

cd $(pwd)/ksu_patched
cp ../out/arch/arm64/boot/Image ./
mv Image kernel

#make boot.img
../github.com-topjohnwu/x86_64/magiskboot repack ../samsungbootimg/boot.img boot.img
../github.com-topjohnwu/x86_64/magiskboot sign boot.img ../certificate.pem
