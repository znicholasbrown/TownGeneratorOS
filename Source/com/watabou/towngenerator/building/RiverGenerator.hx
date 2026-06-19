package com.watabou.towngenerator.building;

import openfl.geom.Point;
import com.watabou.geom.Polygon;
import com.watabou.utils.Random;
import com.watabou.towngenerator.settings.GeneratorSettings;

using com.watabou.utils.PointExtender;
using com.watabou.utils.ArrayExtender;

/**
 * River generator that walks along actual Voronoi edges.
 *
 * Algorithm:
 * 1. Build a graph of all Voronoi vertex connections from patch edges
 * 2. Identify boundary vertices (on the edge of the map)
 * 3. Start from a random boundary vertex
 * 4. Walk the graph by choosing connected vertices
 * 5. Stop when reaching another boundary vertex
 */
class RiverGenerator {

	// Generate a river by walking the Voronoi edge graph
	public static function generate(model:Model):RiverData {
		var settings = GeneratorSettings.instance;
		var riverWidth = settings.riverWidth;

		// Build edge graph from all patches
		var edgeGraph = buildEdgeGraph(model);
		if (edgeGraph.vertices.length < 3) return null;

		// Find boundary vertices (vertices on the edge of the map)
		var boundaryVerts = findBoundaryVertices(model, edgeGraph);
		if (boundaryVerts.length < 2) return null;

		// Pick a random starting boundary vertex
		var startIdx = Random.int(0, boundaryVerts.length);
		var startVert = boundaryVerts[startIdx];

		// Walk the graph to find a path to another boundary vertex
		var path = walkEdgeGraph(edgeGraph, startVert, boundaryVerts, model.center);
		if (path.length < 2) return null;

		return {
			path: path,
			polygon: new Polygon(),  // Not used anymore - we use stroke rendering
			width: riverWidth
		};
	}

	// Build a graph of vertex connections from all Voronoi edges
	private static function buildEdgeGraph(model:Model):EdgeGraph {
		var graph = new EdgeGraph();

		// Iterate over all patches and extract edges
		for (patch in model.patches) {
			var shape = patch.shape;
			var n = shape.length;

			for (i in 0...n) {
				var a = shape[i];
				var b = shape[(i + 1) % n];

				// Add vertices to graph
				var idxA = graph.addVertex(a);
				var idxB = graph.addVertex(b);

				// Add edge (bidirectional)
				graph.addEdge(idxA, idxB);
			}
		}

		return graph;
	}

	// Find vertices that lie on the boundary of the map (outer edges)
	private static function findBoundaryVertices(model:Model, graph:EdgeGraph):Array<Int> {
		var boundary:Array<Int> = [];

		// A vertex is on the boundary if it has fewer connections
		// OR if it lies on a patch that touches the outer boundary
		// We'll use a simpler heuristic: vertices that are far from center
		// and have degree <= 3 (typical for boundary vertices)

		// First, find the bounding box of all vertices
		var minX = Math.POSITIVE_INFINITY;
		var maxX = Math.NEGATIVE_INFINITY;
		var minY = Math.POSITIVE_INFINITY;
		var maxY = Math.NEGATIVE_INFINITY;

		for (v in graph.vertices) {
			minX = Math.min(minX, v.x);
			maxX = Math.max(maxX, v.x);
			minY = Math.min(minY, v.y);
			maxY = Math.max(maxY, v.y);
		}

		// Add some margin
		var marginX = (maxX - minX) * 0.05;
		var marginY = (maxY - minY) * 0.05;

		// Vertices near the edge of the bounding box are boundary vertices
		for (i in 0...graph.vertices.length) {
			var v = graph.vertices[i];
			if (v.x < minX + marginX || v.x > maxX - marginX ||
				v.y < minY + marginY || v.y > maxY - marginY) {
				boundary.push(i);
			}
		}

		return boundary;
	}

