# HORROR GAME DESIGN DOC — Level, Visual & Audio Overhaul

## 1. TEXTURE PIPELINE

### How It Works
1. Generate image with AI at **256×256 or larger** using provided prompts
2. Save to `assets/textures/raw/<filename>`
3. Run `bash assets/textures/process_textures.sh`
4. ImageMagick downsizes to 64×64 or 128×128 → reduces palette to 8–32 colors → optionally Floyd-Steinberg dithers → scales back up to 256×256 → outputs to `assets/textures/`
5. The PSX shader uses `filter_nearest_mipmap, repeat_enable` so it stays crisp and pixelated — no bilinear blur

### Specs Per Texture Type
| Type | Target Size | Colors | Dithered |
|---|---|---|---|
| Wall / floor / ceiling | 128×128 | 24–32 | Yes |
| Props (crates, etc.) | 64×64 | 16 | Yes |
| Posters / decals | 128×128 | 8 | No |
| Blood / decals | 64×64 | 8 | No |

---

## 2. ARCHITECTURAL IMPROVEMENTS (All Tapes)

### 2.1 Room Variety — [✓ COMPLETED]
**Problem**: Every cell is 5×5×4. Zero architectural variation.

**Fixes**:
- **Wide corridors**: Merge adjacent cells into 10×5 or 5×10 runs by removing the shared wall AND the column at the junction — [✓]
- **Large chambers**: Select 3–4 cells during generation to become "merged rooms" — remove all internal walls between a 2×2 or 3×2 block of cells — [✓]
- **Narrow passages**: Some corridors get "clutter blocking" — props placed to narrow effective walkable width to 2–3 units — [✓]
- **Dead-end rooms**: A cell with 3 walls and no passage gets a prop set-piece (e.g., desk + chair + filing cabinet for industrial, hospital bed + curtain for medical) — [✓]

### 2.2 Verticality — [✓ COMPLETED]
**Problem**: Completely flat at y=0, no elevation change.

**Fixes**:
- **Raised platforms**: In 15% of cells, raise the floor mesh +0.5 to +1.0 units with a ramp mesh connecting to the corridor. The platform sits on box supports.
- **Sunken areas**: Similarly, sink 10% of cells by -0.5 units with steps down — [✓]
- **Catwalks (Industrial)**: Thin walkway meshes at y=2.0 spanning across a cell, with a ladder or ramp up
- **Stairs**: A simple stair mesh (stacked boxes) at strategic points connecting two elevation levels — only 1–2 per maze to keep them meaningful — [✓]

### 2.3 Landmarks — [✓ COMPLETED]
**Problem**: No recognizable locations, player navigates by minimap alone.

