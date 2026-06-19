import os
import random
import subprocess
import math

def write_bmp(filename, width, height, pixels):
    row_size = (width * 3 + 3) & ~3
    pixel_data_size = row_size * height
    file_size = 54 + pixel_data_size
    
    header = bytearray(54)
    header[0:2] = b'BM'
    header[2:6] = file_size.to_bytes(4, 'little')
    header[10:14] = (54).to_bytes(4, 'little')
    header[14:18] = (40).to_bytes(4, 'little')
    header[18:22] = width.to_bytes(4, 'little')
    header[22:26] = height.to_bytes(4, 'little')
    header[26:28] = (1).to_bytes(2, 'little')
    header[28:30] = (24).to_bytes(2, 'little')
    header[34:38] = pixel_data_size.to_bytes(4, 'little')
    
    with open(filename, 'wb') as f:
        f.write(header)
        for y in range(height - 1, -1, -1):
            row = bytearray()
            for x in range(width):
                r, g, b = pixels[y * width + x]
                row.append(int(max(0, min(255, b))))
                row.append(int(max(0, min(255, g))))
                row.append(int(max(0, min(255, r))))
            row.extend(b'\x00' * (row_size - len(row)))
            f.write(row)

# Helper generators
def clamp(v, low=0, high=255):
    return max(low, min(high, v))

def noise(val, amount):
    return val + random.randint(-amount, amount)

