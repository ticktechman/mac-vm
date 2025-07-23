#!/usr/bin/env bash
###############################################################################
##
##       filename: gen-cloud-init.sh
##    description:
##        created: 2025/07/22
##         author: ticktechman
##
###############################################################################

# === CONFIG ===
USER_NAME=${1:-ubuntu}
HOST_NAME=${2:plucky-vm}
SSH_KEY=${3:-"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINorAKTkV9MgQl7w8OQq7tyL71i+vRbAi2fhxhWihwdB ticktech@ubuntu"}

# Create temporary working directory
WORKDIR='./seed'
rm -rf $WORKDIR
CIDATADIR="$WORKDIR/cidata"
mkdir -p "$CIDATADIR"

echo "Working in $CIDATADIR"

# Create user-data
cat >"$CIDATADIR/user-data" <<EOF
#cloud-config
hostname: plucky-vm
users:
  - name: $USER_NAME
    shell: /bin/bash
    groups: sudo
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    lock_passwd: False
    ssh_authorized_keys: "$SSH_KEY"
    passwd: "$(openssl passwd -6 $USER_NAME)"
ssh_pwauth: True
chpasswd:
  expire: False
EOF

# Create meta-data
cat >"$CIDATADIR/meta-data" <<EOF
instance-id: $(uuidgen)
local-hostname: $HOST_NAME
EOF

# network-config
cat >"$CIDATADIR/network-config" <<EOF
version: 2
ethernets:
  enp0s1:
    dhcp4: true
EOF

# Create ISO using hdiutil (macOS built-in)
ISO_NAME="seed.iso"
rm -f $ISO_NAME
mkisofs -output "$ISO_NAME" \
  -volid CIDATA \
  -joliet \
  -rock \
  -input-charset utf-8 \
  -allow-lowercase \
  "$CIDATADIR"

echo "ISO created: $ISO_NAME"

###############################################################################
