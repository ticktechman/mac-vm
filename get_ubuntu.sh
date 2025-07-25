#!/usr/bin/env bash
###############################################################################
##
##       filename: get_ubuntu.sh
##    description:
##        created: 2025/07/22
##         author: ticktechman
##
###############################################################################

## first: brew install bash
## bash 4.x+ support map but the original macOS bash version is v3.2

declare -A images
images["initrd"]="https://cloud-images.ubuntu.com/releases/plucky/release/unpacked/ubuntu-25.04-server-cloudimg-arm64-initrd-generic"
images["vmlinuz.gz"]="https://cloud-images.ubuntu.com/releases/plucky/release/unpacked/ubuntu-25.04-server-cloudimg-arm64-vmlinuz-generic"
images["rootfs.img"]="https://cloud-images.ubuntu.com/releases/plucky/release/ubuntu-25.04-server-cloudimg-arm64.img"

[[ -d images ]] || mkdir images

for one in "${!images[@]}"; do
  wget -O "./images/$one" "${images[$one]}"
done

[[ ! -f "./images/vmlinuz.gz" ]] || {
  if gzip -t "./images/vmlinuz.gz" 2>/dev/null; then
    gunzip ./images/vmlinuz.gz
  fi
}

[[ ! -f "./images/rootfs.img" ]] || {
  qemu-img convert -O raw ./images/rootfs.img ./images/rootfs.raw
}

###############################################################################
