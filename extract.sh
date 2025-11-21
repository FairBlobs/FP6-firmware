#!/bin/bash

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <path-to-factory-image.zip>"
    exit 1
fi

tmpdir=$(mktemp -d)
mount=$(mktemp -d)

cleanup() {
    set +e
    sudo umount "$mount"

    sudo dmsetup remove /dev/mapper/dynpart-*
    sudo losetup -d "$loopdev"

    sudo rmdir "$mount"
    sudo rm -r "$tmpdir"
}
trap cleanup EXIT

unzip -j -d "$tmpdir" "$1" \*/images/BTFM.bin \*/images/dspso.bin \*/images/NON-HLOS.bin \*/images/super.img

mkdir hexagonfs hexagonfs/dsp hexagonfs/sensors

### NON-HLOS.bin ###
sudo mount -o ro "$tmpdir"/NON-HLOS.bin "$mount"
cp "$mount"/image/adsp* .
cp "$mount"/image/battmgr.jsn .
cp "$mount"/image/cdsp* .
cp "$mount"/image/ipa_fws.* .
cp -r "$mount"/image/modem* .
cp "$mount"/image/qca6750/wpss{.mdt,.b*} .
sudo umount "$mount"

### BTFM.bin ###
sudo mount -o ro "$tmpdir"/BTFM.bin "$mount"
cp "$mount"/image/msbtfw12.mbn .
cp "$mount"/image/msnv12.bin .
sudo umount "$mount"

### dspso.bin ###
sudo mount -o ro "$tmpdir"/dspso.bin "$mount"
cp -r "$mount"/*dsp hexagonfs/dsp/
sudo umount "$mount"

### super.img ###
simg2img "$tmpdir"/super.img "$tmpdir"/super.raw.img
rm "$tmpdir"/super.img

loopdev=$(sudo losetup --read-only --find --show "$tmpdir"/super.raw.img)
sudo dmsetup create --concise "$(sudo parse-android-dynparts "$loopdev")"

sudo mount -o ro /dev/mapper/dynpart-vendor_a "$mount"
cp "$mount"/firmware/{gen80300_gmu.bin,gen80300_sqe.fw,gen80300_zap.mbn} .
cp "$mount"/firmware/vpu20_2v.mbn .
cp -r "$mount"/etc/acdbdata hexagonfs/acdb
cp -r "$mount"/etc/sensors/config hexagonfs/sensors/config
cp -r "$mount"/etc/sensors/sns_reg_config hexagonfs/sensors/sns_reg.conf

# Sensor registry for hexagonfs is extracted from persist partition which is
# not shipped with the factory image.
# cp -r /mnt/persist/sensors/registry/registry hexagonfs/sensors/registry

# Socinfo files are extracted from the running device with stock Android.
# for i in hw_platform platform_subtype platform_subtype_id platform_version revision soc_id; do adb shell cat /sys/devices/soc0/$i > hexagonfs/socinfo/$i; done

# cleanup happens on exit with the signal handler at the top
