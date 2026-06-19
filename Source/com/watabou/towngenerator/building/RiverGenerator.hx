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
	// The river follows the boundaries BETWEEN patches
	private static function extractEdgePath(model:Model, patchPath:Array<Patch>):Polygon {
		var path = new Polygon();

		if (patchPath.length < 2) return path;

		// Build path by following shared boundaries between consecutive patches
		// Key insight: use a consistent reference patch (the second one) for all vertex lookups
		// This ensures we're always working with the same Point objects

		for (i in 0...patchPath.length - 1) {
			var p1 = patchPath[i];
			var p2 = patchPath[i + 1];

			// Get shared vertices by finding vertices of p2 that are also in p1
			// We extract from p2 to maintain consistent references
			var sharedVerts = getSharedVerticesOrdered(p1, p2);

			if (sharedVerts.length == 0) continue;

			if (path.length == 0) {
				// First segment - add all shared vertices
				for (v in sharedVerts) {
					path.push(v);
				}
			} else {
				// Connect to existing path
				var lastPoint = path[path.length - 1];

				// Check if we need to reverse the shared vertices
				var distToFirst = Point.distance(lastPoint, sharedVerts[0]);
				var distToLast = Point.distance(lastPoint, sharedVerts[sharedVerts.length - 1]);

				// If the endpoints are very close (same point), just add in order
				// Otherwise, add in the direction that connects properly
				if (distToFirst < 0.01) {
					// Already connected at first vertex - add remaining
					for (j in 1...sharedVerts.length) {
						path.push(sharedVerts[j]);
					}
				} else if (distToLast < 0.01) {
					// Connected at last vertex - add in reverse, skip last
					var j = sharedVerts.length - 2;
					while (j >= 0) {
						path.push(sharedVerts[j]);
						j--;
					}
				} else {
					// Not directly connected - need to traverse p1's boundary
					// Find the connection point on p1
					var connectPath = findConnectionPath(p1.shape, lastPoint, sharedVerts[0], sharedVerts[sharedVerts.length - 1]);

					// Add connection path (skip first as it's already in path)
					for (j in 1...connectPath.path.length) {
						path.push(connectPath.path[j]);
					}

					// Add shared vertices in correct direction
					if (connectPath.connectsToFirst) {
						for (v in sharedVerts) {
							if (!pointNear(path[path.length - 1], v)) {
								path.push(v);
							}
						}
					} else {
						var j = sharedVerts.length - 1;
						while (j >= 0) {
							if (!pointNear(path[path.length - 1], sharedVerts[j])) {
								path.push(sharedVerts[j]);
							}
							j--;
						}
					}
				}
			}
		}

		return path;
	}

	// Get shared vertices between two patches, ordered as they appear in p2's shape
	private static function getSharedVerticesOrdered(p1:Patch, p2:Patch):Array<Point> {
		var shared:Array<Point> = [];
		var epsilon = 0.01;

		// Find vertices of p2 that are also in p1
		for (v2 in p2.shape) {
			for (v1 in p1.shape) {
				if (Point.distance(v1, v2) < epsilon) {
					shared.push(v2);  // Use p2's reference
					break;
				}
			}
		}

		if (shared.length < 2) return shared;

		// The shared vertices should be contiguous in p2's shape
		// Find the starting index and extract in order
		var startIdx = -1;
		for (i in 0...p2.shape.length) {
			if (isInArray(shared, p2.shape[i])) {
				startIdx = i;
				break;
			}
		}

		if (startIdx == -1) return shared;

		// Extract contiguous shared vertices starting from startIdx
		var ordered:Array<Point> = [];
		var n = p2.shape.length;
		var idx = startIdx;
		var count = 0;

		while (count < n) {
			var v = p2.shape[idx];
			if (isInArray(shared, v)) {
				ordered.push(v);
			} else if (ordered.length > 0) {
				// Hit a non-shared vertex after finding shared ones - stop
				break;
			}
			idx = (idx + 1) % n;
			count++;
		}

		return ordered;
	}

	private static function isInArray(arr:Array<Point>, p:Point):Bool {
		var epsilon = 0.01;
		for (v in arr) {
			if (Point.distance(v, p) < epsilon) return true;
		}
		return false;
	}

	private static function pointNear(a:Point, b:Point):Bool {
		return Point.distance(a, b) < 0.01;
	}

	// Find path along polygon boundary from 'from' to either 'to1' or 'to2', whichever is shorter
	private static function findConnectionPath(shape:Polygon, from:Point, to1:Point, to2:Point):{path:Array<Point>, connectsToFirst:Bool} {
		var path1 = getPathAlongBoundary(shape, from, to1);
		var path2 = getPathAlongBoundary(shape, from, to2);

		if (path1.length == 0 && path2.length == 0) {
			// Fallback - just use from point
			return {path: [from], connectsToFirst: Point.distance(from, to1) < Point.distance(from, to2)};
		} else if (path1.length == 0) {
			return {path: path2, connectsToFirst: false};
		} else if (path2.length == 0) {
			return {path: path1, connectsToFirst: true};
		} else if (path1.length <= path2.length) {
			return {path: path1, connectsToFirst: true};
		} else {
			return {path: path2, connectsToFirst: false};
		}
	}

	// Get the path along a polygon boundary from point a to point b (shortest direction)
	private static function getPathAlongBoundary(shape:Polygon, a:Point, b:Point):Array<Point> {
		// Find indices of a and b in the polygon
		// First try reference equality, then fall back to geometric proximity
		var idxA = findPointInPolygon(shape, a);
		var idxB = findPointInPolygon(shape, b);

		if (idxA == -1 || idxB == -1) {
			// Points not found, return empty path (will skip connection)
			return [];
		}

		if (idxA == idxB) {
			// Same point, no path needed
			return [shape[idxA]];
		}

		var n = shape.length;

		// Forward path (idxA to idxB going forward)
		var forward:Array<Point> = [];
		var idx = idxA;
		while (true) {
			forward.push(shape[idx]);
			if (idx == idxB) break;
			idx = (idx + 1) % n;
			if (forward.length > n) break; // Safety
		}

		// Backward path (idxA to idxB going backward)
		var backward:Array<Point> = [];
		idx = idxA;
		while (true) {
			backward.push(shape[idx]);
			if (idx == idxB) break;
			idx = (idx - 1 + n) % n;
			if (backward.length > n) break; // Safety
		}

		// Return shorter path
		return forward.length <= backward.length ? forward : backward;
	}

	// Find a point in a polygon, trying reference equality first, then geometric proximity
	private static function findPointInPolygon(shape:Polygon, target:Point):Int {
		// First try reference equality
		for (i in 0...shape.length) {
			if (shape[i] == target) return i;
		}

		// Fall back to geometric proximity (within small epsilon)
		var epsilon = 0.001;
		for (i in 0...shape.length) {
			if (Point.distance(shape[i], target) < epsilon) return i;
		}

		return -1;
	}

	// Check if polygon contains a point (by reference or proximity)
	private static function hasPoint(poly:Polygon, p:Point):Bool {
		var epsilon = 0.001;
		for (v in poly) {
			if (v == p || Point.distance(v, p) < epsilon) return true;
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

			polygon.push(new Point(curr.x + nx * halfWidth, curr.y + ny * halfWidth));
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

			polygon.push(new Point(curr.x - nx * halfWidth, curr.y - ny * halfWidth));
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
