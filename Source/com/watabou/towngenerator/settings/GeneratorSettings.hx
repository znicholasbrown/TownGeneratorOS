package com.watabou.towngenerator.settings;

import msignal.Signal.Signal0;
import com.watabou.towngenerator.mapping.Palette;
import com.watabou.towngenerator.wards.*;
import com.watabou.towngenerator.settings.FeatureMode;

class WardWeight {
	public var wardClass:Class<Ward>;
	public var weight:Int;
	public var name:String;

	public function new(wardClass:Class<Ward>, weight:Int, name:String) {
		this.wardClass = wardClass;
		this.weight = weight;
		this.name = name;
	}
}

class GeneratorSettings {

	public static var instance:GeneratorSettings = new GeneratorSettings();

	// Signal fired when any setting changes
	public var onChange:Signal0 = new Signal0();

	// ===== GENERATION TAB =====

	// City size (number of patches/wards)
	public var size(default, set):Int = 15;
	public static inline var SIZE_MIN = 6;
	public static inline var SIZE_MAX = 40;

	// Random seed (-1 for random)
	public var seed:Int = -1;

	// Feature toggles
	public var plazaMode(default, set):FeatureMode = Chance;
	public var citadelMode(default, set):FeatureMode = Chance;
	public var wallsMode(default, set):FeatureMode = Chance;

	// ===== WARDS TAB =====

	// Ward distribution weights (0-10 scale for UI)
	public var wardWeights:Array<WardWeight>;

	// Preset name (null = custom)
	public var wardPreset(default, set):String = "balanced";

	// ===== DETAILS TAB - Streets =====

	public var mainStreetWidth(default, set):Float = 2.0;
	public var regularStreetWidth(default, set):Float = 1.0;
	public var alleyWidth(default, set):Float = 0.6;

	public static inline var STREET_WIDTH_MIN = 0.3;
	public static inline var STREET_WIDTH_MAX = 4.0;

	// ===== DETAILS TAB - Buildings =====

	// Global chaos multiplier (0.0 = more rigid, 1.0 = more organic)
	public var gridChaosMultiplier(default, set):Float = 1.0;

	// Global size variation multiplier
	public var sizeVariationMultiplier(default, set):Float = 1.0;

	// Global empty lot probability multiplier
	public var emptyLotMultiplier(default, set):Float = 1.0;

	// ===== DETAILS TAB - Advanced =====

	// Voronoi relaxation iterations
	public var voronoiRelaxation(default, set):Int = 3;
	public static inline var RELAXATION_MIN = 0;
	public static inline var RELAXATION_MAX = 10;

	// Junction merge distance
	public var junctionMergeDistance(default, set):Float = 8.0;
	public static inline var JUNCTION_DIST_MIN = 4.0;
	public static inline var JUNCTION_DIST_MAX = 16.0;

	// ===== STYLE TAB =====

	public var palette(default, set):Palette = Palette.DEFAULT;
	public var paletteName(default, set):String = "default";

	// Stroke widths
	public var normalStroke(default, set):Float = 0.300;
	public var thickStroke(default, set):Float = 1.800;
	public var thinStroke(default, set):Float = 0.150;

	// ===== Constructor =====

	public function new() {
		initWardWeights();
	}

	private function initWardWeights():Void {
		wardWeights = [
			new WardWeight(CraftsmenWard, 7, "Craftsmen"),
			new WardWeight(MerchantWard, 2, "Merchant"),
			new WardWeight(Slum, 3, "Slum"),
			new WardWeight(PatriciateWard, 2, "Patriciate"),
			new WardWeight(Market, 1, "Market"),
			new WardWeight(Cathedral, 1, "Cathedral"),
			new WardWeight(AdministrationWard, 1, "Administration"),
			new WardWeight(MilitaryWard, 1, "Military"),
			new WardWeight(Park, 1, "Park")
		];
	}

	// ===== Ward Presets =====

	public static var PRESETS:Map<String, Array<Int>> = [
		"balanced" => [7, 2, 3, 2, 1, 1, 1, 1, 1],
		"commercial" => [4, 5, 2, 2, 3, 1, 1, 0, 1],
		"military" => [5, 1, 2, 1, 1, 1, 2, 5, 0],
		"noble" => [3, 2, 1, 5, 1, 2, 2, 1, 3],
		"slums" => [8, 1, 6, 0, 1, 0, 0, 1, 0]
	];

	public function applyPreset(presetName:String):Void {
		if (PRESETS.exists(presetName)) {
			var weights = PRESETS.get(presetName);
			for (i in 0...wardWeights.length) {
				if (i < weights.length) {
					wardWeights[i].weight = weights[i];
				}
			}
			wardPreset = presetName;
			onChange.dispatch();
		}
	}

	// ===== Palette Helpers =====

	public static var PALETTES:Map<String, Palette> = [
		"default" => Palette.DEFAULT,
		"blueprint" => Palette.BLUEPRINT,
		"bw" => Palette.BW,
		"ink" => Palette.INK,
		"night" => Palette.NIGHT,
		"ancient" => Palette.ANCIENT,
		"colour" => Palette.COLOUR,
		"simple" => Palette.SIMPLE
	];

	public static var PALETTE_NAMES:Array<String> = [
		"default", "blueprint", "bw", "ink", "night", "ancient", "colour", "simple"
	];

