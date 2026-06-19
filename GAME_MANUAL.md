# Echo Index — Developer & Player Manual

## Part 1: Player Manual

### Overview
You are trapped in a procedurally generated industrial maze. Collect 5 glowing pages to unlock the exit. Restart 3 generators to restore lighting. Avoid the entity that stalks the halls.

### Controls
- **WASD**: Move
- **Mouse**: Look
- **E**: Interact / Grab Page / Crank Generator (hold)
- **F**: Toggle Flashlight
- **ESC**: Pause Menu
- **Click**: Capture mouse

### Objectives
1. Restart all 3 generators to light the maze
2. Collect all 5 pages to unlock the exit
3. Reach the exit door to escape

### Survival
- Flashlight is your only light source in unpowered areas
- Restarting generators lights nearby ceiling lamps
- The entity stalks via FSM: shadows from a distance, bluff charges, commits when you're cornered
- Sprint (hold Shift) drains stamina but outruns the entity

---

## Part 2: Developer Manual

### Technical Overview
- **Engine**: Godot 4.x
- **Language**: GDScript
- **Render**: Forward+ / Mobile, unshaded materials
- **Aesthetics**: Low-poly geometry, nearest-neighbor filtering, dark ambient lighting

### Core Systems

#### Level Generation (`level_generator.gd`)
- Recursive division maze on an 8×8 to 12×12 grid
- Braiding removes ~20% of dead ends to prevent cornering
- Navigation mesh baked asynchronously at runtime
- Generators, pages, and exit placed at strategic locations

#### Enemy AI (`enemy_ai.gd`)
- FSM: Shadowing → Bluff → Commit → Search
- Vision via RayCast3D line-of-sight to player
- Audio occlusion: LowPassFilter on enemy bus when walls block LoS

#### Player Controller (`player.gd`)
- CharacterBody3D with camera-relative movement
- Handcam simulation: inertia, FastNoiseLite jitter, trauma system
- Head bob synced to footstep audio
- Flashlight with flicker effect

#### Generator System (`generator.gd`)
- Hold E to crank, progress decays when released
- Each generator scans nearby OmniLight3D nodes and toggles them on activate
- Green indicator when online, blinking yellow while cranking, red when off

### Key File Structure
- `scripts/level_generator.gd` — maze generation + geometry
- `scripts/enemy_ai.gd` — enemy FSM
- `scripts/player.gd` — movement + interaction
- `scripts/generator.gd` — generator logic + light control
- `scripts/ui_manager.gd` — HUD + menus + minimap
- `scripts/main.gd` — game loop + state management
- `scripts/utils/material_factory.gd` — unshaded material creation
- `scripts/utils/theme_manager.gd` — texture path management (industrial only)

### Debug Tools
- **F3**: Toggle Debug Overlay
