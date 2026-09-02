#!/bin/bash
# install2.sh — main-server system configuration. Runs INSIDE arch-chroot,
# invoked by install1.sh. Can also be run by hand: arch-chroot /mnt /root/install2.sh
# Idempotent: safe to re-run.
set -euo pipefail

if [[ -r /root/main-server.env ]]; then . /root/main-server.env; fi
: "${HOSTNAME_FQDN:=server.ljlee37.com}"
: "${TIMEZONE:=Asia/Seoul}"
: "${LANG_DEFAULT:=en_US.UTF-8}"
: "${USERNAME:=ljlee}"
: "${LOCALES:=en_GB.UTF-8 UTF-8|en_US.UTF-8 UTF-8|eo UTF-8|ja_JP.UTF-8 UTF-8|ko_KR.EUC-KR EUC-KR|ko_KR.UTF-8 UTF-8}"

echo "==> time zone: ${TIMEZONE}"
ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
if [[ -e /dev/rtc0 ]]; then hwclock --systohc; else echo "   no /dev/rtc0 — skipping hwclock"; fi

echo "==> locales"
IFS='|' read -ra _loc <<< "$LOCALES"
for l in "${_loc[@]}"; do
    esc=$(sed 's/[.[\*^$/]/\\&/g' <<< "$l")
    if grep -qE "^#?[[:space:]]*${esc}[[:space:]]*$" /etc/locale.gen; then
        sed -i "s|^#\?[[:space:]]*${esc}[[:space:]]*$|${l}|" /etc/locale.gen
    else
        echo "$l" >> /etc/locale.gen
    fi
done
locale-gen
echo "LANG=${LANG_DEFAULT}" > /etc/locale.conf

echo "==> hostname / hosts"
echo "$HOSTNAME_FQDN" > /etc/hostname
short=${HOSTNAME_FQDN%%.*}
cat > /etc/hosts <<EOF
# Static table lookup for hostnames. See hosts(5).
127.0.0.1	localhost
::1		localhost
127.0.1.1	${HOSTNAME_FQDN} ${short}
EOF

echo "==> initramfs (LVM dm-cache)"
# dm-cache targets: force them in via MODULES. The lvm2 install hook also adds
# them, but it runs after 'autodetect', which filters anything not currently
# loaded — MODULES is not filtered.
sed -i 's|^MODULES=([^)]*)|MODULES=(dm-cache dm-cache-smq)|' /etc/mkinitcpio.conf
# 'lvm2' hook after 'block'. This lvm2 package ships only the (systemd-aware)
# 'lvm2' hook — there is no 'sd-lvm2' and no lvm2 runtime hook; activation is
# udev-event driven under the 'systemd' hook. Address the active HOOKS=( line
# only, so the commented example lines (which also contain ' block ') are left be.
if ! grep -qE '^HOOKS=\(.*[[:space:]]lvm2[[:space:]]' /etc/mkinitcpio.conf; then
    sed -i '/^HOOKS=(/ s|\([[:space:]]\)block[[:space:]]|\1block lvm2 |' /etc/mkinitcpio.conf
fi
grep -E '^(MODULES|HOOKS)=' /etc/mkinitcpio.conf
mkinitcpio -P
if ! lsinitcpio /boot/initramfs-linux.img | grep -qE 'dm[-_]cache'; then
    echo "   WARNING: dm-cache not found in initramfs-linux.img" >&2
fi

echo "==> user: ${USERNAME}"
if ! id -u "$USERNAME" >/dev/null 2>&1; then
    useradd -m -G wheel -s /bin/zsh "$USERNAME"
    echo "   set a password for ${USERNAME}:"
    passwd "$USERNAME"
else
    usermod -aG wheel -s /bin/zsh "$USERNAME"
fi
printf '%%wheel ALL=(ALL:ALL) ALL\n' > /etc/sudoers.d/10-wheel
chmod 440 /etc/sudoers.d/10-wheel
visudo -cf /etc/sudoers.d/10-wheel >/dev/null

echo "==> root password"
if [[ "$(passwd -S root 2>/dev/null | awk '{print $2}')" == "P" ]]; then
    echo "   root already has a password — leaving it. (run 'passwd' to change)"
else
    passwd
fi

echo "==> GRUB (UEFI, /boot = ESP)"
cat > /etc/default/grub <<'EOF'
GRUB_DEFAULT=0
GRUB_TIMEOUT=0
GRUB_DISTRIBUTOR="Arch"
GRUB_CMDLINE_LINUX_DEFAULT="nomodeset text"
GRUB_CMDLINE_LINUX=""
GRUB_PRELOAD_MODULES="part_gpt part_msdos"
GRUB_TIMEOUT_STYLE=menu
GRUB_TERMINAL_INPUT=console
GRUB_TERMINAL_OUTPUT=console
GRUB_GFXMODE=auto
GRUB_GFXPAYLOAD_LINUX=keep
GRUB_DISABLE_RECOVERY=true
EOF
# --removable also drops BOOTX64.EFI in the fallback path (survives NVRAM loss).
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Arch --removable
grub-mkconfig -o /boot/grub/grub.cfg
if ! grep -qE 'root=/dev/mapper/vg0-root|root=/dev/vg0/root|rd\.lvm\.lv=vg0/root' /boot/grub/grub.cfg; then
    echo "   WARNING: grub.cfg has no vg0 root= entry — check before rebooting" >&2
fi
grep -q 'intel-ucode' /boot/grub/grub.cfg && echo "   intel-ucode.img: picked up" || echo "   NOTE: intel-ucode.img not referenced"

echo "==> services"
systemctl enable dhcpcd sshd
# Everything else (mariadb, netatalk, avahi-daemon, docker, noip2, ufw, cronie)
# is enabled/configured by server-automation (Ansible), not here.

echo
echo "install2 done. Back in install1.sh / the live env: unmount and reboot."
