import os
import shutil
import re

# 1. Rename existing procedural textures in raw and output directories to include _proc
raw_dir = "assets/textures/raw"
out_dir = "assets/textures"
artifacts_dir = "/home/carlos/.gemini/antigravity/brain/74e2868f-bca2-4d94-a040-e89f64e92fae"

# We have 16 textures
texture_names = [
    "wall_concrete_dark", "floor_grate", "ceiling_panel", "crate_wood",
    "wall_pipes", "poster_warning", "wall_tile_white", "wall_tile_damaged",
    "floor_tile_linoleum", "ceiling_tile_acoustic", "poster_medical",
    "floor_blood_pool", "ground_dirt", "wall_stone_ruins", "foliage_dark",
    "gravel_path"
]

# Rename existing procedural ones
print("Renaming procedural textures to use _proc suffix...")
for name in texture_names:
    # in raw
    raw_path = os.path.join(raw_dir, name + ".png")
    if os.path.exists(raw_path):
        shutil.move(raw_path, os.path.join(raw_dir, name + "_proc.png"))
        print(f"Moved raw procedural: {name} -> {name}_proc")
        
    # in output
    out_path = os.path.join(out_dir, name + ".png")
    if os.path.exists(out_path):
        shutil.move(out_path, os.path.join(out_dir, name + "_proc.png"))
        print(f"Moved output procedural: {name} -> {name}_proc")

# 2. Copy AI generated images from artifacts folder to raw/
print("Locating and copying AI-generated textures from artifacts folder...")
artifacts_files = os.listdir(artifacts_dir)

for name in texture_names:
    # Look for files matching name_XXXX.png or name_XXXX_timestamp.png
    # The generate_image saves it with a suffix, e.g. wall_concrete_dark_1781798315522.png
    pattern = re.compile(rf"^{name}_\d+\.png$")
    matching_files = [f for f in artifacts_files if pattern.match(f)]
    
    if matching_files:
        # Sort to get the latest one if multiple exist
        matching_files.sort()
        src_file = matching_files[-1]
        src_path = os.path.join(artifacts_dir, src_file)
        dest_path = os.path.join(raw_dir, name + ".png")
        shutil.copy(src_path, dest_path)
        print(f"Copied AI texture: {src_file} -> {name}.png")
    else:
        print(f"WARNING: No AI texture found for {name} in artifacts!")

# 3. Update process_textures.sh to process BOTH sets
print("Updating process_textures.sh to support both AI and Procedural textures...")
sh_content = """#!/bin/bash
# Process raw textures to look like compressed PS1 textures

INPUT_DIR="raw"
OUTPUT_DIR="."

mkdir -p "$INPUT_DIR"

process_texture() {
    local name=$1
    local size=$2
    local colors=$3
    local dither=$4
    
    if [ -f "$INPUT_DIR/$name" ]; then
        echo "Processing $name..."
        if [ "$name" = "blood_splatter.png" ] || [ "$name" = "floor_blood_pool.png" ] || [ "$name" = "floor_blood_pool_proc.png" ]; then
            magick "$INPUT_DIR/$name" -fuzz 15% -transparent white -resize "${size}x${size}!" -colors "$colors" -scale 256x256! "$OUTPUT_DIR/$name"
        elif [ "$dither" = "true" ]; then
            magick "$INPUT_DIR/$name" -resize "${size}x${size}!" -colors "$colors" -dither FloydSteinberg -scale 256x256! "$OUTPUT_DIR/$name"
        else
            magick "$INPUT_DIR/$name" -resize "${size}x${size}!" -colors "$colors" -scale 256x256! "$OUTPUT_DIR/$name"
        fi
    fi
}

# Base textures
process_texture "wall_concrete.png" "128" "32" "true"
process_texture "floor_concrete.png" "128" "32" "true"
process_texture "ceiling_concrete.png" "128" "24" "true"
process_texture "box_cardboard.png" "64" "16" "true"
process_texture "metal_rust.png" "64" "16" "true"
process_texture "page_note.png" "128" "8" "false"
process_texture "blood_splatter.png" "64" "8" "false"

# AI TEXTURES
# Tape 1 - Industrial
process_texture "wall_concrete_dark.png" "128" "32" "true"
process_texture "floor_grate.png" "128" "32" "true"
process_texture "ceiling_panel.png" "128" "24" "true"
process_texture "crate_wood.png" "64" "16" "true"
process_texture "wall_pipes.png" "128" "32" "true"
process_texture "poster_warning.png" "128" "8" "false"

# Tape 2 - Medical
process_texture "wall_tile_white.png" "128" "32" "true"
process_texture "wall_tile_damaged.png" "128" "32" "true"
process_texture "floor_tile_linoleum.png" "128" "32" "true"
process_texture "ceiling_tile_acoustic.png" "128" "24" "true"
process_texture "poster_medical.png" "128" "8" "false"
process_texture "floor_blood_pool.png" "64" "8" "false"

# Tape 3 - Outdoor
process_texture "ground_dirt.png" "128" "32" "true"
process_texture "wall_stone_ruins.png" "128" "32" "true"
process_texture "foliage_dark.png" "128" "32" "true"
process_texture "gravel_path.png" "128" "32" "true"


# PROCEDURAL TEXTURES
# Tape 1 - Industrial
process_texture "wall_concrete_dark_proc.png" "128" "32" "true"
process_texture "floor_grate_proc.png" "128" "32" "true"
process_texture "ceiling_panel_proc.png" "128" "24" "true"
process_texture "crate_wood_proc.png" "64" "16" "true"
process_texture "wall_pipes_proc.png" "128" "32" "true"
process_texture "poster_warning_proc.png" "128" "8" "false"

# Tape 2 - Medical
process_texture "wall_tile_white_proc.png" "128" "32" "true"
process_texture "wall_tile_damaged_proc.png" "128" "32" "true"
process_texture "floor_tile_linoleum_proc.png" "128" "32" "true"
process_texture "ceiling_tile_acoustic_proc.png" "128" "24" "true"
process_texture "poster_medical_proc.png" "128" "8" "false"
process_texture "floor_blood_pool_proc.png" "64" "8" "false"

# Tape 3 - Outdoor
process_texture "ground_dirt_proc.png" "128" "32" "true"
process_texture "wall_stone_ruins_proc.png" "128" "32" "true"
process_texture "foliage_dark_proc.png" "128" "32" "true"
process_texture "gravel_path_proc.png" "128" "32" "true"

echo "Done!"
"""

with open("assets/textures/process_textures.sh", "w") as f:
    f.write(sh_content)

print("Done organizing and updating shell script.")
