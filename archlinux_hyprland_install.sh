#!/usr/bin/env bash

set -e

DISK="/dev/sda"
USERNAME="aaditya"
PASSWORD="@r4q6n2h0f5t6r2#"
HOSTNAME="archlinux"

echo "=== Arch Linux Automated Installer ==="
echo "Target Disk: $DISK"
read -p "Press ENTER to continue (or Ctrl+C to cancel)..."

# Update system clock
timedatectl set-ntp true

# Partition the disk
echo "Partitioning $DISK..."
sgdisk -Z $DISK
sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI System Partition" $DISK
sgdisk -n 2:0:0 -t 2:8300 -c 2:"Linux filesystem" $DISK

# Format partitions
mkfs.fat -F32 ${DISK}1
mkfs.ext4 ${DISK}2

# Mount
mount ${DISK}2 /mnt
mkdir -p /mnt/boot/efi
mount ${DISK}1 /mnt/boot/efi

# Install base packages
echo "Installing base system..."
pacstrap /mnt base linux linux-firmware vim networkmanager sudo

# Fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot and configure
arch-chroot /mnt /bin/bash <<EOF
set -e
ln -sf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime
hwclock --systohc
sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "$HOSTNAME" > /etc/hostname

# Network
systemctl enable NetworkManager

# Create user
useradd -m -G wheel -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
echo "root:$PASSWORD" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Install GUI-related packages
pacman -S --noconfirm git nano wayland hyprland waybar rofi alacritty \
    ttf-roboto ttf-roboto-mono wofi sddm sddm-wayland neofetch \
    pipewire pipewire-pulse wireplumber xdg-desktop-portal-hyprland \
    network-manager-applet polkit-gnome grim slurp wl-clipboard \
    firefox thunar brightnessctl playerctl pamixer

# Enable login manager
systemctl enable sddm

# Setup Hyprland config
sudo -u $USERNAME mkdir -p /home/$USERNAME/.config/{hypr,waybar,wofi,alacritty}
sudo -u $USERNAME mkdir -p /home/$USERNAME/Pictures

# Sample wallpaper
curl -L -o /home/$USERNAME/Pictures/wallpaper.png https://images.unsplash.com/photo-1503264116251-35a269479413?w=1920

# Hyprland config
cat <<HYPRCONF | sudo -u $USERNAME tee /home/$USERNAME/.config/hypr/hyprland.conf >/dev/null
monitor=,preferred,auto,1
exec = waybar &
exec = wofi --show drun
exec = alacritty

general {
    gaps_in = 5
    border_size = 2
    col.active_border = rgba(00ff99ff)
    col.inactive_border = rgba(555555aa)
}

decoration {
    rounding = 10
    blur = yes
}

input {
    kb_layout = us
    follow_mouse = 1
}

bind = SUPER, RETURN, exec, alacritty
bind = SUPER, Q, killactive,
bind = SUPER, F, fullscreen
bind = SUPER, E, exec, thunar
bind = SUPER, D, exec, wofi --show drun
bind = SUPER, L, exec, hyprctl dispatch exit

workspace = 1, monitor:HDMI-A-1
HYPRCONF

# Waybar config
cat <<WAYBARCONF | sudo -u $USERNAME tee /home/$USERNAME/.config/waybar/config.jsonc >/dev/null
{
  "layer": "top",
  "modules-left": ["hyprland/workspaces"],
  "modules-center": ["clock"],
  "modules-right": ["cpu", "memory", "battery", "network"],
  "clock": { "format": "%a %b %d %H:%M" }
}
WAYBARCONF

cat <<WAYBARSTYLE | sudo -u $USERNAME tee /home/$USERNAME/.config/waybar/style.css >/dev/null
* {
  font-family: "Roboto";
  font-size: 12px;
  background: rgba(20, 20, 20, 0.9);
  color: #00ff99;
}
WAYBARSTYLE

# Alacritty config
cat <<ALACRITTY | sudo -u $USERNAME tee /home/$USERNAME/.config/alacritty/alacritty.yml >/dev/null
font:
  normal:
    family: Roboto Mono
  size: 12
colors:
  primary:
    background: '0x000000'
    foreground: '0x00ff99'
window:
  opacity: 0.95
ALACRITTY

EOF

echo "=== Installation complete! ==="
echo "You can now reboot into your new Arch Linux system."

