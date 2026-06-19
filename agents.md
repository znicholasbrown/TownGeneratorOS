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
│   ├── TownScene.hx         # UI scene with CityMap and SettingsPanel
│   ├── StateManager.hx      # URL parameter handling (?size=X&seed=Y)
│   ├── building/
│   │   ├── Model.hx         # CORE: City generation algorithm
│   │   ├── Patch.hx         # City region/ward container
│   │   ├── Topology.hx      # Street graph/pathfinding
│   │   ├── CurtainWall.hx   # Walls and fortifications
│   │   └── Cutter.hx        # Polygon subdivision utilities
│   ├── wards/               # 13 ward types (see below)
│   ├── mapping/
│   │   ├── CityMap.hx           # Renders generated city
│   │   ├── ImportedCityMap.hx   # Renders imported JSON city
│   │   ├── Palette.hx           # 8 color schemes (with water color)
│   │   └── Brush.hx             # Stroke widths and drawing
│   ├── export/
│   │   └── CityExporter.hx      # Exports Model to JSON
│   ├── importing/
│   │   ├── CityImporter.hx      # Parses JSON to ImportedCity
│   │   └── ImportedCity.hx      # Data structure for imported cities
│   ├── settings/                # Configuration system
│   │   ├── GeneratorSettings.hx # Central settings with observables
│   │   └── FeatureMode.hx       # Feature toggle enum (Always/Never/Chance)
│   └── ui/                      # UI components
│       ├── SettingsPanel.hx     # Tabbed settings panel
│       ├── Button.hx            # Legacy button
│       └── Tooltip.hx           # Ward info tooltip
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

## Settings System (GeneratorSettings.hx)

Centralized configuration with observable properties. All settings trigger `onChange` signal when modified.

**Generation Settings:**
- `size` (6-40) - Number of city patches/wards
- `seed` - Random seed for reproducibility
- `plazaMode`, `citadelMode`, `wallsMode` - FeatureMode enum (Always/Never/Chance)

**Ward Distribution:**
- `wardWeights` - Array of WardWeight objects with per-type weights
- `wardPreset` - Named presets: "balanced", "commercial", "military", "noble", "slums"

**Street & Building:**
- `mainStreetWidth`, `regularStreetWidth`, `alleyWidth` - Configurable widths
- `gridChaosMultiplier`, `sizeVariationMultiplier`, `emptyLotMultiplier` - Building style

**Advanced:**
- `voronoiRelaxation` - Relaxation iterations (0-10)
- `junctionMergeDistance` - Vertex merge threshold (4-16)

**Visual:**
- `palette` - Active Palette instance
- `paletteName` - Palette identifier for UI
- `normalStroke`, `thickStroke`, `thinStroke` - Line widths

---

## UI System (SettingsPanel.hx)

Custom OpenFL-based tabbed settings panel on the right side of the screen.

**Tabs:**
1. **Gen** - City size slider, seed input, feature toggles (Plaza, Citadel, Walls), Generate button
2. **Wards** - Ward distribution presets
3. **Detail** - Street widths, building chaos/density sliders
4. **Style** - Palette picker grid

**UI Components (in SettingsPanel.hx):**
- `SimpleButton` - Click button with hover state
- `SimpleSlider` - Draggable value slider
- `SimpleToggle` - Checkbox toggle
- `SimpleInput` - Text input field
- `TabButton` - Tab navigation button
- `PaletteButton` - Color palette selector with swatch

---

## Import/Export System

### JSON Export Format

Exports to a GeoJSON-like FeatureCollection format compatible with the official MFCG version.

**Feature Types:**

| ID | Type | Description |
|----|------|-------------|
| `values` | Feature | Metadata (roadWidth, towerRadius, wallThickness, version) |
| `earth` | Polygon | Map boundary |
| `roads` | GeometryCollection | LineStrings with width property |
| `walls` | GeometryCollection | Polygons with width property |
| `rivers` | GeometryCollection | River paths (empty in generated cities) |
| `planks` | GeometryCollection | Bridges (empty in generated cities) |
| `buildings` | MultiPolygon | Regular buildings |
| `prisms` | MultiPolygon | Special buildings (Castle, Cathedral) |
| `squares` | MultiPolygon | Plazas (Market ward) |
| `greens` | MultiPolygon | Parks (Park ward) |
| `fields` | MultiPolygon | Farms (Farm ward) |
| `trees` | MultiPoint | Tree positions (empty in generated cities) |
| `districts` | GeometryCollection | Named ward polygons |
| `water` | MultiPolygon | Water bodies (empty in generated cities) |

### Import

Load any JSON file matching the export format. The `ImportedCityMap` renderer supports:
- Buildings, prisms, squares, greens, fields
- Roads with variable widths
- Walls with towers
- Water bodies
- Rivers
- Bridges (planks)
- Trees (rendered as small circles)

**Usage:**
1. Click "Import JSON" button in the Gen tab
2. Select a `.json` file
3. City is rendered immediately

### Export

Click "Export JSON" button to download the current city as `city_export.json`.

### Key Classes

| Class | Purpose |
|-------|---------|
| `CityExporter` | Converts Model to JSON string |
| `CityImporter` | Parses JSON to ImportedCity |
| `ImportedCity` | Lightweight city data structure |
| `ImportedCityMap` | Renders ImportedCity to display |

---

## Known Limitations

- Water bodies and rivers are not generated (but can be imported)
- Trees are not generated (but can be imported)
- Named districts use ward type labels, not unique names
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
