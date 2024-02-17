#!/bin/bash

[ "$KDIR" = "" ] && { echo "Variable KDIR is not set"; exit 1; }

set -x
set -e

scriptdir=$(dirname $(realpath -s $0))
build="$(realpath $scriptdir/../build)"
rootfs="$build/alpine-minirootfs"

# get kernel version
make -j12 -C "$KDIR" include/config/kernel.release
VERSION=$(cat "$KDIR/include/config/kernel.release")

# target files
built_kernel="$build/bzImage-$VERSION"
built_rootfs="$build/minirootfs-$VERSION.img.lz4"

rm -rf "$build"
mkdir -p $build

# get minimal rootfs
minirootfs_zipped="alpine-minirootfs-3.19.1-x86_64.tar.gz"
wget -nc --directory-prefix=$build "https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/x86_64/$minirootfs_zipped"
mkdir -p $rootfs
tar xf $build/$minirootfs_zipped -C $rootfs

# copy /etc/resolv.conf to enable name resolution
cp /etc/resolv.conf $rootfs/etc

# install linux incl. kernel modules and kselftests
cp "$KDIR/arch/x86/boot/bzImage" "$built_kernel"
make -j12 -C "$KDIR" INSTALL_MOD_PATH="$rootfs" modules_install
make -j12 -C "$KDIR/tools/testing/selftests/tpm2" INSTALL_PATH="$rootfs/home" install

# install additional packages python via chroot
pkgs="python3"
unshare -r chroot $rootfs /bin/sh -c "apk add --no-cache --initramfs-diskless-boot  $pkgs"

# add init
cp $scriptdir/../src/init $rootfs/init
chmod +x $rootfs/init

# turn rootfs into cpio
pushd $rootfs
find . -print0 |
    cpio --null --create --verbose --owner root:root --format=newc |
    lz4c -l > $built_rootfs
popd
