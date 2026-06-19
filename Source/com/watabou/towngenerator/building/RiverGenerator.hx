package com.watabou.towngenerator.building;

import openfl.geom.Point;
import com.watabou.geom.Polygon;
import com.watabou.utils.Random;
import com.watabou.towngenerator.settings.GeneratorSettings;

using com.watabou.utils.PointExtender;
using com.watabou.utils.ArrayExtender;

class RiverGenerator {

	// Generate a river following Voronoi edges (patch boundaries)
	public static function generate(model:Model):RiverData {
		var settings = GeneratorSettings.instance;
		var riverWidth = settings.riverWidth;

		// Get boundary patches (not fully enclosed)
		var boundary = model.getBoundaryPatches();
		if (boundary.length < 2) return null;

		// Select entry and exit patches on roughly opposite sides
		var entryPatch = selectEntryPatch(boundary, model.center);
		if (entryPatch == null) return null;

		var exitPatch = selectExitPatch(boundary, entryPatch, model.center);
		if (exitPatch == null) return null;

		// Find path through patches using A*
		var patchPath = findPatchPath(model, entryPatch, exitPatch);
		if (patchPath.length < 2) return null;

		// Extract the Voronoi edge path from the patch sequence
		var edgePath = extractEdgePath(model, patchPath);
		if (edgePath.length < 2) return null;

		// Create river polygon with width
		var riverPolygon = createRiverPolygon(edgePath, riverWidth);

		return {
			path: edgePath,
			polygon: riverPolygon,
			width: riverWidth
		};
	}

	// Select an entry patch from boundary patches
	private static function selectEntryPatch(boundary:Array<Patch>, center:Point):Patch {
		if (boundary.length == 0) return null;

		// Pick a random angle for entry
		var entryAngle = Random.float() * Math.PI * 2;
		var entryDir = new Point(Math.cos(entryAngle), Math.sin(entryAngle));

		// Find the boundary patch closest to that direction
		var best:Patch = null;
		var bestScore = Math.NEGATIVE_INFINITY;

		for (patch in boundary) {
			var patchCenter = patch.shape.centroid;
			var toCenter = patchCenter.subtract(center);
			// Dot product to find patch most aligned with entry direction
			var score = toCenter.x * entryDir.x + toCenter.y * entryDir.y;
			if (score > bestScore) {
				bestScore = score;
				best = patch;
			}
		}

		return best;
	}

	// Select an exit patch roughly opposite to entry
	private static function selectExitPatch(boundary:Array<Patch>, entryPatch:Patch, center:Point):Patch {
		if (boundary.length < 2) return null;

		var entryCenter = entryPatch.shape.centroid;
		var entryDir = entryCenter.subtract(center);
		entryDir.normalize(1);

		// Look for patch roughly opposite (negative dot product)
		var best:Patch = null;
		var bestScore = Math.POSITIVE_INFINITY;

		for (patch in boundary) {
			if (patch == entryPatch) continue;

			var patchCenter = patch.shape.centroid;
			var toCenter = patchCenter.subtract(center);
			toCenter.normalize(1);

			// Dot product - more negative = more opposite
			var score = toCenter.x * entryDir.x + toCenter.y * entryDir.y;

			// Also factor in distance from entry (prefer farther patches)
			var dist = Point.distance(patchCenter, entryCenter);

			// Combined score: prefer opposite direction and far distance
			var combinedScore = score - dist * 0.01;

			if (combinedScore < bestScore) {
				bestScore = combinedScore;
				best = patch;
			}
		}

		return best;
	}

	// A* pathfinding on patch adjacency graph
	private static function findPatchPath(model:Model, start:Patch, end:Patch):Array<Patch> {
		// Build neighbor lookup
		var neighbors = new Map<Int, Array<Patch>>();
		var patchIndex = new Map<Int, Patch>();

		for (i in 0...model.patches.length) {
			var patch = model.patches[i];
			patchIndex.set(i, patch);
			neighbors.set(i, model.getNeighbours(patch));
		}

		// Find indices
		var startIdx = model.patches.indexOf(start);
		var endIdx = model.patches.indexOf(end);
		if (startIdx == -1 || endIdx == -1) return [];

		// A* data structures
		var openSet = [startIdx];
		var cameFrom = new Map<Int, Int>();
		var gScore = new Map<Int, Float>();
		var fScore = new Map<Int, Float>();

		gScore.set(startIdx, 0);
		fScore.set(startIdx, heuristic(start, end));

		while (openSet.length > 0) {
			// Find node in openSet with lowest fScore
			var current = openSet[0];
			var currentF = fScore.exists(current) ? fScore.get(current) : Math.POSITIVE_INFINITY;
			for (idx in openSet) {
				var f = fScore.exists(idx) ? fScore.get(idx) : Math.POSITIVE_INFINITY;
				if (f < currentF) {
					current = idx;
					currentF = f;
				}
			}

			if (current == endIdx) {
				return reconstructPath(model.patches, cameFrom, current);
			}

			openSet.remove(current);

			var currentPatch = model.patches[current];
			var neighborPatches = neighbors.get(current);
			if (neighborPatches == null) continue;

			for (neighbor in neighborPatches) {
				var neighborIdx = model.patches.indexOf(neighbor);
				if (neighborIdx == -1) continue;

				var edgeLen = model.getSharedEdgeLength(currentPatch, neighbor);
				var tentativeG = (gScore.exists(current) ? gScore.get(current) : Math.POSITIVE_INFINITY) + edgeLen;

				var neighborG = gScore.exists(neighborIdx) ? gScore.get(neighborIdx) : Math.POSITIVE_INFINITY;

				if (tentativeG < neighborG) {
					cameFrom.set(neighborIdx, current);
					gScore.set(neighborIdx, tentativeG);
					fScore.set(neighborIdx, tentativeG + heuristic(neighbor, end));

					if (!openSet.contains(neighborIdx)) {
						openSet.push(neighborIdx);
					}
				}
			}
		}

		return []; // No path found
	}

