# RUST HILL - Developer & Player Manual

## PART 1: PLAYER MANUAL

### **Overview**
**RUST HILL** is a psychological horror game designed to evoke the tension of early 90s found-footage and PS1 survival horror. You are trapped in a labyrinthine, abandoned archive known as "Rust Hill." Your goal is simple: Find the evidence, and find the way out.

But you are not alone.

### **Objectives**
1.  **Collect Pages:** Scoured throughout the maze are **5 Glowing Pages**. You must find all of them to unlock the exit.
2.  **Escape:** Once all pages are collected, locate the **Exit Door** (marked by a Red light that turns Green) to survive.
3.  **Survive:** Avoid "The Static Shift," an anomaly that stalks the halls.

### **Controls**
*   **WASD:** Move
*   **Mouse:** Look
*   **Left Click:** Interact / Grab Page
*   **Right Click (Hold):** Zoom (Mechanical Camera Zoom)
*   **F:** Toggle Flashlight
*   **TAB:** Toggle Minimap
*   **ESC:** Pause Menu (Options, Resume, Quit)

### **Survival Mechanics**
*   **The Handcam:** Your view is through a heavy, handheld camcorder. It has weight, sway, and glitchy autofocus.
*   **The Flashlight:**
    *   Battery life is limited.
    *   **Visual Cue:** The light will flicker intensely when battery is critical (< 20%).
    *   **Recharge:** Turn off the flashlight to slowly recharge the battery.
*   **The Map:**
    *   Press **TAB** to see a grid map of the areas you have explored.
    *   **Fog of War:** You only see walls and paths you have physically visited.
    *   **Markers:**
        *   **Green:** You
        *   **Magenta:** The Entity (It is always tracked... use this to survive).
        *   **Yellow:** Pages (Once discovered).
        *   **Red:** Locked Exit / **Green:** Unlocked Exit.
*   **The Entity ("The Static Shift"):**
    *   It does not simply chase you. It stalks.
    *   **Shadowing:** It prefers to watch from a distance.
    *   **Bluffing:** It may charge at you screaming, only to vanish at the last second. Do not panic.
    *   **Commitment:** If you are cornered, it will stop playing games.
    *   **Detection:** Your camera will suffer chromatic aberration and shake when it is near. Use your Zoom and Map to keep tabs on it.

---

## PART 2: DEVELOPER MANUAL

### **Technical Overview**
*   **Engine:** Godot 4.x
*   **Language:** GDScript
*   **Render Pipeline:** Compatibility (OpenGL) / Forward+ (Vulkan) target.
*   **Aesthetics:** PS1 styling via vertex jitter shaders, affine texture mapping emulation, and heavy post-processing (VHS, Dithering, Color Depth reduction).

### **Core Systems & Algorithms**

#### **1. Level Generation (`level_generator.gd`)**
*   **Algorithm:** **Recursive Division**.
    *   The map is a 12x12 grid.
    *   The algorithm recursively splits the space horizontally and vertically to create a nested structure of rooms and corridors, simulating an archive or basement.
*   **Braiding:**
    *   Post-generation, the script identifies "Dead Ends" (cells with 3 walls) and removes a random wall in ~20% of them. This creates loops, preventing the player from getting frustratingly cornered and allowing for "juking" gameplay.
*   **Navigation:**
    *   Uses `NavigationRegion3D` and `NavigationMesh`.
    *   **Critical:** The NavMesh is baked **asynchronously** at runtime using `PARSED_GEOMETRY_STATIC_COLLIDERS`. The game waits for the `bake_finished` signal before spawning AI to ensure valid pathfinding.

#### **2. Enemy AI (`enemy_ai.gd`)**
*   **Archetype:** "The Elastic Stalker" (FSM - Finite State Machine).
*   **States:**
    *   `SHADOWING`: Uses A* to pathfind to the player's general area but moves slowly (speed 3.0). Updates path infrequently to look "creepy."
    *   `BLUFF`: Triggered randomly or by timer. Enemy sprints (speed 7.0) at the player. Upon getting within striking distance (3.0 units), it intentionally triggers a "Miss/Skid" animation and stops, entering a temporary cooldown.
    *   `COMMIT`: Triggered if the player is cornered or after multiple bluffs. Relentless A* pursuit.
    *   `SEARCH`: If Line of Sight (Raycast) is broken, the enemy goes to the `last_known_position` and waits.
*   **Sensors:**
    *   **Vision:** RayCast3D from enemy eyes to player center. Updates `last_known_position` only on successful hit.
    *   **Audio Occlusion:** RayCast3D checks for walls between Enemy and Player. If blocked, a `LowPassFilter` on the "EnemyBus" is enabled (500Hz cutoff), muffling sounds.

#### **3. Player Controller (`player.gd`)**
*   **Physics:** Standard `CharacterBody3D`. Movement is relative to the camera's Y-rotation (head).
*   **Handcam Simulation:**
    *   **Inertia:** The camera rotation `lerp`s towards the raw mouse input, creating a "drag" effect.
    *   **Noise:** `FastNoiseLite` applies constant translational and rotational jitter (breathing/trembling).
    *   **Trauma:** Events (enemy proximity, jumpscares) add `trauma` (0.0-1.0), which exponentially increases the shake intensity.
    *   **Walk Cycle:** A Figure-8 bob pattern (`cos`/`-cos`) with Z-axis roll. Footstep audio is synced to the bob's lowest point (`cos > 0.9`).
    *   **Collision:** A `ShapeCast3D` detects walls in front of the camera and smoothly retracts the camera (`z` offset) to prevent clipping.

#### **4. UI & Systems (`ui_manager.gd`, `main.gd`)**
*   **Minimap:**
    *   A 12x12 grid of `ColorRect`s.
    *   **Fog of War:** Cells start Black. When the player enters a grid coordinate, it turns Grey.
    *   **Wall Rendering:** Each cell has 4 child ColorRects representing walls (N/S/E/W), toggled based on level data.
    *   **Enemy Tracking:** The enemy position is calculated from World Space -> Grid Space and drawn as Magenta on top of everything.
*   **Post-Processing:**
    *   **VHS Shader:** `shaders/vhs_glitch.gdshader`. Handles screen tearing and noise.
    *   **PSX Shader:** `shaders/psx_post.gdshader`. Handles color depth reduction, dithering, and resolution scaling.
    *   **Dynamic Aberration:** The Enemy AI drives the `aberration_amount` uniform on the PSX shader based on proximity.

### **Key File Structure**
*   `scripts/`
    *   `level_generator.gd`: map gen + nav baking.
    *   `enemy_ai.gd`: FSM logic + audio + visuals animation.
    *   `player.gd`: movement + handcam physics + interaction.
    *   `ui_manager.gd`: map drawing + HUD + menus.
    *   `main.gd`: game loop + global state (pages collected).
*   `shaders/`
    *   `enemy_skin.gdshader`: Vertex jitter + scrolling noise texture.
    *   `psx_post.gdshader`: Fullscreen retro effects.

### **Debug Tools**
*   **F3:** Toggle Debug Overlay (FPS, State, Position, Logs).
*   **Key 1:** Toggle Fullbright (Lighting).
*   **Key 2:** Toggle Enemy X-Ray (See through walls).
*   **Key 3:** Toggle Constant VHS Glitch.
