# Medieval Fantasy City Generator - Agent Guide

## Quick Reference

**Language:** Haxe | **Framework:** OpenFL/Lime | **Build:** `openfl build html5` or `openfl build neko`

**Entry Point:** `Source/com/watabou/towngenerator/Main.hx`

**Live Demo:** https://watabou.itch.io/medieval-fantasy-city-generator/

---

## What This Is

A procedural medieval city/town generator that creates randomized 2D city maps with walls, streets, wards (districts), and buildings. Uses Voronoi diagrams for organic ward layouts and A* pathfinding for street networks.

---

## Project Structure

```
Source/com/watabou/
├── towngenerator/           # Main application
│   ├── Main.hx              # Entry point, initializes Model + TownScene
│   ├── TownScene.hx         # UI scene with CityMap and size buttons
│   ├── StateManager.hx      # URL parameter handling (?size=X&seed=Y)
│   ├── building/
│   │   ├── Model.hx         # CORE: City generation algorithm
│   │   ├── Patch.hx         # City region/ward container
│   │   ├── Topology.hx      # Street graph/pathfinding
│   │   ├── CurtainWall.hx   # Walls and fortifications
│   │   └── Cutter.hx        # Polygon subdivision utilities
│   ├── wards/               # 13 ward types (see below)
│   ├── mapping/
│   │   ├── CityMap.hx       # Renders the city to display
│   │   ├── Palette.hx       # 8 color schemes
│   │   └── Brush.hx         # Stroke widths and drawing
│   └── ui/                  # Buttons, tooltips
├── coogee/                  # Minimal game framework (Scene, Game, BitmapText)
├── geom/                    # Geometry: Polygon, Voronoi, Graph, Spline
└── utils/                   # Random (seeded RNG), MathUtils, PerlinNoise
```

---

## Generation Pipeline (Model.hx)

```
Model.build()
  1. buildPatches()     → Voronoi diagram creates ward regions
  2. optimizeJunctions() → Merge close vertices (<8 units)
  3. buildWalls()       → 50% chance city walls, optional citadel
  4. buildStreets()     → A* pathfinding connects gates to plaza
  5. createWards()      → Assign ward types based on location scores
  6. buildGeometry()    → Generate buildings within each ward
```

**Key Parameters:**
- `nPatches` (6-40): Number of ward regions
- `seed`: Random seed for reproducibility (-1 = random)
- `plazaNeeded`, `citadelNeeded`, `wallsNeeded`: 50% chance each

---

## Ward System

**Base class:** `Ward.hx` with building generation methods

| Ward Type | Purpose | Key Trait |
|-----------|---------|-----------|
| `CraftsmenWard` | Artisan workshops | Most common (weighted heavily) |
| `MerchantWard` | Trading houses | Prefers city center |
| `Market` | Central plaza | Fountain/statue, always central |
| `MilitaryWard` | Barracks | Near walls/citadel, regular grid |
| `PatriciateWard` | Noble mansions | Large buildings, near parks |
| `AdministrationWard` | Government | Overlooks plaza |
| `Cathedral` | Temple | Ring or orthogonal layout |
| `Park` | Gardens | Radial sector layout |
| `Farm` | Rural | Single house, outside walls |
| `Slum` | Poor housing | City edges, chaotic |
| `GateWard` | Border garrison | At city gates |
| `Castle` | Citadel | Fortified, single per city |
| `CommonWard` | Generic | Fallback type |

**Ward Placement:** Each ward has static `rateLocation()` returning placement cost (lower = preferred location).

**Building Generation:** Wards use recursive polygon subdivision with chaos parameters:
- `gridChaos`: 0.0 (regular) to 1.0 (chaotic angles)
- `sizeChaos`: Building size variation
- `emptyProb`: Empty lot probability

---

## Extension Points

### Add a New Ward Type

```haxe
// Source/com/watabou/towngenerator/wards/MyWard.hx
class MyWard extends CommonWard {
  public function new(model:Model, patch:Patch) {
    super(model, patch,
      /* minSq */ 30,       // Min building area
      /* gridChaos */ 0.5,  // 0-1 regularity
      /* sizeChaos */ 0.5,  // 0-1 size variation
      /* emptyProb */ 0.1   // 0-1 empty lots
    );
  }

  static function rateLocation(model:Model, patch:Patch):Float {
    // Return cost score; lower = preferred location
    return patch.distanceToCenter;
  }

  override function getLabel():String return "My Ward";
}
```

Then add to `Model.WARDS` array to include in generation.

### Add a Color Palette

In `Palette.hx`, add new static instance:
```haxe
public static var MYTHEME = new Palette(
  0xPAPER,   // Background
  0xLIGHT,   // Light elements
  0xMEDIUM,  // Medium elements
  0xDARK     // Strokes/text
);
```

### Custom Building Layout

Override `createGeometry()` in your Ward class. Available methods:
- `createAlleys()` - Recursive chaotic subdivision
- `createOrthoBuilding()` - Grid-based rectangular
- `Cutter.radial()` - Circular sectors
- `Cutter.semiRadial()` - Partial radial
- `Cutter.ring()` - Concentric rings

---

## Key Classes Reference

| Class | Purpose |
|-------|---------|
| `Model` | Core generation orchestrator |
| `Patch` | Single ward region (polygon + metadata) |
| `Ward` | Base ward with building algorithms |
| `Topology` | Street network graph + A* |
| `CurtainWall` | Wall segments + towers + gates |
| `Voronoi` | Voronoi diagram generation |
| `Polygon` | Polygon ops (shrink, cut, buffer) |
| `Graph` | Generic graph with pathfinding |
| `Random` | Seeded LCG random number generator |
| `CityMap` | Renders Model to display |
| `Palette` | Color scheme definitions |

---

## Build & Run

**Dependencies:**
```bash
haxelib install openfl
haxelib install lime
haxelib install msignal
```

**Build targets:**
```bash
openfl build html5    # Web browser
openfl build neko     # Desktop (Neko VM)
openfl build windows  # Native Windows
openfl build mac      # Native macOS
openfl build linux    # Native Linux
```

**Run:**
```bash
openfl test html5     # Build and run in browser
openfl test neko      # Build and run desktop
```

**Configuration:** `project.xml` (window size, FPS, assets, dependencies)

---

## URL Parameters (HTML5)

- `?size=15` - Ward count (6-40)
- `?seed=123456` - Random seed for reproducibility
- Combined: `?size=20&seed=987654`

---

## Known Limitations

- No waterbodies/rivers (mentioned in README as missing)
- No UI for changing palettes (hardcoded)
- Source may lag behind live demo version

---

## Constants Reference

**Street Widths:** `MAIN_STREET=2.0`, `REGULAR_STREET=1.0`, `ALLEY=0.6`

**Stroke Widths:** `NORMAL=0.3`, `THICK=1.8`, `THIN=0.15`

**City Sizes:**
- Small Town: 6-10 patches
- Large Town: 10-15 patches
- Small City: 15-24 patches
- Large City: 24-40 patches
