#!/bin/sh
qemu-system-x86_64 \
    -m 64M \
    -smp 1 \
    -kernel ./bzImage \
    -initrd ./rootfs.cpio \
    -append "console=ttyS0 panic=1 kpti=1 quiet" \
    -cpu kvm64,+smep \
    -monitor /dev/null \
    -nographic
