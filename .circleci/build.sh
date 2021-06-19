#!/bin/bash
echo "Cloning dependencies"
git clone --depth=1 -b light11 https://github.com/prorooter007/Android_Kernel_Xiaomi_Sweet_ kernel
cd kernel
git clone --depth=1 -b master https://github.com/kdrag0n/proton-clang clang
git clone --depth=1 https://github.com/prorooter007/AnyKernel3 -b sweet AnyKernel
echo "Done"
TANGGAL=$(date +"%F-%S")
START=$(date +"%s")
KERNEL_DIR=$(pwd)
REPACK_DIR="${KERNEL_DIR}/AnyKernel"
IMAGE_DTB="${KERNEL_DIR}/out/arch/arm64/boot/Image.gz-dtb"
export CONFIG_PATH="${KERNEL_DIR}/arch/arm64/configs/lightning-sweet_defconfig"
PATH="${PWD}/clang/bin:$PATH"
export ARCH=arm64
export KBUILD_BUILD_HOST=circleci
export KBUILD_BUILD_USER="prorooter007"
# Compile plox
function compile() {
 make lightning-sweet_defconfig O=out
    make -j$(nproc --all) O=out \
                      ARCH=arm64 \
                      CC=clang \
                      CROSS_COMPILE=aarch64-linux-gnu- \
                      CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
                      NM=llvm-nm \
                      OBJCOPY=llvm-objcopy \
                      OBJDUMP=llvm-objdump \
                      STRIP=llvm-strip

    cd $REPACK_DIR

    if ! [ -a "$IMAGE" ]; then
        exit 1
        echo "There are some issues"
    fi
    cp $IMAGE_DTB $REPACK_DIR
}
# Zipping
function zipping() {
    cd $REPACK_DIR || exit 1
    zip -r9 Lightning-V1-${TANGGAL}.zip *
    curl --upload-file ./Lightning-V1-${TANGGAL}.zip https://transfer.sh/Lightning-V1-${TANGGAL}.zip
    cd ..
}
compile
zipping
