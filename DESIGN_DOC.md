# Design Doc — Echo Index

## Concept
First-person horror set in a procedurally generated industrial maze. Collect pages to unlock the exit while avoiding the entity that stalks the halls. Generators restore lighting.

## Current State
- Single **Industrial** theme (concrete walls, metal grating floors, hanging lamps)
- Procedural maze via recursive division, 8×8 to 12×12 grid
- Navigation mesh baked asynchronously at runtime
- Player: WASD movement, mouse look, flashlight toggle (F), interact (E)
- Enemy AI: FSM with Shadowing/Bluff/Commit/Search states
- 3 generators to restart (crank hold), each lights nearby ceiling lamps
- 5 glowing pages to collect, exit door unlocks when all collected
- All materials use unshaded `StandardMaterial3D` (no PSX shaders)
- PSX aesthetic: low-poly geometry, nearest-neighbor textures, dark ambient

## Removed Systems
- Medical/Outdoor themes — industrial only
- PSX surface shader (`psx_surface.gdshader`) — removed for stability
- Touch controls, menu camera, battery system, camera zoom, VHS toggle
- Random ground props (crates, barrels, chairs, etc.)
- Verticality (raised/sunken cells, catwalks, stairs, ramps)
- Column decorations (cables, vines, warning stripes, pipe junctions, valves)
- Ambience emitters, power-ratio light flicker
- Cell Y variation, theme branching in all systems

## Planned (Top-Down Shooter Conversion)
- Camera: orthographic top-down view
- Controls: twin-stick or mouse aim + WASD move
- Weapons/ammo added, enemy AI reworked for line-of-sight
- Maze/wall system mostly reusable as-is
