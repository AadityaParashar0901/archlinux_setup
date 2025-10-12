#!/usr/bin/env bash
# Automated Arch Linux Installer + GRUB (UEFI) + stylish GRUB background & font
# WARNING: This will wipe the disk defined in DISK variable.

set -euo pipefail
IFS=$'\n\t'

# === CONFIG ===
DISK="/dev/sda"                    # change if different (e.g., /dev/nvme0n1)
USERNAME="aaditya"
PASSWORD="@r4q6n2h0f5t6r2#"
HOSTNAME="archlinux"
TIMEZONE="Asia/Kolkata"
LOCALE="en_US.UTF-8"
LANG="${LOCALE}"
EFI_PART="${DISK}1"
ROOT_PART="${DISK}2"
WALLPAPER_URL="https://images.unsplash.com/photo-1503264116251-35a269479413?w=1920"
GRUB_BG_URL="https://images.unsplash.com/photo-1503264116251-35a269479413?w=1920" # reuse or change
# Note: If using a different image, ensure it is reasonable resolution and PNG/JPG

echo "=== Arch Linux Automated Installer (with GRUB & stylish GRUB image) ==="
echo "Target disk: $DISK"
read -r -p "Press ENTER to continue or Ctrl+C to cancel..."

# === Prepare ===
timedatectl set-ntp true

echo "Wiping partitions on $DISK..."
sgdisk -Z "$DISK"

echo "Creating partitions..."
# 512MiB EFI, rest root
sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI System Partition" "$DISK"
sgdisk -n 2:0:0 -t 2:8300 -c 2:"Linux filesystem" "$DISK"

echo "Formatting partitions..."
mkfs.fat -F32 "$EFI_PART"
mkfs.ext4 "$ROOT_PART"

echo "Mounting..."
mount "$ROOT_PART" /mnt
mount --mkdir "$EFI_PART" /mnt/boot

# === Base system install ===
echo "Installing base system..."
pacstrap /mnt base linux linux-firmware vim networkmanager sudo \
  efibootmgr grub dosfstools mtools os-prober

# Add packages we want later (GUI + fonts etc.)
pacstrap /mnt git nano wayland hyprland waybar rofi alacritty \
    ttf-roboto ttf-roboto-mono wofi sddm fastfetch \
    pipewire pipewire-pulse wireplumber xdg-desktop-portal-hyprland \
    network-manager-applet polkit-gnome grim slurp wl-clipboard \
    firefox thunar brightnessctl playerctl pamixer swww imagemagick

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# === Chroot configuration ===
arch-chroot /mnt /bin/bash <<EOF
set -euo pipefail

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

# Root & user setup
echo "root:${PASSWORD}" | chpasswd
useradd -m -G wheel -s /bin/bash ${USERNAME}
echo "${USERNAME}:${PASSWORD}" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Install and configure GRUB (UEFI)
echo "Installing GRUB (UEFI)..."
# Ensure efibootmgr and grub packages are present (installed via pacstrap)

# Install grub to the EFI directory
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB

# Prepare fonts for GRUB so it looks nicer
mkdir -p /boot/grub/fonts
# Try to find Roboto Mono TTF installed by pkg; fallback if path differs
ROBO_TTF=""
if [ -f /usr/share/fonts/TTF/RobotoMono-Regular.ttf ]; then
  ROBO_TTF="/usr/share/fonts/TTF/RobotoMono-Regular.ttf"
elif [ -f /usr/share/fonts/TTF/Roboto-Regular.ttf ]; then
  ROBO_TTF="/usr/share/fonts/TTF/Roboto-Regular.ttf"
fi

if [ -n "\$ROBO_TTF" ]; then
  grub-mkfont --output=/boot/grub/fonts/RobotoMono.pf2 "\$ROBO_TTF" || true
  echo "Created GRUB font from \$ROBO_TTF"
fi

# Download a stylish background image for GRUB and place in /boot/grub/
mkdir -p /boot/grub
if command -v curl &>/dev/null; then
  curl -L -o /boot/grub/background.png "${GRUB_BG_URL}" || true
elif command -v wget &>/dev/null; then
  wget -O /boot/grub/background.png "${GRUB_BG_URL}" || true
fi

# If the image exists, convert to a supported format/size if needed
if [ -f /boot/grub/background.png ]; then
  # Convert to PNG (if not) and limit size to reasonable resolution
  if command -v convert &>/dev/null; then
    convert /boot/grub/background.png -resize 1920x1080\> /boot/grub/background.png || true
  fi
fi

# Create /etc/default/grub with stylish options
cat > /etc/default/grub <<GRUBCFG
GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="Arch"
GRUB_CMDLINE_LINUX_DEFAULT="quiet"
GRUB_CMDLINE_LINUX=""
GRUB_TERMINAL_OUTPUT=gfxterm
GRUB_GFXMODE=auto
GRUB_GFXPAYLOAD_LINUX=keep
# Set GRUB background if present
if [ -f /boot/grub/background.png ]; then
  GRUB_BACKGROUND="/boot/grub/background.png"
fi
# If we created a font, enable it
GRUB_FONT="/boot/grub/fonts/RobotoMono.pf2"
GRUB_DISABLE_OS_PROBER=false
GRUB_ENABLE_CRYPTODISK=n
GRUB_TIMEOUT_STYLE=menu
GRUB_THEME=""
GRUBCFG

# Finally generate grub.cfg
grub-mkconfig -o /boot/grub/grub.cfg

# Additional user-level setup (configs, wallpaper)
mkdir -p /home/${USERNAME}/.config/{hypr,waybar,wofi,alacritty}
mkdir -p /home/${USERNAME}/Pictures

# Download wallpaper for hyprland (also used earlier)
if command -v curl &>/dev/null; then
  curl -L -o /home/${USERNAME}/Pictures/wallpaper.png "${WALLPAPER_URL}" || true
elif command -v wget &>/dev/null; then
  wget -O /home/${USERNAME}/Pictures/wallpaper.png "${WALLPAPER_URL}" || true
fi
chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}

# Enable SDDM for Wayland (if desired)
systemctl enable sddm

EOF

echo "=== Installation finished on disk ${DISK} ==="
echo "You can now unmount and reboot:"
echo "  umount -R /mnt"
echo "  reboot"

# Final note printed to user
cat <<NOTE

Notes & customization tips:
- If your machine is not UEFI (or uses different device names), update DISK, EFI partition, and grub-install options.
- To change the GRUB background image, replace /boot/grub/background.png (supports PNG/JPG). After replacing run:
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
  (or boot into the installed system and run the grub-mkconfig command there.)
- If you want a full GRUB theme, you can set GRUB_THEME="/boot/grub/themes/yourtheme/theme.txt" in /etc/default/grub and add theme files under /boot/grub/themes/.
- Secure Boot is not handled by this script. If you use Secure Boot, additional steps are required.

NOTE
