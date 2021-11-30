#! /bin/bash
# Copyright (C) 2020 KenHV
# Copyright (C) 2020 Starlight
# Copyright (C) 2021 CloudedQuartz
#

# Config
DEVICE="sweet"
DEFCONFIG="vendor/sweet_user_defconfig"
LOG="$HOME/log.txt"

# Export arch and subarch
ARCH="arm64"
SUBARCH="arm64"
export ARCH SUBARCH

KERNEL_IMG=$KERNEL_DIR/out/arch/$ARCH/boot/Image.gz
KERNEL_DTBO=$KERNEL_DIR/out/arch/$ARCH/boot/dtbo.img

# End config

# Function definitions

# build_setup - enter kernel directory and get info for caption.
# also removes the previous kernel image, if one exists.
build_setup() {
    cd "$KERNEL_DIR" || echo -e "\nKernel directory ($KERNEL_DIR) does not exist" || exit 1

    [[ ! -d out ]] && mkdir out
    [[ -f "$KERNEL_IMG" ]] && rm "$KERNEL_IMG"
	find out/ -name "*.dtb*" -type f -delete
}

# build_config - builds .config file for device.
build_config() {
	make O=out $1 -j$(nproc --all)
}
# build_kernel - builds defconfig and kernel image using llvm tools, while saving the output to a specified log location
# only use after runing build_setup()
build_kernel() {

    BUILD_START=$(date +"%s")
    make -j$(nproc --all) O=out \
                PATH="$TC_DIR/bin:$PATH" \
                CC="clang" \
                CROSS_COMPILE=$TC_DIR/bin/aarch64-linux-gnu- \
                CROSS_COMPILE_ARM32=$TC_DIR/bin/arm-linux-gnueabi- \
                LLVM=llvm- \
                AR=llvm-ar \
                NM=llvm-nm \
                OBJCOPY=llvm-objcopy \
                OBJDUMP=llvm-objdump \
                STRIP=llvm-strip |& tee $LOG

    BUILD_END=$(date +"%s")
    DIFF=$((BUILD_END - BUILD_START))
}

# build_end - creates and sends zip
build_end() {

    echo -e "\n> Build successful! generating flashable zip..."
	cd "$AK_DIR" || echo -e "\nAnykernel directory ($AK_DIR) does not exist" || exit 1
	git clean -fd
	mv "$KERNEL_IMG" "$AK_DIR"/zImage
	mv "$KERNEL_DTBO" "$AK_DIR"
	curl https://android.googlesource.com/platform/external/avb/+/refs/heads/master/avbtool.py?format=TEXT | base64 --decode > avbtool.py
	python3 avbtool.py add_hash_footer --image dtbo.img --partition_size=33554432 --partition_name dtbo
	ZIP_NAME=$KERNELNAME-$1-$COMMIT_SHA-$(date +%Y-%m-%d_%H%M)-UTC
	zip -r9 "$ZIP_NAME".zip ./* -x .git README.md ./*placeholder avbtool.py

	# Sign zip if java is available
	if command -v java > /dev/null 2>&1; then
		curl -sLo zipsigner-4.0.jar https://github.com/baalajimaestro/AnyKernel3/raw/master/zipsigner-4.0.jar
		java -jar zipsigner-4.0.jar "$ZIP_NAME".zip "$ZIP_NAME"-signed.zip
		ZIP_NAME="$ZIP_NAME-signed.zip"
	fi

	curl --upload-file ./"$ZIP_NAME" https://transfer.sh/"$ZIP_NAME"
}

# End function definitions

# Build device 1
build_setup
build_config $DEFCONFIG
build_kernel
build_end $DEVICE

# Use stock panel dimentions for miui vendor based roms
cd $KERNEL_DIR
git am patches/0001-Revert-ARM64-dts-sweet-Decrease-physical-panel-dimen.patch

# Build device 1 for MIUI
build_setup
build_config $DEFCONFIG
build_kernel
build_end ${DEVICE}_MIUI
