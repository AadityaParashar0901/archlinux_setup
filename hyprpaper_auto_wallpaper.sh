#!/bin/bash

WALLPAPER_DIR="~Pictures"
# Get a random image from the folder
NEW_WALLPAPER=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" \) | shuf -n 1)

# Preload the new wallpaper
hyprpaper preload "$NEW_WALLPAPER"

# Set the wallpaper for all monitors (or specific monitors like "DP-1")
hyprpaper wallpaper "VGA-1,$NEW_WALLPAPER"

# Optional: Unload unused wallpapers to free memory
hyprpaper unload unused
