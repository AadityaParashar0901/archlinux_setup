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
sgdisk -n 2:0:+1G -t 2:8200 -c 2:"Linux Swap" "$DISK"
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
  efibootmgr grub git nano fastfetch iwd
# Add packages we want later (GUI + fonts etc.)
pacstrap -K /mnt hyprland waybar hyprpaper hyprlock rofi-wayland alacritty \
  xdg-desktop-portal-hyprland xdg-desktop-portal xdg-desktop-portal-gtk

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

pacstrap -S pipewire wireplumber pipewire-pulse pavucontrol helvum vlc \
  thunar tumbler file-roller okular gthumb \
  network-manager-applet nm-connection-editor firefox \
  htop btop gnome-disk-utility pavucontrol brightnessctl pamixer playerctl \
  lxappearance qt5ct qt6ct papirus-icon-theme gnome-themes-extra nwg-look \
  cliphist wl-clipboard swaync grim slurp swappy \
  neovim wget curl flatpak filelight p7zip unzip \
pacman -Scc

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

# Additional user-level setup (configs, wallpaper)
mkdir -p /home/${USERNAME}/.config/{hypr,waybar,wofi,alacritty}
mkdir -p /home/${USERNAME}/Pictures
curl https://raw.githubusercontent.com/AadityaParashar0901/archlinux_setup/master/hyprland.conf -o /home/${USERNAME}/.config/hypr/hyprland.conf
curl https://raw.githubusercontent.com/AadityaParashar0901/archlinux_setup/master/hyprpaper.conf -o /home/${USERNAME}/.config/hypr/hyprpaper.conf
curl https://raw.githubusercontent.com/AadityaParashar0901/archlinux_setup/master/config.jsonc -o /home/${USERNAME}/.config/waybar/config.jsonc
curl https://raw.githubusercontent.com/AadityaParashar0901/archlinux_setup/master/style.css -o /home/${USERNAME}/.config/waybar/style.css
curl https://raw.githubusercontent.com/AadityaParashar0901/archlinux_setup/master/wallpaper.png -o /home/${USERNAME}/Pictures/wallpaper.png
chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}

EOF

umount-R /mnt
reboot