	private static function heuristic(a:Patch, b:Patch):Float {
		return Point.distance(a.shape.centroid, b.shape.centroid);
	}

	private static function reconstructPath(patches:Array<Patch>, cameFrom:Map<Int, Int>, current:Int):Array<Patch> {
		var path = [patches[current]];
		while (cameFrom.exists(current)) {
			current = cameFrom.get(current);
			path.unshift(patches[current]);
		}
		return path;
	}

	// Extract continuous edge path from patch sequence
	private static function extractEdgePath(model:Model, patchPath:Array<Patch>):Polygon {
		var path = new Polygon();

		for (i in 0...patchPath.length - 1) {
			var p1 = patchPath[i];
			var p2 = patchPath[i + 1];
			var sharedEdge = model.getSharedEdge(p1, p2);

			if (sharedEdge.length == 0) continue;

			// Add vertices in correct order (avoid backtracking)
			if (path.length == 0) {
				// First edge - add all vertices
				var j = 0;
				while (j < sharedEdge.length) {
					path.push(sharedEdge[j]);
					j++;
				}
			} else {
				// Connect to existing path - determine direction
				var lastPoint = path[path.length - 1];
				var firstNew = sharedEdge[0];
				var lastNew = sharedEdge[sharedEdge.length - 1];

				var distToFirst = Point.distance(lastPoint, firstNew);
				var distToLast = Point.distance(lastPoint, lastNew);

				if (distToFirst <= distToLast) {
					// Add in forward order
					for (v in sharedEdge) {
						if (!hasPoint(path, v)) {
							path.push(v);
						}
					}
				} else {
					// Add in reverse order
					var j = sharedEdge.length - 1;
					while (j >= 0) {
						var v = sharedEdge[j];
						if (!hasPoint(path, v)) {
							path.push(v);
						}
						j--;
					}
				}
			}
		}

		return path;
	}

	// Check if polygon contains a point (by reference)
	private static function hasPoint(poly:Polygon, p:Point):Bool {
		for (v in poly) {
			if (v == p) return true;
		}
		return false;
	}

	// Create river polygon from center path with width
	private static function createRiverPolygon(path:Polygon, width:Float):Polygon {
		var polygon = new Polygon();
		var halfWidth = width / 2;

		if (path.length < 2) return polygon;

		// Left side (forward direction)
		for (i in 0...path.length) {
			var curr = path[i];
			var prev = i > 0 ? path[i - 1] : curr;
			var next = i < path.length - 1 ? path[i + 1] : curr;

			// Calculate tangent direction
			var dx = next.x - prev.x;
			var dy = next.y - prev.y;
			var len = Math.sqrt(dx * dx + dy * dy);
			if (len == 0) len = 1;

			// Perpendicular (normal) direction - left side
			var nx = -dy / len;
			var ny = dx / len;

			// Slight width variation for natural look
			var localWidth = halfWidth * (0.9 + Random.float() * 0.2);

			polygon.push(new Point(curr.x + nx * localWidth, curr.y + ny * localWidth));
		}

		// Right side (reverse direction)
		var i = path.length - 1;
		while (i >= 0) {
			var curr = path[i];
			var prev = i > 0 ? path[i - 1] : curr;
			var next = i < path.length - 1 ? path[i + 1] : curr;

			var dx = next.x - prev.x;
			var dy = next.y - prev.y;
			var len = Math.sqrt(dx * dx + dy * dy);
			if (len == 0) len = 1;

			var nx = -dy / len;
			var ny = dx / len;

			var localWidth = halfWidth * (0.9 + Random.float() * 0.2);

			polygon.push(new Point(curr.x - nx * localWidth, curr.y - ny * localWidth));
			i--;
		}

		return polygon;
	}
}

typedef RiverData = {
	path:Polygon,      // Center line of river (Voronoi edges)
	polygon:Polygon,   // Full polygon with width
	width:Float
};
