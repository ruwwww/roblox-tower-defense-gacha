# Roblox Tower Defense × Gacha Game

A complete, production-ready **Tower Defense × Gacha** game built with **Rojo 7.7.1** and modern **Luau**.

## Features

- **Gacha Summon System**:
  - Rates: 3★ Common (70%), 4★ Rare (25%), 5★ Epic (4.5%), 6★ Legendary (0.5%).
  - Pity System: Guaranteed 5★+ within 10 pulls, Guaranteed 6★ within 50 pulls.
  - Multi-pull discount (10x Summon for 900 Gems).
- **Unit Roster**:
  - **3★ Common**: Silver Archer (Rapid single-target), Stone Thrower (Ground splash).
  - **4★ Rare**: Frost Sorceress (35% AoE slow), Iron Bombardier (Heavy mortar splash).
  - **5★ Epic**: Storm Shaman (Chain lightning to 4 targets), Phantom Sniper (High-range burst).
  - **6★ Legendary**: Solar Archon (Orbital laser beam + burn DoT), Chrono Overlord (50% time-warp aura).
- **Tower Defense Mechanics**:
  - Server-authoritative grid placement (4-stud snap, path collision checks).
  - Targeting modes: `First`, `Last`, `Strongest`, `Weakest`, `Closest`.
  - Upgrades up to Level 5 with dynamic stat multipliers.
  - Sell system with investment refund.
- **Wave System**:
  - Scripted waves 1–10 and procedural infinite scaling for wave 11+.
  - Diverse enemies: Goblin Scout, Shadow Sprinter, Armored Orc, Magma Golem, Dread Sovereign (Boss).
  - Intermission preparation timer with manual "Start Wave" skip.
- **Client & Visuals**:
  - Modern Luau HUD (Crystal HP, Wave status, Gold/Gems counters, 5-slot Hotbar).
  - 3D holographic placement preview with attack radius indicator.
  - Laser tracer beams, impact flashes, and floating damage numbers.
  - Interactive Tower Inspect & Upgrade Modal.
  - Full-screen Gacha Summon Banner and Animated Pull Reveal modal.

## Project Structure

```
src/
├── shared/
│   ├── Config.luau
│   ├── Network.luau
│   ├── Data/
│   │   ├── UnitData.luau
│   │   ├── EnemyData.luau
│   │   ├── BannerData.luau
│   │   └── WaveData.luau
│   └── Utils/
│       └── MathUtil.luau
├── server/
│   ├── init.server.luau
│   └── Services/
│       ├── MapService.luau
│       ├── GachaService.luau
│       ├── WaveService.luau
│       └── CombatService.luau
└── client/
    ├── init.client.luau
    └── Controllers/
        ├── UIController.luau
        ├── PlacementController.luau
        └── VisualsController.luau
```

## Running with Rojo

1. Start the Rojo sync server:
   ```bash
   rojo serve --address 0.0.0.0 --port 34872
   ```
2. Connect from Roblox Studio via the Rojo plugin at `http://<SERVER_IP>:34872`.
3. Press **Play (F5)** in Roblox Studio!