	public static var PALETTE_LABELS:Map<String, String> = [
		"default" => "Parchment",
		"blueprint" => "Blueprint",
		"bw" => "Black & White",
		"ink" => "Ink",
		"night" => "Night",
		"ancient" => "Ancient",
		"colour" => "Colour",
		"simple" => "Simple"
	];

	public function setPaletteByName(name:String):Void {
		if (PALETTES.exists(name)) {
			palette = PALETTES.get(name);
			paletteName = name;
			onChange.dispatch();
		}
	}

	// ===== Build Ward Array for Model =====

	public function buildWardArray():Array<Class<Ward>> {
		var result:Array<Class<Ward>> = [];
		for (ww in wardWeights) {
			for (i in 0...ww.weight) {
				result.push(ww.wardClass);
			}
		}
		return result;
	}

	// ===== Property Setters (trigger onChange) =====

	function set_size(v:Int):Int {
		if (v < SIZE_MIN) v = SIZE_MIN;
		if (v > SIZE_MAX) v = SIZE_MAX;
		if (size != v) {
			size = v;
			onChange.dispatch();
		}
		return size;
	}

	function set_plazaMode(v:FeatureMode):FeatureMode {
		if (plazaMode != v) { plazaMode = v; onChange.dispatch(); }
		return plazaMode;
	}

	function set_citadelMode(v:FeatureMode):FeatureMode {
		if (citadelMode != v) { citadelMode = v; onChange.dispatch(); }
		return citadelMode;
	}

	function set_wallsMode(v:FeatureMode):FeatureMode {
		if (wallsMode != v) { wallsMode = v; onChange.dispatch(); }
		return wallsMode;
	}

	function set_wardPreset(v:String):String {
		wardPreset = v;
		return wardPreset;
	}

	function set_mainStreetWidth(v:Float):Float {
		if (mainStreetWidth != v) { mainStreetWidth = v; onChange.dispatch(); }
		return mainStreetWidth;
	}

	function set_regularStreetWidth(v:Float):Float {
		if (regularStreetWidth != v) { regularStreetWidth = v; onChange.dispatch(); }
		return regularStreetWidth;
	}

	function set_alleyWidth(v:Float):Float {
		if (alleyWidth != v) { alleyWidth = v; onChange.dispatch(); }
		return alleyWidth;
	}

	function set_gridChaosMultiplier(v:Float):Float {
		if (gridChaosMultiplier != v) { gridChaosMultiplier = v; onChange.dispatch(); }
		return gridChaosMultiplier;
	}

	function set_sizeVariationMultiplier(v:Float):Float {
		if (sizeVariationMultiplier != v) { sizeVariationMultiplier = v; onChange.dispatch(); }
		return sizeVariationMultiplier;
	}

	function set_emptyLotMultiplier(v:Float):Float {
		if (emptyLotMultiplier != v) { emptyLotMultiplier = v; onChange.dispatch(); }
		return emptyLotMultiplier;
	}

	function set_voronoiRelaxation(v:Int):Int {
		if (v < RELAXATION_MIN) v = RELAXATION_MIN;
		if (v > RELAXATION_MAX) v = RELAXATION_MAX;
		if (voronoiRelaxation != v) { voronoiRelaxation = v; onChange.dispatch(); }
		return voronoiRelaxation;
	}

	function set_junctionMergeDistance(v:Float):Float {
		if (v < JUNCTION_DIST_MIN) v = JUNCTION_DIST_MIN;
		if (v > JUNCTION_DIST_MAX) v = JUNCTION_DIST_MAX;
		if (junctionMergeDistance != v) { junctionMergeDistance = v; onChange.dispatch(); }
		return junctionMergeDistance;
	}

	function set_palette(v:Palette):Palette {
		if (palette != v) { palette = v; onChange.dispatch(); }
		return palette;
	}

	function set_paletteName(v:String):String {
		paletteName = v;
		return paletteName;
	}

	function set_normalStroke(v:Float):Float {
		if (normalStroke != v) { normalStroke = v; onChange.dispatch(); }
		return normalStroke;
	}

	function set_thickStroke(v:Float):Float {
		if (thickStroke != v) { thickStroke = v; onChange.dispatch(); }
		return thickStroke;
	}

	function set_thinStroke(v:Float):Float {
		if (thinStroke != v) { thinStroke = v; onChange.dispatch(); }
		return thinStroke;
	}

	// ===== Serialization for URL =====

	public function toUrlParams():String {
		var params:Array<String> = [];
		params.push('size=$size');
		if (seed > 0) params.push('seed=$seed');
		if (plazaMode != Chance) params.push('plaza=${plazaMode == Always ? "1" : "0"}');
		if (citadelMode != Chance) params.push('citadel=${citadelMode == Always ? "1" : "0"}');
		if (wallsMode != Chance) params.push('walls=${wallsMode == Always ? "1" : "0"}');
		if (paletteName != "default") params.push('palette=$paletteName');
		return params.join("&");
	}

	public function fromUrlParams(params:Map<String, String>):Void {
		if (params.exists("size")) {
			size = Std.parseInt(params.get("size"));
		}
		if (params.exists("seed")) {
			seed = Std.parseInt(params.get("seed"));
		}
		if (params.exists("plaza")) {
			plazaMode = params.get("plaza") == "1" ? Always : Never;
		}
		if (params.exists("citadel")) {
			citadelMode = params.get("citadel") == "1" ? Always : Never;
		}
		if (params.exists("walls")) {
			wallsMode = params.get("walls") == "1" ? Always : Never;
		}
		if (params.exists("palette")) {
			setPaletteByName(params.get("palette"));
		}
	}
}
