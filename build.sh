#!/bin/bash

set -e

if [ ! x"${DEBUG_BUILD}" = x"" ]
then
    set -x
fi

export PATH=$PATH:${ANDROID_TOOLCHAIN}

# Command line arguments
command="${1}"
opt_arg="${2}"
startdir="$(pwd)"

# Default Make Arguments
ARCH=${ARCH:-"arm"}
DEVICE=${DEVICE:-"galaxys4gmtd"}
DEFCONFIG=${DEFCONFIG:-"cyanogen_${DEVICE}_defconfig"}
SRC=${SRC:-"${ANDROID_BUILD_TOP}/kernel/${DEVICE}"}
JOBS=${JOBS:-"$(grep ^process /proc/cpuinfo | wc -l)"}
CROSSCC=${CROSSCC:-"arm-eabi-"}
HOSTCC=${HOSTCC:-"$(which gcc)"}
HOSTCXX=${HOSTCXX:-"$(which g++)"}
EXTRA_CONFIG=${EXTRA_CONFIG:-""}
DEFAULT_ARGS=${DEFAULT_ARGS:-"-j${JOBS} ARCH=${ARCH} \
    CROSS_COMPILE=${CROSSCC} HOSTCC=${HOSTCC} HOSTCXX=${HOSTCXX} \
    ${EXTRA_CONFIG}"}

# MISC Options

# Utility Functions
error()
{
    abort_msg "============== Error!!! ==============\n${@}"
    exit 1
}

abort_msg()
{
    printf "${@}\n"
    exit 1
}

abort()
{
    exit 1
}

prep()
{
    printf "============== Prep ====================\n"
    cd ${SRC}

    if [ ! x"${command}" = x"build" ]
    then
        make distclean || error "Could not make distclean in ${SRC}!"
    fi

    if [ ! x"${command}" = x"distclean" ]
    then
        make ${DEFAULT_ARGS} ${DEFCONFIG} || \
            error "Could not set default config!"
    fi
}

build()
{
    prep
    printf "============== Build ===================\n"
    cd ${SRC}
    if [ -f ${SRC}/../build.log ]
    then
	rm ${SRC}/../build.log
    fi
    make ${DEFAULT_ARGS} 2>&1 | tee ${SRC}/../build.log || error "Build Failed!"
    make ${DEFAULT_ARGS} modules 2>&1 | tee -a ${SRC}/../build.log || error "Build Modules Failed!"
    if [ -f arch/${ARCH}/boot/zImage ]
    then
        printf "Copying zImage to: device/samsung/${DEVICE}/kernel\n"
        rm -f ${ANDROID_BUILD_TOP}/device/samsung/${DEVICE}/kernel
        cp -f arch/${ARCH}/boot/zImage \
            ${ANDROID_BUILD_TOP}/device/samsung/${DEVICE}/kernel
    else
        error "Could not find zImage!"
    fi
    modules=$(find ${SRC} -name '*.ko' -type f)
    if [ ! x"${modules}" = x"" ]
    then
        printf "Copying: kernel modules to device/samsung/${DEVICE}/modules/\n"
        rm -rf ${ANDROID_BUILD_TOP}/device/samsung/${DEVICE}/modules/*.ko
        cp -f ${modules} ${ANDROID_BUILD_TOP}/device/samsung/${DEVICE}/modules/
    else
        error "Couldn't find any kernel modules to copy!"
    fi
    finalize
}

config()
{
    prep
    printf "============== Config ==================\n"
    cd ${SRC}
    make ${DEFAULT_ARGS} menuconfig || error "Menuconfig failed!"
    if [ -r .config ]
    then
        cp .config ${SRC}/arch/${ARCH}/configs/${DEFCONFIG} || \
            error "Could not copy .config to arch/${ARCH}/configs" \
            "/${DEFCONFIG}"
    fi
    finalize
}

distclean()
{
    prep
    printf "============== DistClean ===============\n"
    cd ${SRC}
    make ${DEFAULT_ARGS} distclean || error "distclean failed!"
    printf "Distclean was successful!\n"
    finalize
}

repack()
{
    prep
    printf "============== Repack ==================\n"
    printf "Nothing for now... implement me $(id -un)\n"
    finalize
}

usage()
{
    printf "============== Usage ===================\n"
    printf "Commands:\n"
    printf "\tbuild\t\tbuild the kernel\n"
    printf "\tconfig\t\trun menuconfig and copy it over the defconfig\n"
    printf "\trepack\t\trepack the initramfs if the kernel exists\n"
    printf "\tdistclean\tclean up the kernel.\n"
    printf "\tusage\t\tThis help\n"
    printf "You can override the following environment variables\n"
    printf "by using export.\n"
    printf "ARCH\t\tSets the architecture to build for. (Default: arm)\n"
    printf "DEFCONFIG\tSets the defconfig to use.\n"
    printf "\t\t(Default: aries_galaxys4g_defconfig)\n"
    printf "SRC\t\tSets the kernel source directory.\n"
    printf "\t\t(Default: ${ANDROID_BUILD_TOP}/kernel/galaxys4gmtd)\n"
    printf "JOBS\t\tSets the number of jobs to build with.\n"
    printf "\t\t(Default: $(grep ^process /proc/cpuinfo | wc -l))\n"
    printf "CROSSCC\t\tCross-Compiler to use.\n"
    printf "\t\t(Default: ${ANDROID_TOOLCHAIN}/arm-eabi-)\n"
    printf "HOSTCC\t\tHost cc to use.\n"
    printf "\t\t(Default: $(which gcc))\n"
    printf "HOSTCXX\t\tHost cxx to use.\n"
    printf "\t\t(Default: $(which g++))\n"
    printf "EXTRA_CONFIG\tCan be used to add other arguments\n"
    printf "to the kernel make command line. This is not set by default.\n"
    printf "DEFAULT_ARGS\tDefault arguments provided by the above:\n"
    printf "\t\t-j${JOBS} ARCH=${ARCH} \
    CROSS_COMPILE=${CROSSCC} HOSTCC=${HOSTCC} HOSTCXX=${HOSTCXX} \
    ${EXTRA_CONFIG}\n\n"
    abort
}

missing_arg()
{
    printf "============== Missing Argument ========\n"
    printf "Nothing for now... implement me $(id -un)\n"
}

finalize()
{
    printf "============== Finalize ================\n"
    if [ ! x"$(git status -z)" = x"" ]
    then
        :
    #    printf "============== Dirty Build =============\n"
    #    printf "The build has outstanding changes.\nFollowing are the outstanding changes.\n"
    #    git status
    #    git diff
    fi
}

main()
{
    printf "============== Main ====================\n"

    case $command in
        build)
            build
            ;;
        config)
            config
            ;;
        distclean)
            distclean
            ;;
        repack)
            repack
            ;;
        *)
            usage
            ;;
    esac
}

# Deal with silly users
if [ x"${ANDROID_BUILD_TOP}" = x"" ]
then
    error "You have not ran:\n\nsource ./build/envsetup.sh\nlunch cyanogen_galaxys4gmtd-eng"
fi
if [ x"${command}" = x"" ]
then
    printf "============== Error!!! ==============\nYou must supply a command!\n"
    usage
fi

# DO IT!!!
main

# vi: ts=4:sw=4:et:ai
