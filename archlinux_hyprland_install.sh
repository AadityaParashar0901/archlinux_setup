#!/bin/bash
set -e

# ========================
# CONFIG
# ========================
DISK="/dev/sda"
HOSTNAME="archlinux"
USERNAME="aaditya"
PASSWORD="@r4q6n2h0f5t6r2#"

echo "Installing Arch Linux on $DISK (this will wipe it)"
read -p "Press ENTER to continue..."

# ========================
# PARTITION & FORMAT
# ========================
wipefs -a "$DISK"
parted -s "$DISK" mklabel gpt
parted -s "$DISK" mkpart ESP fat32 1MiB 513MiB
parted -s "$DISK" set 1 esp on
parted -s "$DISK" mkpart ROOT ext4 513MiB 100%

mkfs.fat -F32 "${DISK}1"
mkfs.ext4 -F "${DISK}2"

mount "${DISK}2" /mnt
mkdir -p /mnt/boot
mount "${DISK}1" /mnt/boot

# ========================
# BASE INSTALL
# ========================
pacstrap /mnt base linux linux-firmware networkmanager sudo vim git nano

genfstab -U /mnt >> /mnt/etc/fstab

# ========================
# CONFIGURE SYSTEM
# ========================
arch-chroot /mnt /bin/bash <<EOF
echo "$HOSTNAME" > /etc/hostname
ln -sf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime
hwclock --systohc
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen

systemctl enable NetworkManager

useradd -m -G wheel -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
echo "root:$PASSWORD" | chpasswd
echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers

# Bootloader
pacman --noconfirm -S grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=ARCHUSB
grub-mkconfig -o /boot/grub/grub.cfg

# ========================
# DESKTOP ENVIRONMENT
# ========================
pacman --noconfirm -S \
  hyprland hyprlock waybar alacritty firefox \
  thunar network-manager-applet \
  xdg-desktop-portal-hyprland polkit-gnome \
  pipewire wireplumber pipewire-alsa pipewire-pulse \
  ttf-dejavu ttf-font-awesome \
  grim slurp wl-clipboard swaybg wofi \
  gdm

# Enable GDM login manager
systemctl enable gdm

# Create Hyprland session entry for GDM
mkdir -p /usr/share/wayland-sessions
cat >/usr/share/wayland-sessions/hyprland.desktop <<'DESKTOP'
[Desktop Entry]
Name=Hyprland
Comment=Dynamic tiling Wayland compositor
Exec=Hyprland
Type=Application
DesktopNames=Hyprland
DESKTOP

# Auto login user (optional)
mkdir -p /etc/gdm
cat >/etc/gdm/custom.conf <<'AUTOGDM'
[daemon]
AutomaticLoginEnable=True
AutomaticLogin=aadi
WaylandEnable=true
AUTOGDM

# ========================
# HYPRLAND CONFIG
# ========================
sudo -u $USERNAME mkdir -p /home/$USERNAME/.config/{hypr,waybar}

cat <<HYPR >/home/$USERNAME/.config/hypr/hyprland.conf
monitor=,preferred,auto,1

exec-once = hyprctl setcursor "Adwaita" 24
exec-once = waybar &
exec-once = nm-applet &
exec-once = firefox &
exec-once = thunar &
exec-once = swaybg -i /usr/share/backgrounds/archlinux/archbtw.jpg -m fill

# Lock screen shortcut
bind = SUPER, L, exec, hyprlock

bind = SUPER, RETURN, exec, alacritty
bind = SUPER, W, exec, firefox
bind = SUPER, E, exec, thunar
bind = SUPER, Q, killactive,
bind = SUPER, F, fullscreen,
bind = SUPER, ESCAPE, exit,
bind = SUPER, R, exec, wofi --show drun

input {
  kb_layout = us
  follow_mouse = 1
}

decoration {
  rounding = 8
  blur = yes
  blur_size = 8
  drop_shadow = yes
  shadow_range = 10
  shadow_render_power = 2
}

animations {
  enabled = yes
  bezier = easeOutQuint, 0.23, 1, 0.32, 1
  animation = windows, 1, 7, easeOutQuint
  animation = border, 1, 10, easeOutQuint
  animation = fade, 1, 7, easeOutQuint
}

windowrulev2 = float, class:^(pavucontrol)\$
windowrulev2 = size 800 600, class:^(pavucontrol)\$
HYPR

cat <<WAYBAR >/home/$USERNAME/.config/waybar/config.jsonc
{
  "layer": "top",
  "position": "top",
  "modules-left": ["clock", "cpu", "memory"],
  "modules-center": ["window"],
  "modules-right": ["network", "pulseaudio", "tray"],

  "clock": { "format": "{:%H:%M}" },
  "cpu": { "format": "CPU {usage}%" },
  "memory": { "format": "RAM {used:0.1f}G" },
  "network": { "format-wifi": "{essid} ({signalStrength}%)", "format-ethernet": "{ifname}" },
  "pulseaudio": { "format": "VOL {volume}%" }
}
WAYBAR

cat <<STYLE >/home/$USERNAME/.config/waybar/style.css
* {
  font-family: JetBrainsMono, sans-serif;
  font-size: 11pt;
  color: #e0e0e0;
}
window { background: #1e1e2e; }
#clock, #cpu, #memory, #network, #pulseaudio { padding: 0 10px; }
STYLE

chown -R $USERNAME:$USERNAME /home/$USERNAME/.config

# ========================
# VM FIXES
# ========================
echo "WLR_NO_HARDWARE_CURSORS=1" >> /etc/environment
echo "WLR_RENDERER_ALLOW_SOFTWARE=1" >> /etc/environment

EOF

umount -R /mnt
echo "Installation complete!"
echo "Username: $USERNAME Password: $PASSWORD"
echo "Boot your Arch system — GDM will start Hyprland automatically."