def generate_textures():
    os.makedirs("assets/textures/raw", exist_ok=True)
    random.seed(42) # Deterministic generation
    
    # 1. wall_concrete_dark
    pixels = []
    for y in range(256):
        for x in range(256):
            base = 45 + random.randint(-8, 8)
            # Water stains
            stain = math.sin(x * 0.05) * 8 * (1 if y > 120 else 0.5)
            val = clamp(base + stain)
            pixels.append((val, val, val))
    write_bmp("assets/textures/raw/wall_concrete_dark.bmp", 256, 256, pixels)
    
    # 2. floor_grate (Square metal grid)
    pixels = []
    for y in range(256):
        for x in range(256):
            # Check grid lines
            is_grid = (x % 32 < 4) or (y % 32 < 4)
            if is_grid:
                # Dark metal grid line
                pixels.append((20, 20, 20))
            else:
                # Metal surface with rust
                r = 60 + random.randint(-10, 10)
                g = 60 + random.randint(-10, 10)
                b = 60 + random.randint(-10, 10)
                # Rust spots
                if random.random() < 0.05:
                    r += 35
                    g += 12
                    b -= 15
                pixels.append((clamp(r), clamp(g), clamp(b)))
    write_bmp("assets/textures/raw/floor_grate.bmp", 256, 256, pixels)
    
    # 3. ceiling_panel
    pixels = []
    for y in range(256):
        for x in range(256):
            base = 80 + random.randint(-12, 12)
            # Border of panels
            is_border = (x < 3 or x > 252 or y < 3 or y > 252)
            if is_border:
                base = 40
            # Mold spots
            mold = 0
            if math.sin(x*0.1) * math.cos(y*0.1) > 0.6:
                mold = -20
            pixels.append((clamp(base + mold), clamp(base + mold * 0.7), clamp(base + mold)))
    write_bmp("assets/textures/raw/ceiling_panel.bmp", 256, 256, pixels)
    
    # 4. crate_wood
    pixels = []
    for y in range(256):
        for x in range(256):
            # Wood planks (vertical seams)
            is_seam = (x % 64 < 3)
            # Wood grain line
            grain = math.sin(y * 0.8) * 8
            if is_seam:
                r, g, b = 45, 30, 20
            else:
                # Brown wood base
                r = 125 + random.randint(-15, 15) + grain
                g = 85 + random.randint(-10, 10) + grain * 0.7
                b = 50 + random.randint(-8, 8)
            pixels.append((clamp(r), clamp(g), clamp(b)))
    write_bmp("assets/textures/raw/crate_wood.bmp", 256, 256, pixels)
    
    # 5. wall_pipes
    pixels = []
    for y in range(256):
        for x in range(256):
            # Base dark concrete
            c = 50 + random.randint(-8, 8)
            r, g, b = c, c, c
            # Draw vertical pipes at x = 70..85 and x = 180..195
            if (x >= 70 and x <= 85) or (x >= 180 and x <= 195):
                # Metal cylinders
                center = 77 if x < 120 else 187
                dist = abs(x - center)
                shade = 1.0 - (dist / 8.0) * 0.6
                r = clamp(110 * shade + 35) # Rusty pipe
                g = clamp(70 * shade + 10)
                b = clamp(40 * shade - 5)
            pixels.append((r, g, b))
    write_bmp("assets/textures/raw/wall_pipes.bmp", 256, 256, pixels)
    
    # 6. poster_warning
    pixels = []
    for y in range(256):
        for x in range(256):
            # Check borders
            if x < 10 or x > 246 or y < 10 or y > 246:
                # Distressed grey wall border
                pixels.append((70, 70, 70))
                continue
            # Yellow poster background
            r = 210 + random.randint(-15, 15)
            g = 180 + random.randint(-15, 15)
            b = 40 + random.randint(-10, 10)
            
            # Simple biohazard sign in the center (circle + spikes)
            dx, dy = x - 128, y - 128
            dist = math.sqrt(dx*dx + dy*dy)
            if dist > 20 and dist < 32 and (abs(dx) > 6 or abs(dy) > 6):
                r, g, b = 25, 25, 25 # black biohazard mark
            elif dist < 8:
                r, g, b = 25, 25, 25
            
            pixels.append((clamp(r), clamp(g), clamp(b)))
    write_bmp("assets/textures/raw/poster_warning.bmp", 256, 256, pixels)
    
    # 7. wall_tile_white
    pixels = []
    for y in range(256):
        for x in range(256):
            # Grout lines every 64 pixels
            is_grout = (x % 64 < 3) or (y % 64 < 3)
            if is_grout:
                pixels.append((140, 140, 140))
            else:
                # White ceramic shine/noise
                v = 220 + random.randint(-8, 8)
                pixels.append((v, v, v))
    write_bmp("assets/textures/raw/wall_tile_white.bmp", 256, 256, pixels)
    
    # 8. wall_tile_damaged
    pixels = []
    for y in range(256):
        for x in range(256):
            is_grout = (x % 64 < 3) or (y % 64 < 3)
            # Random cracks
            crack = (abs(math.sin(x * 0.15 + y * 0.1)) > 0.96) and (x > 40 and y > 40 and x < 210 and y < 210)
            
            if is_grout or crack:
                # Moldy grout/crack
                pixels.append((40, 35, 30))
            else:
                v = 200 + random.randint(-12, 12)
                r, g, b = v, v, v
                # Blood stains/decay
                if (x - 100)**2 + (y - 150)**2 < 1200:
                    r = clamp(r + 40)
                    g = clamp(g - 60)
                    b = clamp(b - 60)
                pixels.append((r, g, b))
    write_bmp("assets/textures/raw/wall_tile_damaged.bmp", 256, 256, pixels)
    
    # 9. floor_tile_linoleum
    pixels = []
    for y in range(256):
        for x in range(256):
            is_grout = (x % 128 < 4) or (y % 128 < 4)
            if is_grout:
                pixels.append((120, 115, 110))
            else:
                v = 205 + random.randint(-6, 6)
                # Beige linoleum
                pixels.append((v, clamp(v - 10), clamp(v - 20)))
    write_bmp("assets/textures/raw/floor_tile_linoleum.bmp", 256, 256, pixels)
    
    # 10. ceiling_tile_acoustic
    pixels = []
    for y in range(256):
        for x in range(256):
            is_grid = (x % 128 < 4) or (y % 128 < 4)
            if is_grid:
                pixels.append((100, 100, 100))
            else:
                # Noise pattern (acoustic texture)
                base = 180 + random.randint(-15, 15)
                # Stains
                dx, dy = x - 180, y - 80
                if dx*dx + dy*dy < 900:
                    base = clamp(base - 35) # Darker ring stain
                pixels.append((base, clamp(base - 10), clamp(base - 20)))
    write_bmp("assets/textures/raw/ceiling_tile_acoustic.bmp", 256, 256, pixels)
    
    # 11. poster_medical
    pixels = []
    for y in range(256):
        for x in range(256):
            if x < 10 or x > 246 or y < 10 or y > 246:
                pixels.append((80, 80, 80))
                continue
            # Off-white paper background
            r, g, b = 230, 225, 215
            # Draw red cross in center
            dx, dy = abs(x - 128), abs(y - 128)
            if (dx < 10 and dy < 35) or (dx < 35 and dy < 10):
                r, g, b = 180, 20, 20
            pixels.append((r, g, b))
    write_bmp("assets/textures/raw/poster_medical.bmp", 256, 256, pixels)
    
    # 12. floor_blood_pool
    pixels = []
    for y in range(256):
        for x in range(256):
            # Circle splatter shape with noise
            dx, dy = x - 128, y - 128
            dist = math.sqrt(dx*dx + dy*dy) + random.randint(-15, 15)
            if dist < 60:
                # Deep blood red
                pixels.append((120, 8, 8))
            else:
                # White/transparent base (magick handles transparent white in process_textures)
                pixels.append((255, 255, 255))
    write_bmp("assets/textures/raw/floor_blood_pool.bmp", 256, 256, pixels)
    
    # 13. ground_dirt
    pixels = []
    for y in range(256):
        for x in range(256):
            # Brown dirt base
            r = 90 + random.randint(-12, 12)
            g = 68 + random.randint(-8, 8)
            b = 45 + random.randint(-6, 6)
            # Grass patches (dark green)
            if (math.sin(x*0.08) * math.cos(y*0.08) > 0.4):
                r, g, b = 45, 60, 30
            pixels.append((clamp(r), clamp(g), clamp(b)))
    write_bmp("assets/textures/raw/ground_dirt.bmp", 256, 256, pixels)
    
    # 14. wall_stone_ruins
    pixels = []
    for y in range(256):
        for x in range(256):
            # Stone block pattern
            block_y = y // 48
            offset_x = 32 if block_y % 2 == 0 else 0
            is_seam = (y % 48 < 4) or ((x + offset_x) % 64 < 4)
            if is_seam:
                # Mossy mortar
                pixels.append((35, 45, 35))
            else:
                # Stone base
                v = 85 + random.randint(-12, 12)
                # Moss green tint
                g_add = 15 if (x % 32 < 12 and y % 32 < 12) else 0
                pixels.append((clamp(v - g_add), clamp(v + g_add), clamp(v - g_add)))
    write_bmp("assets/textures/raw/wall_stone_ruins.bmp", 256, 256, pixels)
    
    # 15. foliage_dark
    pixels = []
    for y in range(256):
        for x in range(256):
            # Dense leaf textures (shades of dark green/black)
            base = 35 + random.randint(-15, 15)
            r = clamp(base - 10)
            g = clamp(base + 20)
            b = clamp(base - 15)
            pixels.append((r, g, b))
    write_bmp("assets/textures/raw/foliage_dark.bmp", 256, 256, pixels)
    
    # 16. gravel_path
    pixels = []
    for y in range(256):
        for x in range(256):
            # Small stones (dots)
            stone = (x // 8 + y // 8) % 2 == 0
            v = 110 + random.randint(-20, 20) if stone else 75 + random.randint(-10, 10)
            pixels.append((v, v, v))
    write_bmp("assets/textures/raw/gravel_path.bmp", 256, 256, pixels)
    
    # Convert all .bmp to .png in raw/ directory
    for f in os.listdir("assets/textures/raw"):
        if f.endswith(".bmp"):
            bmp_path = os.path.join("assets/textures/raw", f)
            png_path = bmp_path[:-4] + ".png"
            print(f"Converting {bmp_path} to {png_path}...")
            subprocess.run(["magick", bmp_path, png_path], check=True)
            os.remove(bmp_path)

if __name__ == "__main__":
    generate_textures()
