package com.watabou.towngenerator.importing;

import openfl.geom.Point;
import com.watabou.geom.Polygon;

typedef LineWithWidth = {
	var coords:Array<Point>;
	var width:Float;
}

typedef NamedPolygon = {
	var polygon:Polygon;
	var name:String;
}

typedef ImportMetadata = {
	var roadWidth:Float;
	var towerRadius:Float;
	var wallThickness:Float;
	var generator:String;
	var version:String;
}

class ImportedCity {

	// Metadata
	public var metadata:ImportMetadata;

	// Earth boundary (outer map limit)
	public var earth:Polygon;

	// Roads/Streets
	public var roads:Array<LineWithWidth>;

	// Walls
	public var walls:Array<LineWithWidth>;

	// Rivers
	public var rivers:Array<LineWithWidth>;

	// Bridges (planks)
	public var planks:Array<LineWithWidth>;

	// Buildings
	public var buildings:Array<Polygon>;

	// Special buildings (prisms - taller/important)
	public var prisms:Array<Polygon>;

	// Plazas/Markets
	public var squares:Array<Polygon>;

	// Parks/Gardens
	public var greens:Array<Polygon>;

	// Farm fields
	public var fields:Array<Polygon>;

	// Tree positions
	public var trees:Array<Point>;

	// Named districts
	public var districts:Array<NamedPolygon>;

	// Water bodies
	public var water:Array<Polygon>;

	// Computed bounds
	public var bounds:{minX:Float, maxX:Float, minY:Float, maxY:Float};

	public function new() {
		metadata = {
			roadWidth: 8.0,
			towerRadius: 7.6,
			wallThickness: 7.6,
			generator: "unknown",
			version: "0.0.0"
		};

		earth = new Polygon();
		roads = [];
		walls = [];
		rivers = [];
		planks = [];
		buildings = [];
		prisms = [];
		squares = [];
		greens = [];
		fields = [];
		trees = [];
		districts = [];
		water = [];
		bounds = {minX: 0, maxX: 0, minY: 0, maxY: 0};
	}

	public function computeBounds():Void {
		var minX = Math.POSITIVE_INFINITY;
		var maxX = Math.NEGATIVE_INFINITY;
		var minY = Math.POSITIVE_INFINITY;
		var maxY = Math.NEGATIVE_INFINITY;

		function updateBounds(p:Point) {
			if (p.x < minX) minX = p.x;
			if (p.x > maxX) maxX = p.x;
			if (p.y < minY) minY = p.y;
			if (p.y > maxY) maxY = p.y;
		}

		// Check buildings (most reliable for city bounds)
		for (building in buildings) {
			for (v in building) {
				updateBounds(v);
			}
		}

		// Also check prisms, squares, greens, fields
		for (poly in prisms) for (v in poly) updateBounds(v);
		for (poly in squares) for (v in poly) updateBounds(v);
		for (poly in greens) for (v in poly) updateBounds(v);
		for (poly in fields) for (v in poly) updateBounds(v);

		// Check roads
		for (road in roads) {
			for (p in road.coords) {
				updateBounds(p);
			}
		}

		// Check walls
		for (wall in walls) {
			for (p in wall.coords) {
				updateBounds(p);
			}
		}

		// Check districts
		for (district in districts) {
			for (v in district.polygon) {
				updateBounds(v);
			}
		}

		if (minX == Math.POSITIVE_INFINITY) {
			bounds = {minX: 0, maxX: 100, minY: 0, maxY: 100};
		} else {
			bounds = {minX: minX, maxX: maxX, minY: minY, maxY: maxY};
		}
	}

	public function getCenter():Point {
		return new Point(
			(bounds.minX + bounds.maxX) / 2,
			(bounds.minY + bounds.maxY) / 2
		);
	}

	public function getWidth():Float {
		return bounds.maxX - bounds.minX;
	}

	public function getHeight():Float {
		return bounds.maxY - bounds.minY;
	}
}
