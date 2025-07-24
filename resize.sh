#!/usr/bin/env bash
###############################################################################
##
##       filename: resize.sh
##    description:
##        created: 2025/07/24
##         author: ticktechman
##
###############################################################################

set -e
IMG_FILE="./images/rootfs.raw"

qemu-img resize "$IMG_FILE" +10G

fdisk "$IMG_FILE" <<EOF
p
e
1

w
p
EOF

fdisk -l "$IMG_FILE"

###############################################################################
