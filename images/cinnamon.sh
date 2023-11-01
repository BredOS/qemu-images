#!/bin/bash
# shellcheck disable=SC2034,SC2154
IMAGE_NAME="BredOS-qemu-aarch64-${build_version}.qcow2"
# It is meant for local usage so the disk should be "big enough".
DISK_SIZE="40G"
PACKAGES=(networkmanager nano vim wget yay network-manager-applet gvfs firefox qemu-guest-agent spice-vdagent bakery bakery-gui neofetch bred-skel-default fish lightdm lightdm-slick-greeter cinnamon gnome-terminal xorg noto-fonts gedit gnome-system-monitor mint-themes mint-y-icons engrampa hicolor-icon-theme)
SERVICES=(NetworkManager.service lightdm.service)

function pre() {
    echo "Building cinnamon image"
    local NEWUSER="bred"
    arch-chroot "${MOUNT}" /usr/bin/useradd -m -U "${NEWUSER}" -G wheel -s /usr/bin/fish
    echo -e "${NEWUSER}\n${NEWUSER}" | arch-chroot "${MOUNT}" /usr/bin/passwd "${NEWUSER}"
    echo "${NEWUSER} ALL=(ALL) NOPASSWD: ALL" >"${MOUNT}/etc/sudoers.d/${NEWUSER}"
    echo "%wheel ALL=(ALL) NOPASSWD: ALL" >"${MOUNT}/etc/sudoers.d/10-wheel"
    printf "y\ny\n" | arch-chroot "${MOUNT}" /usr/bin/pacman -Scc
#     cat <<EOF >"${MOUNT}/etc/plymouth/plymouthd.conf"
# # Set your plymouth configuration here.
# [Daemon]
# Theme=reborn
# ShowDelay=0
# DeviceTimeout=8
# EOF
#     echo "GRUB_THEME=\"/boot/grub/themes/Vimix/theme.txt\"" >>"${MOUNT}/etc/default/grub"
#     sed -Ei 's/^(GRUB_CMDLINE_LINUX_DEFAULT=.*)"$/\1 splash"/' "${MOUNT}/etc/default/grub"

    # make a backup of lightdm.conf
    cp "${MOUNT}/etc/lightdm/lightdm.conf" "${MOUNT}/etc/lightdm/lightdm.conf.bak"
    # set lightdm to autologin with user bred user-session=cinnamon and set greeter-session=lightdm-slick-greeter
    # sed -i '/^\[Seat:\*\]$/a autologin-user={username}\\nuser-session={de}' ./lightdm.conf
    sed -i '/^\[Seat:\*\]$/a autologin-user=bred\\nuser-session=cinnamon\\ngreeter-session=lightdm-slick-greeter' "${MOUNT}/etc/lightdm/lightdm.conf"
    # add oemcleanup.service to a service file
    cat <<EOF >"${MOUNT}/etc/systemd/system/oemcleanup.service"
[Unit]
Description=Remove OEM user

[Service]
Type=oneshot
RemainAfterExit=no
ExecStart=/usr/bin/oemcleanup

[Install]
WantedBy=multi-user.target
EOF
    # add the oemcleanup thing
    cat <<EOF >"${MOUNT}/usr/bin/oemcleanup"
#! /bin/sh

/usr/bin/userdel -r -f bred
/usr/bin/rm -rf /home/bred || true
/usr/bin/systemctl disable oemcleanup.service
/usr/bin/rm /etc/systemd/system/oemcleanup.service
/usr/bin/rm /usr/bin/oemcleanup
EOF
    # copy the /usr/share/applications/org.bredos.bakery.desktop file to /home/${NEWUSER}/.config/autostart
    mkdir -p "${MOUNT}/home/${NEWUSER}/.config/autostart"
    cp "${MOUNT}/usr/share/applications/org.bredos.bakery.desktop" "${MOUNT}/home/${NEWUSER}/.config/autostart"
    arch-chroot "${MOUNT}" grub-mkconfig -o /boot/grub/grub.cfg
    sed -i 's/^HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck plymouth)/' "${MOUNT}/etc/mkinitcpio.conf"
    arch-chroot "${MOUNT}" mkinitcpio -P
    rm "${MOUNT}/etc/machine-id" || true
}

function post() {
  qemu-img convert -c -f raw -O qcow2 "${1}" "${2}"
  rm "${1}"
}