	// Walk the edge graph from start vertex to a different boundary vertex
	private static function walkEdgeGraph(graph:EdgeGraph, startIdx:Int, boundaryVerts:Array<Int>, center:Point):Polygon {
		var path = new Polygon();
		var visited = new Map<Int, Bool>();

		var currentIdx = startIdx;
		path.push(graph.vertices[currentIdx]);
		visited.set(currentIdx, true);

		// Direction preference: start by heading toward center, then maintain momentum
		var startVert = graph.vertices[startIdx];
		var currentDir = new Point(center.x - startVert.x, center.y - startVert.y);
		normalizePoint(currentDir);

		var maxSteps = graph.vertices.length * 2; // Safety limit
		var steps = 0;

		while (steps < maxSteps) {
			steps++;

			// Get neighbors of current vertex
			var neighbors = graph.getNeighbors(currentIdx);
			if (neighbors.length == 0) break;

			// Find unvisited neighbors
			var unvisited:Array<Int> = [];
			for (n in neighbors) {
				if (!visited.exists(n)) {
					unvisited.push(n);
				}
			}

			if (unvisited.length == 0) break;

			// Choose next vertex based on direction preference
			var nextIdx = chooseNextVertex(graph, currentIdx, unvisited, currentDir);

			// Check if we've reached another boundary vertex (and not the start)
			if (path.length >= 3 && boundaryVerts.contains(nextIdx) && nextIdx != startIdx) {
				path.push(graph.vertices[nextIdx]);
				break;
			}

			// Update direction for momentum
			var currVert = graph.vertices[currentIdx];
			var nextVert = graph.vertices[nextIdx];
			currentDir = new Point(nextVert.x - currVert.x, nextVert.y - currVert.y);
			normalizePoint(currentDir);

			// Move to next vertex
			path.push(nextVert);
			visited.set(nextIdx, true);
			currentIdx = nextIdx;
		}

		return path;
	}

	// Choose the next vertex based on direction preference
	// Prefers continuing in roughly the same direction (momentum)
	private static function chooseNextVertex(graph:EdgeGraph, currentIdx:Int, candidates:Array<Int>, preferredDir:Point):Int {
		if (candidates.length == 1) return candidates[0];

		var currVert = graph.vertices[currentIdx];
		var bestIdx = candidates[0];
		var bestScore = Math.NEGATIVE_INFINITY;

		for (candIdx in candidates) {
			var candVert = graph.vertices[candIdx];
			var dir = new Point(candVert.x - currVert.x, candVert.y - currVert.y);
			normalizePoint(dir);

			// Score based on alignment with preferred direction
			// Higher score = more aligned with current direction
			var dot = dir.x * preferredDir.x + dir.y * preferredDir.y;

			// Add some randomness to make rivers more natural
			var randomFactor = Random.float() * 0.5 - 0.25;
			var score = dot + randomFactor;

			if (score > bestScore) {
				bestScore = score;
				bestIdx = candIdx;
			}
		}

		return bestIdx;
	}

	private static function normalizePoint(p:Point):Void {
		var len = Math.sqrt(p.x * p.x + p.y * p.y);
		if (len > 0.001) {
			p.x /= len;
			p.y /= len;
		}
	}
}

// Graph structure for Voronoi edges
class EdgeGraph {
	public var vertices:Array<Point>;
	public var edges:Map<Int, Array<Int>>;  // Adjacency list

	private static inline var EPSILON:Float = 0.5;

	public function new() {
		vertices = [];
		edges = new Map<Int, Array<Int>>();
	}

	// Add a vertex, return its index (reuse existing if close enough)
	public function addVertex(p:Point):Int {
		// Check if vertex already exists (within epsilon)
		for (i in 0...vertices.length) {
			if (Point.distance(vertices[i], p) < EPSILON) {
				return i;
			}
		}
		// Add new vertex
		vertices.push(p);
		return vertices.length - 1;
	}

	// Add an edge between two vertices (bidirectional)
	public function addEdge(a:Int, b:Int):Void {
		if (a == b) return;

		if (!edges.exists(a)) {
			edges.set(a, []);
		}
		if (!edges.get(a).contains(b)) {
			edges.get(a).push(b);
		}

		if (!edges.exists(b)) {
			edges.set(b, []);
		}
		if (!edges.get(b).contains(a)) {
			edges.get(b).push(a);
		}
	}

	// Get neighbors of a vertex
	public function getNeighbors(idx:Int):Array<Int> {
		if (edges.exists(idx)) {
			return edges.get(idx);
		}
		return [];
	}
}

typedef RiverData = {
	path:Polygon,      // Center line of river (Voronoi edges)
	polygon:Polygon,   // Legacy - not used with stroke rendering
	width:Float
};
