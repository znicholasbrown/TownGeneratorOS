package com.watabou.towngenerator.export;

import haxe.Json;
import openfl.geom.Point;

import com.watabou.geom.Polygon;
import com.watabou.towngenerator.building.Model;
import com.watabou.towngenerator.building.Patch;
import com.watabou.towngenerator.mapping.Brush;
import com.watabou.towngenerator.wards.*;

class CityExporter {

	// Scale factor to match official export coordinates
	private static inline var SCALE:Float = 10.0;

	public static function toJSON(model:Model):String {
		var features:Array<Dynamic> = [];

		// 1. values - metadata
		features.push({
			type: "Feature",
			id: "values",
			roadWidth: Ward.MAIN_STREET * SCALE,
			towerRadius: Brush.THICK_STROKE * SCALE,
			wallThickness: Brush.THICK_STROKE * SCALE,
			generator: "mfcg-os",
			version: "1.0.0"
		});

		// 2. earth - convex hull boundary of all patches
		var earthCoords = buildEarthBoundary(model);
		features.push({
			type: "Polygon",
			id: "earth",
			coordinates: [earthCoords]
		});

		// 3. roads - arteries as LineStrings with width
		var roadGeometries:Array<Dynamic> = [];
		for (artery in model.arteries) {
			roadGeometries.push({
				type: "LineString",
				coordinates: polygonToCoords(artery),
				width: Ward.MAIN_STREET * SCALE
			});
		}
		features.push({
			type: "GeometryCollection",
			id: "roads",
			geometries: roadGeometries
		});

		// 4. walls - wall shapes as Polygons with width
		var wallGeometries:Array<Dynamic> = [];
		if (model.wall != null) {
			wallGeometries.push({
				type: "Polygon",
				coordinates: [polygonToCoords(model.wall.shape)],
				width: Brush.THICK_STROKE * SCALE
			});
		}
		if (model.citadel != null && model.citadel.ward != null) {
			var castle:Castle = cast model.citadel.ward;
			if (castle.wall != null) {
				wallGeometries.push({
					type: "Polygon",
					coordinates: [polygonToCoords(castle.wall.shape)],
					width: Brush.THICK_STROKE * SCALE * 1.5
				});
			}
		}
		features.push({
			type: "GeometryCollection",
			id: "walls",
			geometries: wallGeometries
		});

		// 5. rivers
		var riverGeometries:Array<Dynamic> = [];
		if (model.rivers != null) {
			for (river in model.rivers) {
				// Export river as a LineString (the path) with width
				riverGeometries.push({
					type: "LineString",
					coordinates: polygonToCoords(river.path),
					width: river.width * SCALE
				});
			}
		}
		features.push({
			type: "GeometryCollection",
			id: "rivers",
			geometries: riverGeometries
		});

		// 6. planks (bridges) - empty for now (not generated)
		features.push({
			type: "GeometryCollection",
			id: "planks",
			geometries: []
		});

		// Collect buildings by type (use Dynamic for flexible nested arrays)
		var buildings:Array<Dynamic> = [];
		var prisms:Array<Dynamic> = [];
		var squares:Array<Dynamic> = [];
		var greens:Array<Dynamic> = [];
		var fields:Array<Dynamic> = [];

		for (patch in model.patches) {
			if (patch.ward == null || patch.ward.geometry == null) continue;

			for (poly in patch.ward.geometry) {
				var coords = polygonToMultiCoords(poly);

				if (Std.isOfType(patch.ward, Market)) {
					squares.push(coords);
				} else if (Std.isOfType(patch.ward, Park)) {
					greens.push(coords);
				} else if (Std.isOfType(patch.ward, Farm)) {
					fields.push(coords);
				} else if (Std.isOfType(patch.ward, Castle) || Std.isOfType(patch.ward, Cathedral)) {
					prisms.push(coords);
				} else {
					buildings.push(coords);
				}
			}
		}

		// 7. buildings
		features.push({
			type: "MultiPolygon",
			id: "buildings",
			coordinates: buildings
		});

		// 8. prisms (special buildings)
		features.push({
			type: "MultiPolygon",
			id: "prisms",
			coordinates: prisms
		});

		// 9. squares (plazas)
		features.push({
			type: "MultiPolygon",
			id: "squares",
			coordinates: squares
		});

		// 10. greens (parks)
		features.push({
			type: "MultiPolygon",
			id: "greens",
			coordinates: greens
		});

		// 11. fields (farms)
		features.push({
			type: "MultiPolygon",
			id: "fields",
			coordinates: fields
		});

		// 12. trees - empty for now (not generated)
		features.push({
			type: "MultiPoint",
			id: "trees",
			coordinates: []
		});

		// 13. districts - patch shapes with ward labels
		var districtGeometries:Array<Dynamic> = [];
		for (patch in model.patches) {
			if (patch.ward == null) continue;
			var label = patch.ward.getLabel();
			if (label == null) label = "Ward";

			districtGeometries.push({
				type: "Polygon",
				name: label,
				coordinates: [polygonToCoords(patch.shape)]
			});
		}
		features.push({
			type: "GeometryCollection",
			id: "districts",
			geometries: districtGeometries
		});

		// 14. water - includes river polygons and any water patches
		var waterCoords:Array<Dynamic> = [];
		// Add river polygons as water bodies
		if (model.rivers != null) {
			for (river in model.rivers) {
				waterCoords.push(polygonToMultiCoords(river.polygon));
			}
		}
		// Add any water patches
		if (model.waterbody != null) {
			for (patch in model.waterbody) {
				waterCoords.push(polygonToMultiCoords(patch.shape));
			}
		}
		features.push({
			type: "MultiPolygon",
			id: "water",
			coordinates: waterCoords
		});

		return Json.stringify({
			type: "FeatureCollection",
			features: features
		});
	}

