# Testing the Linux Kernel TPM Subsystem

This repo runs the linux kernel kselftests of the TPM subsystem against qemu
with swtpm.

## Dependencies

For building the linux kernel (and the rootfs), install:

```sh
sudo apt update
sudo apt install -y bc bison build-essential flex git kmod libelf-dev libssl-dev lz4 python3-pip rsync wget
pip install yq
```

For convenience, we will install additionally:

```sh
sudo apt update
sudo apt-get install -y qemu-system-x86 swtpm
```

## Getting the Linux Kernel

We work with jarkko's linux fork since he is one of the TPM subsystem
maintainers.

We also need to set `KDIR`, to tell the scripts where the linux kernel is
located.

```sh
git clone https://git.kernel.org/pub/scm/linux/kernel/git/jarkko/linux-tpmdd.git
KDIR=$(realpath linux)
```

Alternatively, you can call `KDIR=... scripts/checkout.sh`. It will also apply patches according to [linux.toml](linux.toml).

## Building the kernel

### Configure

First, we need to config the kernel.

```bash
cd $KDIR
make -j$(nproc) -C $KDIR defconfig
scripts/config --module TCG_TPM
scripts/config --module TCG_TIS
scripts/config --module TCG_TIS_I2C
scripts/config --module TCG_TIS_CORE
scripts/config --module TCG_TIS_SPI
scripts/config --enable HW_RANDOM_TPM
scripts/config --disable TCG_TIS_I2C_CR50
scripts/config --disable TCG_TIS_I2C_ATMEL
# ...
```

Alternatively, you can call `KDIR=... scripts/config.sh`.

### Build TPM drivers

If you want, you can build the TPM drivers, now. The drivers above, for which
you selected `--module` will be compiled to kernel modules (`.ko` files).

If we compile the modules for the first time, we need to make `modules_prepare`,
first. Note also, that this does not build the linux kernel itself. This will
result in missing symbols, so we need `KBUILD_MODPOST_WARN=1`.

```bash
make -j$(nproc) -C $KDIR modules_prepare
make -j$(nproc) -C $KDIR KBUILD_MODPOST_WARN=1 M=drivers/char/tpm modules
```

### Build kernel and drivers

For testing with qemu, we need the kernel and the other drivers, as well.

```bash
make -j$(nproc) -C $KDIR bzImage
make -j$(nproc) -C $KDIR modules
```

### Build the rootfs

Lastly, we need a rootfs we can boot into. Let's just download an alpine rootfs
and install everything we need (including kernel modules, kselftests and
dependencies like python). The rootfs also contains the `init` script which will
call the kselftests.

```bash
KDIR=$KDIR scripts/rootfs.sh
```

## Test

First, we need a TPM simulator.

```bash
swtpm_socket=$(mktemp)
swtpm socket --tpmstate dir=$(mktemp -d) --ctrl type=unixio,path=$swtpm_socket --log level=20,file=/dev/null --tpm2
```

Then we can spin up qemu with our kernel and our rootfs. Make sure to use the
correct file names for kernel and rootfs.

```bash
qemu-system-x86_64 \
    -kernel build/bzImage-6.8.0-rc2-00200-g678aefbcb08d \
    -initrd build/minirootfs-6.8.0-rc2-00200-g678aefbcb08d.img.lz4 \
    -m size=512 \
    -nographic \
    -append "console=ttyS0 panic=-1" \
    -no-reboot \
    -nic user \
    -chardev socket,id=chrtpm,path=$swtpm_socket \
    -tpmdev emulator,id=tpm0,chardev=chrtpm -device tpm-tis,tpmdev=tpm0
```

