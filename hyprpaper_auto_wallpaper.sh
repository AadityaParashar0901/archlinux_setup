#!/bin/bash
# Folder containing wallpapers
WALL_DIR="$HOME/Pictures"

# Pick a random wallpaper
WALLPAPER=$(find "$WALL_DIR" -type f | shuf -n 1)

# Set wallpaper with hyprpaper
hyprctl hyprpaper unload all
hyprctl hyprpaper preload "$WALLPAPER"
hyprctl hyprpaper wallpaper ",$WALLPAPER"
