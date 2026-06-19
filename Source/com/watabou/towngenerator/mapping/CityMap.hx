package com.watabou.towngenerator.mapping;

import openfl.display.Shape;
import openfl.display.CapsStyle;
import openfl.display.Graphics;
import openfl.display.Sprite;
import openfl.geom.Point;

import com.watabou.geom.Polygon;

import com.watabou.towngenerator.wards.*;
import com.watabou.towngenerator.building.CurtainWall;
import com.watabou.towngenerator.building.Model;
import com.watabou.towngenerator.settings.GeneratorSettings;

using com.watabou.utils.ArrayExtender;
using com.watabou.utils.GraphicsExtender;
using com.watabou.utils.PointExtender;

class CityMap extends Sprite {

	// Get palette from settings
	public static var palette(get, never):Palette;
	static function get_palette():Palette {
		return GeneratorSettings.instance.palette;
	}

	// Store model reference for redraw
	private var model:Model;

	private var patches:Array<PatchView>;
	private var roadShapes:Array<Shape>;
	private var wallShape:Shape;
	private var riverShape:Shape;

	private var brush:Brush;

	public function new(model:Model) {
		super();
		this.model = model;
		build();
	}

	// Build/rebuild all visual elements
	private function build():Void {
		// Clear existing children
		while (numChildren > 0) {
			removeChildAt(0);
		}

		brush = new Brush(palette);

		// Draw rivers first (bottom layer)
		riverShape = new Shape();
		drawRivers(riverShape.graphics);
		addChild(riverShape);

		// Draw roads
		roadShapes = [];
		for (road in model.roads) {
			var roadView = new Shape();
			drawRoad(roadView.graphics, road);
			roadShapes.push(roadView);
			addChild(roadView);
		}

		// Draw patches
		patches = [];
		for (patch in model.patches) {
			var patchView = new PatchView(patch);
			drawPatch(patchView);
			patches.push(patchView);
		}

		// Add hot areas on top
		for (patch in patches)
			addChild(patch.hotArea);

		// Draw walls on top
		wallShape = new Shape();
		addChild(wallShape);

		if (model.wall != null)
			drawWall(wallShape.graphics, model.wall, false);

		if (model.citadel != null)
			drawWall(wallShape.graphics, cast(model.citadel.ward, Castle).wall, true);
	}

	// Draw a single patch
	private function drawPatch(patchView:PatchView):Void {
		var patch = patchView.patch;
		var patchDrawn = true;
		var g = patchView.graphics;

		g.clear();

		switch (Type.getClass(patch.ward)) {
			case Castle:
				drawBuilding(g, patch.ward.geometry, palette.light, palette.dark, Brush.NORMAL_STROKE * 2);
			case Cathedral:
				drawBuilding(g, patch.ward.geometry, palette.light, palette.dark, Brush.NORMAL_STROKE);
			case Market, CraftsmenWard, MerchantWard, GateWard, Slum, AdministrationWard, MilitaryWard, PatriciateWard, Farm:
				brush.setColor(g, palette.light, palette.dark);
				for (building in patch.ward.geometry)
					g.drawPolygon(building);
			case Park:
				brush.setColor(g, palette.medium);
				for (grove in patch.ward.geometry)
					g.drawPolygon(grove);
			default:
				patchDrawn = false;
		}

		if (patchDrawn && !contains(patchView))
			addChild(patchView);
	}

	// Redraw all elements with current palette/settings (no regeneration)
	public function redraw():Void {
		brush = new Brush(palette);

		// Redraw rivers
		riverShape.graphics.clear();
		drawRivers(riverShape.graphics);

		// Redraw roads
		for (i in 0...roadShapes.length) {
			roadShapes[i].graphics.clear();
			drawRoad(roadShapes[i].graphics, model.roads[i]);
		}

		// Redraw patches
		for (patchView in patches) {
			drawPatch(patchView);
		}

		// Redraw walls
		wallShape.graphics.clear();
		if (model.wall != null)
			drawWall(wallShape.graphics, model.wall, false);
		if (model.citadel != null)
			drawWall(wallShape.graphics, cast(model.citadel.ward, Castle).wall, true);
	}

	private function drawRoad( g:Graphics, road:Street ):Void {
		g.lineStyle( Ward.MAIN_STREET + Brush.NORMAL_STROKE, palette.medium, false, null, CapsStyle.NONE );
		g.drawPolyline( road );

		g.lineStyle( Ward.MAIN_STREET - Brush.NORMAL_STROKE, palette.paper );
		g.drawPolyline( road );
	}

	private function drawWall( g:Graphics, wall:CurtainWall, large:Bool ):Void {
		g.lineStyle( Brush.THICK_STROKE, palette.dark );
		g.drawPolygon( wall.shape );

		for (gate in wall.gates)
			drawGate( g, wall.shape, gate );

		for (t in wall.towers)
			drawTower( g, t, Brush.THICK_STROKE * (large ? 1.5 : 1) );
	}

	private function drawTower( g:Graphics, p:Point, r:Float ) {
		brush.noStroke( g );
		g.beginFill( palette.dark );
		g.drawCircle( p.x, p.y, r );
		g.endFill();
	}

	private function drawGate( g:Graphics, wall:Polygon, gate:Point ) {
		g.lineStyle( Brush.THICK_STROKE * 2, palette.dark, false, null, CapsStyle.NONE );

		var dir = wall.next( gate ).subtract( wall.prev( gate ) );
		dir.normalize( Brush.THICK_STROKE * 1.5 );
		g.moveToPoint( gate.subtract( dir ) );
		g.lineToPoint( gate.add( dir ) );
	}

	private function drawBuilding( g:Graphics, blocks:Array<Polygon>, fill:Int, line:Int, thickness:Float ):Void {
		brush.setStroke( g, line, thickness * 2 );
		for (block in blocks) {
			g.drawPolygon( block );
		}

		brush.noStroke( g );
		brush.setFill( g, fill );
		for (block in blocks) {
			g.drawPolygon( block );
		}
	}

	private function drawRivers(g:Graphics):Void {
		if (model.rivers == null || model.rivers.length == 0) return;

		for (river in model.rivers) {
			// Draw river fill
			g.beginFill(palette.water);
			g.drawPolygon(river.polygon);
			g.endFill();

			// Draw subtle outline
			g.lineStyle(Brush.THIN_STROKE, palette.medium, 0.5);
			g.drawPolygon(river.polygon);
		}
	}
}