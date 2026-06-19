package com.watabou.towngenerator.ui;

import openfl.display.Sprite;
import openfl.display.Shape;
import openfl.display.Graphics;
import openfl.events.MouseEvent;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.text.TextFieldAutoSize;
import openfl.geom.Point;
import openfl.events.Event;

import com.watabou.towngenerator.mapping.Palette;

class MapControls extends Sprite {

	private var controller:MapController;
	private var palette:Palette;

	private var zoomSlider:ZoomSlider;
	private var zoomLabel:TextField;

	private static inline var BUTTON_SIZE:Float = 28;
	private static inline var SLIDER_HEIGHT:Float = 100;
	private static inline var PADDING:Float = 8;

	public function new(controller:MapController, palette:Palette) {
		super();
		this.controller = controller;
		this.palette = palette;

		build();

		// Listen for zoom changes
		controller.onZoomChanged.add(updateZoomDisplay);
	}

	private function build():Void {
		var yPos:Float = 0;

		// Background panel
		var bg = new Shape();
		var bgWidth = BUTTON_SIZE + PADDING * 2;
		var bgHeight = BUTTON_SIZE * 3 + SLIDER_HEIGHT + PADDING * 3 + 20;
		bg.graphics.beginFill(palette.paper, 0.85);
		bg.graphics.lineStyle(1, palette.dark, 0.5);
		bg.graphics.drawRoundRect(0, 0, bgWidth, bgHeight, 8, 8);
		bg.graphics.endFill();
		addChild(bg);

		yPos = PADDING;

		// Zoom in button
		var zoomInBtn = new ControlButton("+", BUTTON_SIZE, function() {
			controller.zoomIn();
			updateZoomDisplay();
		}, palette);
		zoomInBtn.x = PADDING;
		zoomInBtn.y = yPos;
		addChild(zoomInBtn);
		yPos += BUTTON_SIZE + PADDING;

		// Zoom slider
		zoomSlider = new ZoomSlider(SLIDER_HEIGHT, function(value:Float) {
			controller.setZoom(value);
			updateZoomDisplay();
		}, palette);
		zoomSlider.x = PADDING + (BUTTON_SIZE - 16) / 2;
		zoomSlider.y = yPos;
		addChild(zoomSlider);
		yPos += SLIDER_HEIGHT + PADDING;

		// Zoom out button
		var zoomOutBtn = new ControlButton("-", BUTTON_SIZE, function() {
			controller.zoomOut();
			updateZoomDisplay();
		}, palette);
		zoomOutBtn.x = PADDING;
		zoomOutBtn.y = yPos;
		addChild(zoomOutBtn);
		yPos += BUTTON_SIZE + PADDING;

		// Reset/Fit button
		var fitBtn = new ControlButton("FIT", BUTTON_SIZE, function() {
			controller.resetView();
			updateZoomDisplay();
		}, palette, true);
		fitBtn.x = PADDING;
		fitBtn.y = yPos;
		addChild(fitBtn);
		yPos += BUTTON_SIZE + 4;

		// Zoom percentage label
		zoomLabel = new TextField();
		zoomLabel.defaultTextFormat = new TextFormat("_sans", 9, palette.dark);
		zoomLabel.autoSize = TextFieldAutoSize.CENTER;
		zoomLabel.selectable = false;
		zoomLabel.text = "100%";
		zoomLabel.x = PADDING;
		zoomLabel.y = yPos;
		zoomLabel.width = BUTTON_SIZE;
		addChild(zoomLabel);

		updateZoomDisplay();
	}

	private function updateZoomDisplay():Void {
		var zoom = controller.getZoomPercent();
		zoomLabel.text = Std.string(Math.round(zoom * 100)) + "%";
		zoomLabel.x = PADDING + (BUTTON_SIZE - zoomLabel.width) / 2;
		zoomSlider.setValue(zoom);
	}
}

// Simple control button
class ControlButton extends Sprite {

	private var callback:Void->Void;
	private var palette:Palette;
	private var size:Float;
	private var isWide:Bool;

	public function new(text:String, size:Float, onClick:Void->Void, pal:Palette, wide:Bool = false) {
		super();
		this.callback = onClick;
		this.palette = pal;
		this.size = size;
		this.isWide = wide;

		draw(false);

		var label = new TextField();
		label.defaultTextFormat = new TextFormat("_sans", wide ? 9 : 14, pal.paper, true);
		label.text = text;
		label.selectable = false;
		label.autoSize = TextFieldAutoSize.CENTER;
		label.x = (size - label.width) / 2;
		label.y = (size - label.height) / 2;
		addChild(label);

		buttonMode = true;
		addEventListener(MouseEvent.CLICK, onClicked);
		addEventListener(MouseEvent.MOUSE_OVER, onOver);
		addEventListener(MouseEvent.MOUSE_OUT, onOut);
	}

