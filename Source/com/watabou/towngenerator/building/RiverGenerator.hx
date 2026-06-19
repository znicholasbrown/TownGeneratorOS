package com.watabou.towngenerator.building;

import openfl.geom.Point;
import com.watabou.geom.Polygon;
import com.watabou.utils.Random;
import com.watabou.utils.PerlinNoise;
import com.watabou.towngenerator.settings.GeneratorSettings;

using com.watabou.utils.PointExtender;

class RiverGenerator {

	// Generate a river path through the city
	public static function generate(cityRadius:Float, center:Point):RiverData {
		var settings = GeneratorSettings.instance;
		var riverWidth = settings.riverWidth;

		// Pick entry and exit points on opposite sides of the city
		var startAngle = Random.float() * Math.PI * 2;
		// Exit roughly opposite, with some variation
		var endAngle = startAngle + Math.PI + (Random.float() - 0.5) * 0.6;

		var margin = cityRadius * 1.5;
		var startPoint = new Point(
			center.x + Math.cos(startAngle) * margin,
			center.y + Math.sin(startAngle) * margin
		);
		var endPoint = new Point(
			center.x + Math.cos(endAngle) * margin,
			center.y + Math.sin(endAngle) * margin
		);

		// Generate meandering path
		var path = generateMeanderingPath(startPoint, endPoint, cityRadius);

		// Create river polygon from path (with width)
		var riverPolygon = createRiverPolygon(path, riverWidth);

		return {
			path: path,
			polygon: riverPolygon,
			width: riverWidth
		};
	}

	// Generate a meandering path between two points
	private static function generateMeanderingPath(start:Point, end:Point, cityRadius:Float):Polygon {
		var path = new Polygon();
		var segments = 20; // Number of segments in the river

		// Direction vector
		var dx = end.x - start.x;
		var dy = end.y - start.y;
		var length = Math.sqrt(dx * dx + dy * dy);

		// Perpendicular direction for meandering
		var perpX = -dy / length;
		var perpY = dx / length;

		// Meandering amplitude based on city size
		var amplitude = cityRadius * 0.3;

		// Use Perlin-like noise for smooth meandering
		var noiseOffset = Random.float() * 100;

		path.push(start);

		for (i in 1...segments) {
			var t = i / segments;

			// Base position along the line
			var baseX = start.x + dx * t;
			var baseY = start.y + dy * t;

			// Add meandering offset using sin with noise
			var noise = Math.sin(t * Math.PI * 3 + noiseOffset) *
			            Math.sin(t * Math.PI * 1.7 + noiseOffset * 0.5);
			var offset = noise * amplitude * Math.sin(t * Math.PI); // Fade at ends

			var pointX = baseX + perpX * offset;
			var pointY = baseY + perpY * offset;

			path.push(new Point(pointX, pointY));
		}

		path.push(end);

		return path;
	}

	// Create a polygon representing the river with width
	private static function createRiverPolygon(path:Polygon, width:Float):Polygon {
		var polygon = new Polygon();
		var halfWidth = width / 2;

		// Create offset points on both sides
		var leftSide:Array<Point> = [];
		var rightSide:Array<Point> = [];

		for (i in 0...path.length) {
			var current = path[i];
			var prev = i > 0 ? path[i - 1] : current;
			var next = i < path.length - 1 ? path[i + 1] : current;

			// Calculate tangent direction
			var dx = next.x - prev.x;
			var dy = next.y - prev.y;
			var len = Math.sqrt(dx * dx + dy * dy);
			if (len == 0) len = 1;

			// Perpendicular (normal) direction
			var nx = -dy / len;
			var ny = dx / len;

			// Vary width slightly for natural look
			var localWidth = halfWidth * (0.8 + Random.float() * 0.4);

			leftSide.push(new Point(current.x + nx * localWidth, current.y + ny * localWidth));
			rightSide.push(new Point(current.x - nx * localWidth, current.y - ny * localWidth));
		}

		// Build polygon: left side forward, right side backward
		for (p in leftSide) {
			polygon.push(p);
		}
		rightSide.reverse();
		for (p in rightSide) {
			polygon.push(p);
		}

		return polygon;
	}
}

typedef RiverData = {
	path:Polygon,      // Center line of river
	polygon:Polygon,   // Full polygon with width
	width:Float
};
