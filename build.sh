#!/bin/bash
#
# Copyright (C) 2020 azrim.
# All rights reserved.

# Init
KERNEL_DIR="${PWD}"
DTB_TYPE="single" # define as "single" if want use single file
KERN_IMG="${KERNEL_DIR}"/out/arch/arm64/boot/Image.gz-dtb             # if use single file define as Image.gz-dtb instead
KERN_DTB="${KERNEL_DIR}"/out/arch/arm64/boot/dtbo.img # and comment this variable
ANYKERNEL="${HOME}"/anykernel

# Repo URL
CLANG_REPO="https://github.com/silont-project/silont-clang"
ANYKERNEL_REPO="https://github.com/Busetdah/AnyKernel3.git"
ANYKERNEL_BRANCH="jayus"

# Compiler
COMP_TYPE="clang" # unset if want to use gcc as compiler
CLANG_DIR="$HOME/proton-clang"
if ! [ -d "${CLANG_DIR}" ]; then
    git clone "$CLANG_REPO" --depth=1 "$CLANG_DIR"
fi
GCC_DIR="" # Doesn't needed if use proton-clang
GCC32_DIR="" # Doesn't needed if use proton-clang

if [[ "${COMP_TYPE}" =~ "clang" ]]; then
    COMP_PATH="$CLANG_DIR/bin:${PATH}"
else
    COMP_PATH="${GCC_DIR}/bin:${GCC32_DIR}/bin:${PATH}"
fi

# Defconfig
DEFCONFIG="cust_defconfig"
REGENERATE_DEFCONFIG="true" # unset if don't want to regenerate defconfig

# Costumize
KERNEL="SiLonT"
DEVICE="Miatoll"
KERNELTYPE="Unified"
KERNELNAME="${KERNEL}-${DEVICE}-${KERNELTYPE}-$(date +%y%m%d-%H%M)"
TEMPZIPNAME="${KERNELNAME}-unsigned.zip"
ZIPNAME="${KERNELNAME}.zip"

# Telegram
CHATIDQ="-425671460"
CHATID="-1001276955142" # Group/channel chatid (use rose/userbot to get it)
TELEGRAM_TOKEN="" # Get from botfather

# Export Telegram.sh
TELEGRAM_FOLDER="${HOME}"/telegram
if ! [ -d "${TELEGRAM_FOLDER}" ]; then
    git clone https://github.com/fabianonline/telegram.sh/ "${TELEGRAM_FOLDER}"
fi

TELEGRAM="${TELEGRAM_FOLDER}"/telegram

tg_cast() {
    "${TELEGRAM}" -t "${TELEGRAM_TOKEN}" -c "${CHATID}" -H \
    "$(
		for POST in "${@}"; do
			echo "${POST}"
		done
    )"
}

# Regenerating Defconfig
regenerate() {
    cp out/.config arch/arm64/configs/"${DEFCONFIG}"
    git add arch/arm64/configs/"${DEFCONFIG}"
    git commit -m "defconfig: Regenerate"
}

# Building
makekernel() {
    export PATH="${COMP_PATH}"
    rm -rf "${KERNEL_DIR}"/out/arch/arm64/boot # clean previous compilation
    mkdir -p out
    make O=out ARCH=arm64 ${DEFCONFIG}
    if [[ "${REGENERATE_DEFCONFIG}" =~ "true" ]]; then
        regenerate
    fi
    if [[ "${COMP_TYPE}" =~ "clang" ]]; then
        make -j$(nproc --all) CC=clang CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- O=out ARCH=arm64
    else
	make -j$(nproc --all) O=out ARCH=arm64 CROSS_COMPILE="${GCC_DIR}/bin/aarch64-elf-" CROSS_COMPILE_ARM32="${GCC32_DIR}/bin/arm-eabi-"
    fi
    # Check If compilation is success
    if ! [ -f "${KERN_IMG}" ]; then
	    END=$(date +"%s")
	    DIFF=$(( END - START ))
	    echo -e "Kernel compilation failed, See buildlog to fix errors"
	    tg_cast "Build for ${DEVICE} <b>failed</b> in $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)! Check Instance for errors @ThisIsTag"
	    exit 1
    fi
}

# Packing kranul
packingkernel() {
    # Copy compiled kernel
    if [ -d "${ANYKERNEL}" ]; then
        rm -rf "${ANYKERNEL}"
    fi
    git clone "$ANYKERNEL_REPO" -b "$ANYKERNEL_BRANCH" "${ANYKERNEL}"
    if [[ "${DTB_TYPE}" =~ "single" ]]; then
        cp "${KERN_IMG}" "${ANYKERNEL}"/Image.gz-dtb
    else
        mkdir "${ANYKERNEL}"/kernel/
        cp "${KERN_IMG}" "${ANYKERNEL}"/kernel/Image.gz
        cp "${KERN_DTB}" "${ANYKERNEL}"/dtbo.img
    fi

    # Zip the kernel, or fail
    cd "${ANYKERNEL}" || exit
    zip -r9 "${TEMPZIPNAME}" ./*

    # Sign the zip before sending it to Telegram
    curl -sLo zipsigner-4.0.jar https://raw.githubusercontent.com/baalajimaestro/AnyKernel3/master/zipsigner-4.0.jar
    java -jar zipsigner-4.0.jar "${TEMPZIPNAME}" "${ZIPNAME}"

    # Ship it to the CI channel
    "${TELEGRAM}" -f "$ZIPNAME" -t "${TELEGRAM_TOKEN}" -c "${CHATIDQ}"
}

# Starting
tg_cast "<b>STARTING KERNEL BUILD</b>" \
  "Compiler: <code>${COMP_TYPE}</code>" \
	"Device: ${DEVICE}" \
	"Kernel: <code>${KERNEL}, ${KERNELTYPE}</code>" \
	"Linux Version: <code>$(make kernelversion)</code>"
START=$(date +"%s")
makekernel
packingkernel
END=$(date +"%s")
DIFF=$(( END - START ))
tg_cast "Build for ${DEVICE} with ${COMPILER_STRING} <b>succeed</b> took $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)! @ThisIsTag"
