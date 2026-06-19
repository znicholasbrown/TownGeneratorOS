package com.watabou.towngenerator.mapping;

import openfl.display.Shape;
import openfl.display.CapsStyle;
import openfl.display.Graphics;
import openfl.display.Sprite;
import openfl.geom.Point;

import com.watabou.geom.Polygon;
import com.watabou.towngenerator.importing.ImportedCity;
import com.watabou.towngenerator.settings.GeneratorSettings;

using com.watabou.utils.GraphicsExtender;
using com.watabou.utils.PointExtender;

class ImportedCityMap extends Sprite {

	// Get palette from settings
	public static var palette(get, never):Palette;
	static function get_palette():Palette {
		return GeneratorSettings.instance.palette;
	}

	private var city:ImportedCity;
	private var brush:Brush;
	private var scale:Float;

	public function new(city:ImportedCity) {
		super();

		this.city = city;
		brush = new Brush(palette);

		// Calculate scale to fit city into reasonable viewport
		// Salem.json has building coords around -150 to 100 range
		scale = 1.0;

		render();
	}

	private function render():Void {
		// Clear any existing graphics
		graphics.clear();
		while (numChildren > 0) removeChildAt(0);

		// Layer 1: Water bodies (bottom)
		var waterLayer = new Shape();
		drawWater(waterLayer.graphics);
		addChild(waterLayer);

		// Layer 2: Rivers
		var riverLayer = new Shape();
		drawRivers(riverLayer.graphics);
		addChild(riverLayer);

		// Layer 3: Roads
		var roadLayer = new Shape();
		drawRoads(roadLayer.graphics);
		addChild(roadLayer);

		// Layer 4: Bridges (planks) over rivers
		var bridgeLayer = new Shape();
		drawBridges(bridgeLayer.graphics);
		addChild(bridgeLayer);

		// Layer 5: Fields (farms)
		var fieldLayer = new Shape();
		drawPolygons(fieldLayer.graphics, city.fields, palette.light, palette.dark, Brush.NORMAL_STROKE);
		addChild(fieldLayer);

		// Layer 6: Greens (parks)
		var greenLayer = new Shape();
		drawPolygonsFilled(greenLayer.graphics, city.greens, palette.medium);
		addChild(greenLayer);

		// Layer 7: Squares (plazas)
		var squareLayer = new Shape();
		drawPolygonsFilled(squareLayer.graphics, city.squares, palette.light);
		addChild(squareLayer);

		// Layer 8: Buildings
		var buildingLayer = new Shape();
		drawPolygons(buildingLayer.graphics, city.buildings, palette.light, palette.dark, Brush.NORMAL_STROKE);
		addChild(buildingLayer);

		// Layer 9: Prisms (special buildings)
		var prismLayer = new Shape();
		drawPolygons(prismLayer.graphics, city.prisms, palette.light, palette.dark, Brush.NORMAL_STROKE * 2);
		addChild(prismLayer);

		// Layer 10: Trees
		var treeLayer = new Shape();
		drawTrees(treeLayer.graphics);
		addChild(treeLayer);

		// Layer 11: Walls (top, behind towers)
		var wallLayer = new Shape();
		drawWalls(wallLayer.graphics);
		addChild(wallLayer);
	}

	private function drawWater(g:Graphics):Void {
		if (city.water.length == 0) return;

		brush.setColor(g, palette.water);
		for (poly in city.water) {
			g.drawPolygon(poly);
		}
	}

	private function drawRivers(g:Graphics):Void {
		for (river in city.rivers) {
			if (river.coords.length < 2) continue;

			var width = river.width * scale;
			g.lineStyle(width, palette.water, 1, false, null, CapsStyle.ROUND);
			drawPolyline(g, river.coords);
		}
	}

	private function drawRoads(g:Graphics):Void {
		for (road in city.roads) {
			if (road.coords.length < 2) continue;

			var width = road.width * scale;

			// Outer stroke (darker border)
			g.lineStyle(width + Brush.NORMAL_STROKE * 2, palette.medium, 1, false, null, CapsStyle.NONE);
			drawPolyline(g, road.coords);

			// Inner fill (paper color)
			g.lineStyle(width - Brush.NORMAL_STROKE * 2, palette.paper, 1, false, null, CapsStyle.NONE);
			drawPolyline(g, road.coords);
		}
	}

	private function drawBridges(g:Graphics):Void {
		for (plank in city.planks) {
			if (plank.coords.length < 2) continue;

			var width = plank.width * scale;

			// Draw bridge as thicker road segment
			g.lineStyle(width + Brush.NORMAL_STROKE * 4, palette.dark, 1, false, null, CapsStyle.SQUARE);
			drawPolyline(g, plank.coords);

			g.lineStyle(width, palette.light, 1, false, null, CapsStyle.SQUARE);
			drawPolyline(g, plank.coords);
		}
	}

	private function drawPolygons(g:Graphics, polygons:Array<Polygon>, fill:Int, stroke:Int, strokeWidth:Float):Void {
		// First pass: strokes
		brush.setStroke(g, stroke, strokeWidth);
		for (poly in polygons) {
			g.drawPolygon(poly);
		}

		// Second pass: fills
		brush.noStroke(g);
		brush.setFill(g, fill);
		for (poly in polygons) {
			g.drawPolygon(poly);
		}
	}

	private function drawPolygonsFilled(g:Graphics, polygons:Array<Polygon>, fill:Int):Void {
		brush.setColor(g, fill);
		for (poly in polygons) {
			g.drawPolygon(poly);
		}
	}

	private function drawTrees(g:Graphics):Void {
		if (city.trees.length == 0) return;

		var treeRadius = 1.5 * scale;
		brush.noStroke(g);
		g.beginFill(palette.medium);

		for (tree in city.trees) {
			g.drawCircle(tree.x, tree.y, treeRadius);
		}

		g.endFill();
	}

	private function drawWalls(g:Graphics):Void {
		for (wall in city.walls) {
			if (wall.coords.length < 2) continue;

			var width = wall.width * scale;

			// Wall outline
			g.lineStyle(width, palette.dark, 1, false, null, null);

			// Draw as polygon (closed shape)
			if (wall.coords.length > 2) {
				var poly = new Polygon(wall.coords);
				g.drawPolygon(poly);

				// Draw towers at corners
				for (p in wall.coords) {
					drawTower(g, p, width * 0.6);
				}
			} else {
				// Just a line segment
				drawPolyline(g, wall.coords);
			}
		}
	}

	private function drawTower(g:Graphics, p:Point, r:Float):Void {
		brush.noStroke(g);
		g.beginFill(palette.dark);
		g.drawCircle(p.x, p.y, r);
		g.endFill();
	}

	private function drawPolyline(g:Graphics, points:Array<Point>):Void {
		if (points.length < 2) return;

		g.moveTo(points[0].x, points[0].y);
		for (i in 1...points.length) {
			g.lineTo(points[i].x, points[i].y);
		}
	}

	public function getCenter():Point {
		return city.getCenter();
	}

	public function getWidth():Float {
		return city.getWidth();
	}

	public function getHeight():Float {
		return city.getHeight();
	}
}
