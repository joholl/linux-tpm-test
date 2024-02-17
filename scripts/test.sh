#!/bin/bash

set -x
set -e

kernel="build/bzImage-*"
if [ $(echo $kernel | wc -w) -ne 1 ]; then
    echo "Found multiple kernel files: $kernel"
    exit 1
fi

rootfs="build/minirootfs-*"
if [ $(echo $rootfs | wc -w) -ne 1 ]; then
    echo "Found multiple rootfs files: $rootfs"
    exit 1
fi


##### start simulator #####
swtpm_pidfile=$(mktemp)
swtpm_socket=$(mktemp)
swtpm_logfile=$(mktemp)

cleanup() {
    local exit_status=$?
    kill $(cat $swtpm_pidfile)
    exit $exit_status
}

trap cleanup TERM
trap cleanup ERR

swtpm="${swtpm:-$(which swtpm)}"
$swtpm socket --tpmstate dir=$(mktemp -d) --ctrl type=unixio,path=$swtpm_socket --log level=20,file=$swtpm_logfile --tpm2 &
echo $! > $swtpm_pidfile


##### boot into kernel #####
# -no-reboot and panic=-1 make linux try to reboot - and therefore quit out of qemu on panic
qemu-system-x86_64 \
    -kernel $kernel \
    -initrd $rootfs \
    -m size=512 \
    -nographic \
    -append "console=ttyS0 panic=-1" \
    -no-reboot \
    -nic user \
    -chardev socket,id=chrtpm,path=$swtpm_socket \
    -tpmdev emulator,id=tpm0,chardev=chrtpm -device tpm-tis,tpmdev=tpm0 &&\
echo "For swtpm log, see $swtpm_logfile"
