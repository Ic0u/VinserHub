# Vinser Hub

A modular, high-performance Roblox script suite powered by the **Linoria UI Library** (featuring built-in `ThemeManager` and `SaveManager`).

Window Title format:
```text
Vinser Hub (Pottasium - version-a2fb906f52d742d233c1) builderman123 / zlive
```

---

## ⚡ Features & Modules

- **UI Framework**: LinoriaLib (Window-based layout with Left/Right groupboxes, tabboxes, keybinds, color pickers, and watermark).
- **Theme & Save Managers**: Full theme customizer, color pickers, and JSON-based config save/autoloading.
- **Combat & Aimbot**:
  - Silent Aim (Players & NPCs) with velocity prediction.
  - FOV circle (Radius, rainbow chroma, custom color, center/mouse modes).
  - Hardware 3D Beams & 2D Line Tracers.
  - Skill Blacklist filter (Melee, Sword, Fruit, Gun).
- **PvP & Tech**:
  - Fast Attack (High-speed M1 burst).
  - Auto Buso Haki (Armament), Auto Race V3, and Auto Race V4 Awakening.
  - Camlock camera targeting with smoothness & keypicker.
  - Dragon Gun M1 rapid shot & Sanguine Boost impulse dash.
  - Optional mobile draggable floating widgets.
- **Movement & Agility**:
  - Custom WalkSpeed & Dash distance.
  - Super Jump force impulse & Infinite Air Jump.
  - Free Flight gliding with speed controls.
  - Noclip wallpass, Walk on Water, and Anti-Lava immunity.
- **Visuals (ESP)**:
  - 2D Bounding Boxes & Overhead Billboards.
  - Player Names, Health bars, Stud Distance, Equipped Weapon, Devil Fruit, Bounty, Level, and PvP status.
  - Player Chams (Highlight silhouettes) & bottom screen tracers.
- **Soru (Flashstep)**:
  - Infinite Soru (Zero cooldown).
  - Soru Aimbot (Direct teleportation to target).
  - Auto Skill on Soru landing combo.
- **Smart Macro**:
  - 5 Slots with 6 Blocks each (Tap / Hold, weapon auto-equip, skill keys).
  - Loop execution and mobile floating widget button.
- **Misc & Optimization**:
  - FFlags 1 Performance Booster (120 FPS cap, smooth plastic textures, fog removal, debris culling).
  - Animation limiter (prevents character freeze & sideways glitches).
  - Server JobId copier, Rejoin Server, and Server Hop.

---

## 🚀 Loader

Run the following in any compatible Roblox executor (Synapse, Wave, Delta, Fluxus, Codex, Arceus X, etc.):

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Ic0u/VinserHub/main/main.lua"))()
```

---

## 📂 Repository Structure

```text
VinsersHub/
├── modules/
│   ├── combat/
│   │   ├── aimbot_core.lua      # Core targeting & math engine
│   │   ├── player_aimbot.lua    # Player silent aim hook
│   │   ├── npc_aimbot.lua       # Mob/boss silent aim hook
│   │   ├── fov.lua              # FOV drawing circle
│   │   ├── tracers.lua          # 3D Beam and 2D Line tracers
│   │   └── blacklist.lua        # Skill blacklist filter
│   ├── pvp/
│   │   ├── fast_attack.lua      # M1 Fast attack engine
│   │   ├── auto_combat.lua      # Auto Buso, V3, and V4 passives
│   │   ├── camlock.lua          # Camera lock targeting
│   │   ├── dragon_gun_m1.lua    # Rapid dragon gun shots
│   │   ├── sanguine_boost.lua   # Sanguine dash impulse
│   │   └── extra_widgets.lua    # Mobile draggable touch widgets
│   ├── mobility/
│   │   └── movement_engine.lua  # Flight, speed, super jump, water walk
│   ├── soru/
│   │   └── soru_controller.lua  # Flashstep cooldown bypass & aimbot
│   ├── esp/
│   │   └── esp_pvp.lua          # Visual boxes, chams, and telemetry
│   ├── macro/
│   │   └── macro_engine.lua     # Smart combo automation suite
│   └── misc/
│       └── client_tweaks.lua    # FFlags & rendering optimization
├── main.lua                     # Main script (Linoria UI & orchestration)
└── README.md
```