	private function draw(hover:Bool):Void {
		graphics.clear();
		var bgColor = hover ? palette.medium : palette.dark;
		graphics.beginFill(bgColor);
		graphics.drawRoundRect(0, 0, size, size, 4, 4);
		graphics.endFill();
	}

	private function onClicked(_):Void {
		if (callback != null) callback();
	}

	private function onOver(_):Void {
		draw(true);
	}

	private function onOut(_):Void {
		draw(false);
	}
}

// Vertical zoom slider
class ZoomSlider extends Sprite {

	private var sliderHeight:Float;
	private var callback:Float->Void;
	private var palette:Palette;

	private var thumb:Sprite;
	private var dragging:Bool = false;

	private static inline var TRACK_WIDTH:Float = 4;
	private static inline var THUMB_SIZE:Float = 16;

	// Zoom range (logarithmic)
	private var minZoom:Float = MapController.MIN_ZOOM;
	private var maxZoom:Float = MapController.MAX_ZOOM;

	public function new(height:Float, onChange:Float->Void, pal:Palette) {
		super();
		this.sliderHeight = height;
		this.callback = onChange;
		this.palette = pal;

		// Track
		graphics.beginFill(pal.light);
		graphics.drawRoundRect(6, 0, TRACK_WIDTH, height, 2, 2);
		graphics.endFill();

		// Thumb
		thumb = new Sprite();
		thumb.graphics.beginFill(pal.dark);
		thumb.graphics.drawRoundRect(-THUMB_SIZE/2, -THUMB_SIZE/2, THUMB_SIZE, THUMB_SIZE, 4, 4);
		thumb.graphics.endFill();
		thumb.x = 8;
		thumb.y = height / 2;
		thumb.buttonMode = true;
		addChild(thumb);

		thumb.addEventListener(MouseEvent.MOUSE_DOWN, onThumbDown);
		addEventListener(MouseEvent.CLICK, onTrackClick);
	}

	private function onThumbDown(e:MouseEvent):Void {
		e.stopPropagation();
		if (stage == null) return;
		dragging = true;
		stage.addEventListener(MouseEvent.MOUSE_MOVE, onDrag);
		stage.addEventListener(MouseEvent.MOUSE_UP, onMouseUp);
		stage.addEventListener(Event.MOUSE_LEAVE, onMouseLeave);
	}

	private function onDrag(e:MouseEvent):Void {
		if (!dragging) return;
		var localY = globalToLocal(new Point(e.stageX, e.stageY)).y;
		var ratio = Math.max(0, Math.min(1, localY / sliderHeight));
		thumb.y = ratio * sliderHeight;

		// Convert to zoom (inverted: top = zoom in, bottom = zoom out)
		var zoom = zoomFromRatio(1 - ratio);
		if (callback != null) callback(zoom);
	}

	private function onMouseUp(_:MouseEvent):Void {
		endDrag();
	}

	private function onMouseLeave(_:Event):Void {
		endDrag();
	}

	private function endDrag():Void {
		if (!dragging) return;
		dragging = false;
		if (stage != null) {
			stage.removeEventListener(MouseEvent.MOUSE_MOVE, onDrag);
			stage.removeEventListener(MouseEvent.MOUSE_UP, onMouseUp);
			stage.removeEventListener(Event.MOUSE_LEAVE, onMouseLeave);
		}
	}

	private function onTrackClick(e:MouseEvent):Void {
		if (dragging) return;
		var ratio = Math.max(0, Math.min(1, e.localY / sliderHeight));
		thumb.y = ratio * sliderHeight;

		var zoom = zoomFromRatio(1 - ratio);
		if (callback != null) callback(zoom);

		// Start dragging from new position
		if (stage != null) {
			dragging = true;
			stage.addEventListener(MouseEvent.MOUSE_MOVE, onDrag);
			stage.addEventListener(MouseEvent.MOUSE_UP, onMouseUp);
			stage.addEventListener(Event.MOUSE_LEAVE, onMouseLeave);
		}
	}

	// Convert ratio (0-1) to zoom level (logarithmic scale)
	private function zoomFromRatio(ratio:Float):Float {
		var logMin = Math.log(minZoom);
		var logMax = Math.log(maxZoom);
		return Math.exp(logMin + ratio * (logMax - logMin));
	}

	// Convert zoom level to ratio (0-1)
	private function ratioFromZoom(zoom:Float):Float {
		var logMin = Math.log(minZoom);
		var logMax = Math.log(maxZoom);
		var logZoom = Math.log(Math.max(minZoom, Math.min(maxZoom, zoom)));
		return (logZoom - logMin) / (logMax - logMin);
	}

	public function setValue(zoom:Float):Void {
		var ratio = ratioFromZoom(zoom);
		thumb.y = (1 - ratio) * sliderHeight;
	}
}
