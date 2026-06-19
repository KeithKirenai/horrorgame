import os
import math
import subprocess

def load_pixels_from_ppm(filename):
    with open(filename, "rb") as f:
        header = f.readline().decode().strip()
        if header != "P6":
            raise ValueError("Not a binary PPM (P6) file")
        
        # skip comments
        line = f.readline().decode()
        while line.startswith("#"):
            line = f.readline().decode()
            
        dims = line.strip().split()
        width = int(dims[0])
        height = int(dims[1])
        
        max_val = int(f.readline().decode().strip())
        if max_val != 255:
            raise ValueError("Only 8-bit PPM supported")
            
        data = f.read()
        pixels = []
        for i in range(0, len(data), 3):
            pixels.append((data[i], data[i+1], data[i+2]))
        return width, height, pixels

def save_pixels_to_ppm(filename, width, height, pixels):
    with open(filename, "wb") as f:
        f.write(f"P6\n{width} {height}\n255\n".encode())
        data = bytearray()
        for r, g, b in pixels:
            data.append(int(max(0, min(255, r))))
            data.append(int(max(0, min(255, g))))
            data.append(int(max(0, min(255, b))))
        f.write(data)

def generate_normal_and_height(base_name, dir_path, strength=2.0):
    png_path = os.path.join(dir_path, base_name + ".png")
    if not os.path.exists(png_path):
        return
        
    print(f"Generating Normal & Height maps for: {png_path}...")
    
    # Use magick to convert to PPM (force 8-bit depth)
    temp_ppm = os.path.join(dir_path, "temp_normal_in.ppm")
    subprocess.run(["magick", png_path, "-depth", "8", temp_ppm], check=True)
    
    width, height, pixels = load_pixels_from_ppm(temp_ppm)
    os.remove(temp_ppm)
    
    # Calculate height (greyscale) and normals
    height_pixels = []
    normal_pixels = []
    
    # Convert pixels to height value 0..1
    h_map = []
    for r, g, b in pixels:
        # Standard luminance formula
        lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
        h_map.append(lum)
        
    # Helper to get height with wrapping boundaries (seamless)
    def get_h(x, y):
        x = x % width
        y = y % height
        return h_map[y * width + x]
        
    for y in range(height):
        for x in range(width):
            # Height/Displacement pixel (greyscale)
            h_val = h_map[y * width + x]
            hv = int(h_val * 255)
            height_pixels.append((hv, hv, hv))
            
            # Normal calculation using central differences
            # Tangent X and Y
            dh_dx = (get_h(x + 1, y) - get_h(x - 1, y)) / 2.0
            dh_dy = (get_h(x, y + 1) - get_h(x, y - 1)) / 2.0
            
            # Normal vector: normalize(-dh_dx * strength, -dh_dy * strength, 1.0)
            nx = -dh_dx * strength
            ny = -dh_dy * strength
            nz = 1.0
            
            length = math.sqrt(nx*nx + ny*ny + nz*nz)
            nx /= length
            ny /= length
            nz /= length
            
            # Map normal coordinates to 0..255
            r_norm = int((nx + 1.0) * 0.5 * 255)
            g_norm = int((ny + 1.0) * 0.5 * 255)
            b_norm = int((nz + 1.0) * 0.5 * 255)
            
            normal_pixels.append((r_norm, g_norm, b_norm))
            
    # Save height map
    temp_ppm_h = os.path.join(dir_path, "temp_h.ppm")
    save_pixels_to_ppm(temp_ppm_h, width, height, height_pixels)
    out_h_png = os.path.join(dir_path, base_name + "_height.png")
    subprocess.run(["magick", temp_ppm_h, out_h_png], check=True)
    os.remove(temp_ppm_h)
    
    # Save normal map
    temp_ppm_n = os.path.join(dir_path, "temp_n.ppm")
    save_pixels_to_ppm(temp_ppm_n, width, height, normal_pixels)
    out_n_png = os.path.join(dir_path, base_name + "_normal.png")
    subprocess.run(["magick", temp_ppm_n, out_n_png], check=True)
    os.remove(temp_ppm_n)
    
    print(f"  Saved: {out_n_png} and {out_h_png}")

def process_all_maps():
    targets = [
        "wall_concrete_dark", "floor_grate", "ceiling_panel", "crate_wood",
        "wall_pipes", "wall_tile_white", "wall_tile_damaged",
        "floor_tile_linoleum", "ceiling_tile_acoustic",
        "ground_dirt", "wall_stone_ruins", "gravel_path",
        
        "wall_concrete_dark_proc", "floor_grate_proc", "ceiling_panel_proc", "crate_wood_proc",
        "wall_pipes_proc", "wall_tile_white_proc", "wall_tile_damaged_proc",
        "floor_tile_linoleum_proc", "ceiling_tile_acoustic_proc",
        "ground_dirt_proc", "wall_stone_ruins_proc", "gravel_path_proc"
    ]
    
    # Process raw versions first (high resolution detail)
    print("Generating maps for uncompressed textures (in raw/)...")
    for t in targets:
        generate_normal_and_height(t, "assets/textures/raw", strength=3.0)
        
    # Process low-res PS1 versions
    print("Generating maps for compressed textures (in assets/textures/)...")
    for t in targets:
        generate_normal_and_height(t, "assets/textures", strength=2.0)

if __name__ == "__main__":
    process_all_maps()
