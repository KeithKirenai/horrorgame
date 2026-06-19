#!/bin/bash
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
