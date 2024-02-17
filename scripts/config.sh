#!/bin/sh

set -x
set -e

[ "$KDIR" = "" ] && { echo "Variable KDIR is not set"; exit 1; }

make -j$(nproc) -C $KDIR defconfig
$KDIR/scripts/config --file $KDIR/.config --module TCG_TPM
$KDIR/scripts/config --file $KDIR/.config --module TCG_TIS
$KDIR/scripts/config --file $KDIR/.config --module TCG_TIS_I2C
$KDIR/scripts/config --file $KDIR/.config --module TCG_TIS_CORE
$KDIR/scripts/config --file $KDIR/.config --module TCG_TIS_SPI
$KDIR/scripts/config --file $KDIR/.config --enable HW_RANDOM_TPM
$KDIR/scripts/config --file $KDIR/.config --disable TCG_TIS_I2C_CR50
$KDIR/scripts/config --file $KDIR/.config --disable TCG_TIS_I2C_ATMEL
$KDIR/scripts/config --file $KDIR/.config --disable TCG_TIS_I2C_INFINEON
$KDIR/scripts/config --file $KDIR/.config --disable TCG_TIS_I2C_NUVOTON
$KDIR/scripts/config --file $KDIR/.config --disable TCG_NSC
$KDIR/scripts/config --file $KDIR/.config --disable TCG_ATMEL
$KDIR/scripts/config --file $KDIR/.config --disable TCG_INFINEON
$KDIR/scripts/config --file $KDIR/.config --disable TCG_CRB
$KDIR/scripts/config --file $KDIR/.config --disable TCG_VTPM_PROXY
$KDIR/scripts/config --file $KDIR/.config --disable TCG_TIS_ST33ZP24_I2C
$KDIR/scripts/config --file $KDIR/.config --disable TRUSTED_KEYS
$KDIR/scripts/config --file $KDIR/.config --enable TCG_SPDM