	private static function buildEarthBoundary(model:Model):Array<Array<Float>> {
		// Create convex hull of all patches scaled up
		var allPoints:Array<Point> = [];
		for (patch in model.patches) {
			for (v in patch.shape) {
				allPoints.push(v);
			}
		}

		// Simple bounding polygon - expand outward from center
		var minX = Math.POSITIVE_INFINITY;
		var maxX = Math.NEGATIVE_INFINITY;
		var minY = Math.POSITIVE_INFINITY;
		var maxY = Math.NEGATIVE_INFINITY;

		for (p in allPoints) {
			if (p.x < minX) minX = p.x;
			if (p.x > maxX) maxX = p.x;
			if (p.y < minY) minY = p.y;
			if (p.y > maxY) maxY = p.y;
		}

		// Expand by 50x for earth boundary (matches salem.json scale)
		var expandFactor = 50.0;
		var cx = (minX + maxX) / 2;
		var cy = (minY + maxY) / 2;
		var hw = (maxX - minX) / 2 * expandFactor;
		var hh = (maxY - minY) / 2 * expandFactor;

		// Create irregular boundary
		var earthPoints:Array<Array<Float>> = [];
		var numPoints = 20;
		for (i in 0...numPoints) {
			var angle = (i / numPoints) * Math.PI * 2;
			var r = 0.8 + Math.sin(angle * 3) * 0.2; // Irregular radius
			var x = cx + Math.cos(angle) * hw * r;
			var y = cy + Math.sin(angle) * hh * r;
			earthPoints.push([x * SCALE, y * SCALE]);
		}

		return earthPoints;
	}

	private static function polygonToCoords(poly:Polygon):Array<Array<Float>> {
		var coords:Array<Array<Float>> = [];
		for (v in poly) {
			coords.push([v.x * SCALE, v.y * SCALE]);
		}
		return coords;
	}

	private static function polygonToMultiCoords(poly:Polygon):Dynamic {
		// For MultiPolygon, each polygon is [[ring1], [ring2], ...]
		// Most buildings are simple polygons with one ring
		return [polygonToCoords(poly)];
	}

	private static function pointToCoord(p:Point):Array<Float> {
		return [p.x * SCALE, p.y * SCALE];
	}
}
