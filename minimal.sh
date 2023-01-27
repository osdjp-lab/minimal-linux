#!/bin/sh

# Setting of bash script debug flags
set -ex

# Specification of package versions
KERNEL_VERSION=5.11.6
BUSYBOX_VERSION=1.33.0
SYSLINUX_VERSION=6.03

# Package download
wget -O kernel.tar.xz http://kernel.org/pub/linux/kernel/v5.x/linux-${KERNEL_VERSION}.tar.xz
wget -O busybox.tar.bz2 http://busybox.net/downloads/busybox-${BUSYBOX_VERSION}.tar.bz2
wget -O syslinux.tar.xz http://kernel.org/pub/linux/utils/boot/syslinux/syslinux-${SYSLINUX_VERSION}.tar.xz

# Package content extraction
tar -xvf kernel.tar.xz
tar -xvf busybox.tar.bz2
tar -xvf syslinux.tar.xz
mkdir isoimage

# Busybox build
cd busybox-${BUSYBOX_VERSION}
make distclean defconfig
sed -i "s|.*CONFIG_STATIC.*|CONFIG_STATIC=y|" .config
make busybox install
cd _install
rm -f linuxrc
mkdir dev proc sys

# Setting of init script
cat > init << EOF
#!/bin/sh
dmesg -n 1
mount -t devtmpfs none /dev
mount -t proc none /proc
mount -t sysfs none /sys
setsid cttyhack /bin/sh
EOF
chmod +x init

# Packaging of rootfs into compressed archive
find . | cpio -R root:root -H newc -o | gzip > ../../isoimage/rootfs.gz

# Linux kernel build
cd ../../linux-${KERNEL_VERSION}
make mrproper defconfig bzImage

# Placement of kernel and syslinux binary into isoimage folder
cp arch/x86/boot/bzImage ../isoimage/kernel.gz
cd ../isoimage
cp ../syslinux-${SYSLINUX_VERSION}/bios/core/isolinux.bin .
cp ../syslinux-${SYSLINUX_VERSION}/bios/com32/elflink/ldlinux/ldlinux.c32 .
echo 'default kernel.gz initrd=rootfs.gz' > ./isolinux.cfg

# Packaging of system into iso image
xorriso \
  -as mkisofs \
  -o ../minimal_linux_live.iso \
  -b isolinux.bin \
  -c boot.cat \
  -no-emul-boot \
  -boot-load-size 4 \
  -boot-info-table \
  ./
cd ..

# Unsetting of bash script debug flags
set +ex
