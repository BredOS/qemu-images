#!/bin/bash
# shellcheck disable=SC2034,SC2154
IMAGE_NAME="BredOS-cloudimg-aarch64-${build_version}.qcow2"
DISK_SIZE=""
# The growpart module[1] requires the growpart program, provided by the
# cloud-guest-utils package
# [1] https://cloudinit.readthedocs.io/en/latest/topics/modules.html#growpart
PACKAGES=(cloud-init cloud-guest-utils)
SERVICES=(cloud-init-local.service cloud-init.service cloud-config.service cloud-final.service)

function pre() {
  echo "Building cloud image"
  sed -i 's/^name: arch/name: bredos/' "${MOUNT}/etc/cloud/cloud.cfg"
  sed -i 's/^gecos: arch Cloud User/gecos: bredos Cloud User/' "${MOUNT}/etc/cloud/cloud.cfg"
  sed -Ei 's/^(GRUB_CMDLINE_LINUX_DEFAULT=.*)"$/\1 console=tty0 console=ttyS0,115200"/' "${MOUNT}/etc/default/grub"
  echo 'GRUB_TERMINAL="serial console"' >>"${MOUNT}/etc/default/grub"
  echo 'GRUB_SERIAL_COMMAND="serial --speed=115200"' >>"${MOUNT}/etc/default/grub"
  arch-chroot "${MOUNT}" /usr/bin/grub-mkconfig -o /boot/grub/grub.cfg
  rm "${MOUNT}/etc/machine-id" || true
}

function post() {
  qemu-img convert -c -f raw -O qcow2 "${1}" "${2}"
  rm "${1}"
}
