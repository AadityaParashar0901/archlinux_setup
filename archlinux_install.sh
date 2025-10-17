#!/usr/bin/env bash
# Automated Arch Linux Installer + GRUB (UEFI)

set -euo pipefail
IFS=$'\n\t'

# === CONFIG ===
DISK="/dev/sda"
USERNAME="aaditya"
PASSWORD="@r4q6n2h0f5t6r2#"
HOSTNAME="archlinux"
TIMEZONE="Asia/Kolkata"
LOCALE="en_US.UTF-8"
LANG="${LOCALE}"
EFI_PART="${DISK}1"
SWAP_PART="${DISK}2"
ROOT_PART="${DISK}3"

echo "=== Arch Linux Automated Installer ==="
echo "Target disk: $DISK"
read -r -p "Press ENTER to continue or Ctrl+C to cancel..."

# === Prepare ===
timedatectl set-ntp true

echo "Wiping partitions on $DISK..."
sgdisk -Z "$DISK"
echo "Creating partitions..."
sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI System Partition" "$DISK"
sgdisk -n 2:0:+512M -t 2:8200 -c 2:"Linux Swap" "$DISK"
sgdisk -n 3:0:0 -t 3:8300 -c 3:"Linux filesystem" "$DISK"

echo "Formatting partitions..."
mkfs.fat -F32 "$EFI_PART"
mkfs.ext4 "$ROOT_PART"
mkswap "$SWAP_PART"

echo "Mounting..."
mount "$ROOT_PART" /mnt
mount --mkdir "$EFI_PART" /mnt/boot
swapon "$SWAP_PART"

# === Base system install ===
echo "Installing base system..."
pacstrap -K /mnt base linux linux-firmware vim networkmanager sudo \
  efibootmgr grub git nano fastfetch iwd htop btop curl

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# === Chroot configuration ===
arch-chroot /mnt /bin/bash <<EOF
set -euo pipefail

pacman -Scc

# Timezone and locale
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
hwclock --systohc
sed -i 's/^#${LOCALE}/${LOCALE}/' /etc/locale.gen || true
echo "LANG=${LANG}" > /etc/locale.conf
locale-gen

# Hostname
echo "${HOSTNAME}" > /etc/hostname

# Enable NetworkManager
systemctl enable NetworkManager

EOF

arch-chroot /mnt /bin/bash <<EOF
# Root & user setup
echo "Adding User"
echo "root:${PASSWORD}" | chpasswd
useradd -m -G wheel -s /bin/bash ${USERNAME}
echo "${USERNAME}:${PASSWORD}" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
EOF

# Install and configure GRUB (UEFI)
echo "Installing GRUB (UEFI)..."
arch-chroot /mnt /bin/bash <<EOF
# Install grub to the EFI directory
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB

# Finally generate grub.cfg
grub-mkconfig -o /boot/grub/grub.cfg
EOF

umount -R /mnt
reboot
