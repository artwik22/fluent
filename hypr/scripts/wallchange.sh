#!/bin/bash

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"

FILES=("$WALLPAPER_DIR"/*.{jpg,jpeg,png})
declare -A FILE_MAP
NUMS=()
ALPHA=()

for f in "${FILES[@]}"; do
    [[ -f "$f" ]] || continue
    BASENAME=$(basename "$f")
    NAME="${BASENAME%.*}"
    FILE_MAP["$NAME"]="$f"
    if [[ "$NAME" =~ ^[0-9]+$ ]]; then
        NUMS+=("$NAME")
    else
        ALPHA+=("$NAME")
    fi
done

# Sorting
IFS=$'\n' SORTED_NUMS=($(sort -n <<<"${NUMS[*]}"))
SORTED_ALPHA=($(printf '%s\n' "${ALPHA[@]}" | sort))
unset IFS

# Merge lists
FINAL_LIST=("${SORTED_NUMS[@]}" "${SORTED_ALPHA[@]}")

# Selection in rofi
CHOICE=$(printf '%s\n' "${FINAL_LIST[@]}" | rofi -dmenu -i -p "Choose wallpaper:")

# Set wallpaper
if [[ -n "$CHOICE" ]]; then
    swww img "${FILE_MAP[$CHOICE]}" --transition-fps 60 --transition-type fade
fi