**Fixes**:
- **The Generator Room**: The cell containing the last generator gets a unique visual — extra props, different floor texture, a wall sign "SUBSTATION [X]"
- **The Page Shrine**: Page rooms get distinct lighting (a single bright hanging lamp that doesn't flicker) and a lit candle prop (small cylinder + tiny omni light)
- **Courtyard** (existing 2×2 carve): Place a central fountain/statue (stacked cylinders) or a dead tree, making it visually distinct from corridors
- **Color-coded zones**: Subtle floor tint variation per quadrant — slight blue in NW, red in NE, yellow in SW, green in SE — [✓]

### 2.4 Set-Pieces
**Problem**: No memorable focal points.

**Fixes**:
- **Industrial**: A massive broken pipe spraying steam particles (GPU particle emitter) + loud hiss audio — [✓] (animated sphere puff)
- **Medical**: An examination room with a bright overhead surgical light (spotlight) + blood pool floor decal + gurney — [✓]
- **Outdoor**: A broken-down vehicle (box mesh chassis + cylinder wheels) or a hanging body from a tree — [✓]

---

## 3. MATERIAL & TEXTURE IMPROVEMENTS

### 3.1 Wall Differentiation — [✓ COMPLETED]
**Fix**: Introduce 2 wall materials per theme — a primary wall texture and a secondary "accent" texture. Cells with wall_count ≤ 1 (open intersections) use accent. Corridor cells use primary.

### 3.2 Ambient Light Reduction — [✓ COMPLETED]
**Fix**:
- Reduce `ambient_light_energy` from **0.5 → 0.15**
- Change ambient color from `Color(0.35, 0.35, 0.35)` to `Color(0.1, 0.1, 0.12)` — very dim, slightly blue
- Force player to rely on flashlight and lamps for visibility
- Increase lamp `omni_range` from 7.0 → 9.0 to compensate

### 3.3 Surface Variation — [✓ COMPLETED]
**Fix**:
- **Grime zone near floor**: Spawn a thin horizontal quad at y=0.1 along walls with a dark grunge texture — [✓]
- **Water damage below pipes**: Small circular stained decals on walls below ceiling pipes — [✓]
- **Mold near base**: Green-tinted quads along the floor-wall seam — [✓]

---

## 4. PROP & DECORATION EXPANSION

### 4.1 Prop Types — [✓ COMPLETED]
Replace single `box_mesh` with a per-theme prop table:

| Prop | Mesh | Theme | Placement Chance |
|---|---|---|---|
| Wooden crate | BoxMesh (brown) | Industrial | 10% |
| Metal barrel | CylinderMesh | Industrial | 8% |
| Office chair | Cylinder + Box | Industrial | 5% | [✓]
| Filing cabinet | BoxMesh (tall, thin) | Industrial | 5% |
| Cable bundle | CylinderMesh (curved, thin) | Industrial | 8% |
| Pallet | BoxMesh (flat, slatted) | Industrial | 6% |
| Hospital bed | BoxMesh base + Cylinder rails | Medical | 10% |
| IV stand | Cylinder thin + Box arm | Medical | 8% |
| Gurney | BoxMesh (flat) + Cylinder wheels | Medical | 6% | [✓]
| Body bag | CylinderMesh (horizontal, dark) | Medical | 5% |
| Cabinet | BoxMesh (tall, white) | Medical | 8% |
| Tree trunk | CylinderMesh (brown) | Outdoor | 12% |
| Tree foliage | SphereMesh (dark green) | Outdoor | 12% (paired with trunk) |
| Gravestone | BoxMesh (thin, grey, rotating) | Outdoor | 10% |
| Bush | SphereMesh (dark green, squashed) | Outdoor | 10% |
| Puddle | QuadMesh (dark, reflective) | Outdoor | 8% |
| Broken wall | BoxMesh (partial height) | Outdoor | 8% | [✓]

Each prop uses the `psx_surface.gdshader` with appropriate texture and `jitter_amount = 0.5` for low-poly snap.

### 4.2 Blood Improvements — [✓ COMPLETED]
**Current**: Only random wall quads.

**Fixes**:
- **Floor blood pools**: 8% chance per cell to place a blood quad on the floor (rotated horizontal) at a random rotation — [✓]
- **Drip streaks**: Vertical elongated quads from ceiling to floor, narrow with alpha fade — [✓]
- **Hand prints**: Small quad at eye height, near blood pools — [✓]

### 4.3 Ceiling Pipe Junctions — [✓ COMPLETED]
**Fix**: At column positions that coincide with pipes, spawn:
- A small sphere at pipe intersections (valve body) — [✓]
- A thin box protruding from the pipe (valve handle) — [✓] (Industrial only)

### 4.4 Column Decoration — [✓ COMPLETED]
**Fix**:
- **Warning stripes**: Yellow/black striped quad wrapped around column base (industrial) — [✓]
- **Cables**: Thin cylinder spiraling around column (industrial) — [✓]
- **Medical tape / wrap**: White bandage-like mesh on column (medical) — [✓]
- **Vines**: Green cylinder coils around column (outdoor) — [✓]
- **Posters**: 10% chance per column for a poster quad on one face — [✓]

---

## 5. LAYOUT / GAMEPLAY IMPROVEMENTS

### 5.1 Non-predictable Spawn & Exit — [✓ COMPLETED]
**Fix**:
- Spawn cell: Random from the 4 corners instead of always top-left
- Exit cell: Random cell on the opposite edge from spawn, minimum distance of 10 cells
- The exit still has the door model, but its position varies

### 5.2 Contextual Page/Generator Placement
**Fix**:
- Generators: Distribute evenly across quadrants (one per quadrant) instead of purely random. Guarantee at least 1 generator is in a dead-end room (forces exploration).
- Pages: Place pages in cells that require at least 1 turn off the main corridor from a generator location. This ensures the player backtracks through explored areas, creating opportunities for enemy encounters.

### 5.3 Meaningful Courtyards — [✓ COMPLETED]
**Fix**:
- Courtyards (2×2 openings) get a visual centerpiece: dead tree (outdoor), broken statue (industrial), ambulance gurney (medical) — [✓]
- Add a bench or debris ring around the centerpiece — [✓]
- Place a page or generator near a courtyard so it becomes a memorable navigation anchor — [✓]

---

## 6. ATMOSPHERE IMPROVEMENTS

### 6.1 Fog Variation — [✓ COMPLETED]
**Fix**:
- Per-theme fog color instead of always black:
  - Industrial: `Color(0.08, 0.08, 0.08)` — very dark grey
  - Medical: `Color(0.12, 0.12, 0.14)` — slightly blue-grey
  - Outdoor: `Color(0.05, 0.05, 0.1)` — dark night fog
- Increase fog density from 0.045 → 0.06 for shorter draw distance (more horror)

### 6.2 Ambient Sound Fix — [✓ COMPLETED]
**Current**: Uses enemy sound files as random ambient emitters → desensitizes player.

**Fix**:
- Remove enemy sound files from ambient emitter pool
- Replace with actual environmental sounds generated via ffmpeg:
  - Industrial: distant machinery hum, wind through pipes, water drip
  - Medical: HVAC drone, distant intercom static, water drip
  - Outdoor: wind, creaking wood, distant owl/crow
- Keep 8 emitters but use theme-appropriate sound pools

---

## 7. THE THREE TAPES (Level Themes)

All tapes use size 12×12 (hard/large).

### Tape 1 — INDUSTRIAL (Abandoned Facility)

| Aspect | Detail |
|---|---|
| **Wall texture** | `wall_concrete_dark.png` (new) — dark grey, grime, water stains |
| **Accent wall** | `wall_pipes.png` (new) — exposed rusty pipes |
| **Floor texture** | `floor_grate.png` (new) — metal grating |
| **Ceiling texture** | `ceiling_panel.png` (new) — stained concrete panels |
| **Props** | Crates, barrels, chairs, filing cabinets, cable bundles, pallets, warning posters |
| **Lighting** | Dangling lamps with warm yellow flicker (existing, kept) |
| **Footsteps** | Heavy boots on metal — low thud with slight reverb |
| **Ambience** | Low industrial drone, distant clanking, steam hiss |
| **Fog color** | `Color(0.08, 0.08, 0.08)` dark grey |
| **Special** | Steam vent particle effects in 2–3 cells |

### Tape 2 — MEDICAL (Hospital Wing)

| Aspect | Detail |
|---|---|
| **Wall texture** | `wall_tile_white.png` (new) — clean white tiles |
| **Accent wall** | `wall_tile_damaged.png` (new) — cracked, bloody, moldy tiles |
| **Floor texture** | `floor_tile_linoleum.png` (new) — off-white linoleum |
| **Ceiling texture** | `ceiling_tile_acoustic.png` (new) — acoustic panels with water stains |
| **Props** | Hospital beds, IV stands, gurneys, body bags, cabinets, medical posters |
| **Lighting** | Fluorescent-style lights (white/blue-white, buzz, no shade — flat quad on ceiling) |
| **Footsteps** | Shoes on linoleum — slight squeak, higher pitch |
| **Ambience** | HVAC drone, distant intercom static buzz, water drip |
| **Fog color** | `Color(0.12, 0.12, 0.14)` cool blue-grey |
| **Special** | One "operating room" set-piece with bright spotlight |

### Tape 3 — OUTDOOR (Ruins)

| Aspect | Detail |
|---|---|
| **Wall texture** | `wall_stone_ruins.png` (new) — weathered grey stone |
| **Accent wall** | Same as primary (no accent) |
| **Floor texture** | `ground_dirt.png` (new) — dry dirt with dead grass |
| **Ceiling** | **None** — open sky, replaced by gradient background quad |
| **Props** | Trees (trunk + foliage), gravestones, bushes, puddles, broken wall segments |
| **Lighting** | No hanging lamps — only moonlight from sky. Ambient is dimmer, shadows are sharper. |
| **Footsteps** | Dirt/gravel crunch — lower pitch, dry |
| **Ambience** | Wind, creaking branches, distant crow calls |
| **Fog color** | `Color(0.05, 0.05, 0.1)` dark blue night |
| **Special** | Sky gradient background (dark blue to black), no ceiling plane |

---

## 8. AI IMAGE PROMPTS

### Tape 1 — Industrial
| Filename | Prompt |
|---|---|
| `wall_concrete_dark.png` | *"close-up rough concrete wall texture, dark grey, industrial grime, subtle water stains, even lighting, photorealistic, 256x256 seamless tile"* |
| `floor_grate.png` | *"top-down view of metal grating floor, industrial steel grate, rust spots, dark grey, square grid pattern, 256x256 seamless tile"* |
| `ceiling_panel.png` | *"close-up concrete ceiling panel texture, water damage stains, mold spots, dirty grey, 256x256 seamless tile"* |
| `crate_wood.png` | *"close-up rough wood plank surface, brown weathered wood, grain visible, dirty, 256x256 seamless tile"* |
| `wall_pipes.png` | *"industrial wall with exposed rusty pipes running vertically, dark concrete background, 256x256 seamless tile"* |
| `poster_warning.png` | *"torn yellow warning poster on concrete wall, biohazard symbol, grimy, distressed edges, 256x256"* |

### Tape 2 — Medical
| Filename | Prompt |
|---|---|
| `wall_tile_white.png` | *"close-up white ceramic hospital wall tiles, clean, subtle grout lines, even lighting, 256x256 seamless tile"* |
| `wall_tile_damaged.png` | *"cracked and broken white hospital tiles, dark mold in grout, blood stains, decaying, 256x256 seamless tile"* |
| `floor_tile_linoleum.png` | *"top-down off-white hospital linoleum floor tile, slight wear pattern, subtle rectangular tiles, 256x256 seamless tile"* |
| `ceiling_tile_acoustic.png` | *"acoustic ceiling tile texture off-white, water stain rings, slight yellowing, square tile grid, 256x256 seamless"* |
| `poster_medical.png` | *"hospital informational poster on wall, red cross symbol, clinical text, slightly torn, 256x256"* |
| `floor_blood_pool.png` | *"top-down dark red blood pooling on white linoleum floor, splatter edges, 256x256"* |

### Tape 3 — Outdoor
| Filename | Prompt |
|---|---|
| `ground_dirt.png` | *"top-down dry cracked dirt ground texture, small rocks, dead brown grass patches, 256x256 seamless tile"* |
| `wall_stone_ruins.png` | *"weathered grey stone brick wall, moss growing in cracks, ruins texture, dark and moody, 256x256 seamless"* |
| `foliage_dark.png` | *"dense dark green bush foliage texture, no sky visible, shadowy leaves, 256x256 seamless tile"* |
| `gravel_path.png` | *"top-down small grey gravel stones texture, uneven, some dirt between stones, 256x256 seamless tile"* |

---

## 9. IMPLEMENTATION ORDER

### Phase 1: Core Infrastructure — [✓ ALL COMPLETED]
1. Update `process_textures.sh` with all new texture entries — [✓]
2. Add `LevelTheme` enum to `level_generator.gd` — [✓]
3. Add `set_theme()` to `audio_manager.gd` for footstep banks + ambience — [✓]
4. Refactor `main.gd` for theme-aware environment setup — [✓]
5. Add tape selection buttons to start screen in `ui_manager.gd` — [✓]

### Phase 2: Tape 1 — Industrial Overhaul
6. Generate new textures — [✓]
7. Replace/create assets with theme-switched material loading — [✓]
8. Add new props (barrels, chairs, filing cabinets, cable bundles, pallets) — [✓]
9. Generate new SFX (metal footsteps, ambience) — [✓]
10. Add raised platforms + catwalks — [✓]

### Phase 3: Tape 2 — Medical Facility
11. Generate textures — [✓]
12. Implement medical prop spawning (beds, gurneys, IV stands, body bags, cabinets) — [✓]
13. Fluorescent light variant (white, no shade, buzz timer) — [✓]
14. Generate medical SFX (squeaky footsteps, HVAC ambience, intercom static) — [✓]
15. Operating room set-piece — [✓]

### Phase 4: Tape 3 — Outdoor Ruins
16. Generate textures — [✓]
17. Remove ceiling plane, add sky gradient background — [✓]
18. Implement outdoor props (trees, gravestones, bushes, puddles) — [✓]
19. No hanging lamps — darker ambient, add ground lanterns — [✓]
20. Generate outdoor SFX (dirt footsteps, wind, crows) — [✓]

### Phase 5: General Polish
21. Fix non-predictable spawn/exit placement — [✓]
22. Add landmark system (generator rooms, page shrines, courtyard centerpieces) — [✓]
23. Reduce ambient light, tune fog density — [✓]
24. Add grime zones, water damage decals, column decorations — [✓]
25. Test all 3 tapes for gameplay flow — [✓]
