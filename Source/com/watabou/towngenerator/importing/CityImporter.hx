package com.watabou.towngenerator.importing;

import haxe.Json;
import openfl.geom.Point;
import com.watabou.geom.Polygon;

class CityImporter {

	public static function fromJSON(jsonStr:String):ImportedCity {
		var city = new ImportedCity();

		var data:Dynamic = Json.parse(jsonStr);
		if (data == null) return city;

		var features:Array<Dynamic> = data.features;
		if (features == null) return city;

		for (feature in features) {
			var id:String = feature.id;
			if (id == null) continue;

			switch (id) {
				case "values":
					parseValues(feature, city);
				case "earth":
					city.earth = parsePolygon(feature.coordinates);
				case "roads":
					parseRoads(feature, city);
				case "walls":
					parseWalls(feature, city);
				case "rivers":
					parseRivers(feature, city);
				case "planks":
					parsePlanks(feature, city);
				case "buildings":
					parseMultiPolygon(feature.coordinates, city.buildings);
				case "prisms":
					parseMultiPolygon(feature.coordinates, city.prisms);
				case "squares":
					parseMultiPolygon(feature.coordinates, city.squares);
				case "greens":
					parseMultiPolygon(feature.coordinates, city.greens);
				case "fields":
					parseMultiPolygon(feature.coordinates, city.fields);
				case "trees":
					parseTrees(feature, city);
				case "districts":
					parseDistricts(feature, city);
				case "water":
					parseMultiPolygon(feature.coordinates, city.water);
			}
		}

		city.computeBounds();
		return city;
	}

	private static function parseValues(feature:Dynamic, city:ImportedCity):Void {
		if (feature.roadWidth != null)
			city.metadata.roadWidth = feature.roadWidth;
		if (feature.towerRadius != null)
			city.metadata.towerRadius = feature.towerRadius;
		if (feature.wallThickness != null)
			city.metadata.wallThickness = feature.wallThickness;
		if (feature.generator != null)
			city.metadata.generator = feature.generator;
		if (feature.version != null)
			city.metadata.version = feature.version;
	}

	private static function parseRoads(feature:Dynamic, city:ImportedCity):Void {
		var geometries:Array<Dynamic> = feature.geometries;
		if (geometries == null) return;

		for (geom in geometries) {
			if (geom.type == "LineString") {
				var coords = parseLineString(geom.coordinates);
				var width:Float = geom.width != null ? geom.width : city.metadata.roadWidth;
				city.roads.push({coords: coords, width: width});
			}
		}
	}

	private static function parseWalls(feature:Dynamic, city:ImportedCity):Void {
		var geometries:Array<Dynamic> = feature.geometries;
		if (geometries == null) return;

		for (geom in geometries) {
			var coords:Array<Point> = [];
			var width:Float = geom.width != null ? geom.width : city.metadata.wallThickness;

			if (geom.type == "Polygon") {
				var rings:Array<Dynamic> = geom.coordinates;
				if (rings != null && rings.length > 0) {
					coords = parseLineString(rings[0]);
				}
			} else if (geom.type == "LineString") {
				coords = parseLineString(geom.coordinates);
			}

			if (coords.length > 0) {
				city.walls.push({coords: coords, width: width});
			}
		}
	}

	private static function parseRivers(feature:Dynamic, city:ImportedCity):Void {
		var geometries:Array<Dynamic> = feature.geometries;
		if (geometries == null) return;

		for (geom in geometries) {
			if (geom.type == "LineString") {
				var coords = parseLineString(geom.coordinates);
				var width:Float = geom.width != null ? geom.width : 10.0;
				city.rivers.push({coords: coords, width: width});
			}
		}
	}

	private static function parsePlanks(feature:Dynamic, city:ImportedCity):Void {
		var geometries:Array<Dynamic> = feature.geometries;
		if (geometries == null) return;

		for (geom in geometries) {
			if (geom.type == "LineString") {
				var coords = parseLineString(geom.coordinates);
				var width:Float = geom.width != null ? geom.width : 5.0;
				city.planks.push({coords: coords, width: width});
			}
		}
	}

	private static function parseMultiPolygon(coordinates:Dynamic, target:Array<Polygon>):Void {
		if (coordinates == null) return;

		var polys:Array<Dynamic> = coordinates;
		for (polyCoords in polys) {
			// MultiPolygon format: [ [ [ring1], [ring2], ... ] ]
			// We only use the outer ring (first ring)
			var rings:Array<Dynamic> = polyCoords;
			if (rings != null && rings.length > 0) {
				var poly = parsePolygon(rings);
				if (poly.length > 0) {
					target.push(poly);
				}
			}
		}
	}

	private static function parseTrees(feature:Dynamic, city:ImportedCity):Void {
		var coordinates:Array<Dynamic> = feature.coordinates;
		if (coordinates == null) return;

		for (coord in coordinates) {
			var arr:Array<Float> = coord;
			if (arr != null && arr.length >= 2) {
				city.trees.push(new Point(arr[0], arr[1]));
			}
		}
	}

	private static function parseDistricts(feature:Dynamic, city:ImportedCity):Void {
		var geometries:Array<Dynamic> = feature.geometries;
		if (geometries == null) return;

		for (geom in geometries) {
			if (geom.type == "Polygon") {
				var name:String = geom.name != null ? geom.name : "Unknown";
				var poly = parsePolygon(geom.coordinates);
				if (poly.length > 0) {
					city.districts.push({polygon: poly, name: name});
				}
			}
		}
	}

	private static function parsePolygon(coordinates:Dynamic):Polygon {
		if (coordinates == null) return new Polygon();

		var rings:Array<Dynamic> = coordinates;
		if (rings == null || rings.length == 0) return new Polygon();

		// Use first ring (outer boundary)
		return new Polygon(parseLineString(rings[0]));
	}

	private static function parseLineString(coordinates:Dynamic):Array<Point> {
		var points:Array<Point> = [];
		if (coordinates == null) return points;

		var coords:Array<Dynamic> = coordinates;
		for (coord in coords) {
			var arr:Array<Float> = coord;
			if (arr != null && arr.length >= 2) {
				points.push(new Point(arr[0], arr[1]));
			}
		}

		return points;
	}
}
