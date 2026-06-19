package com.watabou.towngenerator.ui;

import openfl.display.Sprite;
import openfl.display.Shape;
import openfl.events.MouseEvent;
import openfl.events.KeyboardEvent;
import openfl.events.Event;
import openfl.geom.Point;
import openfl.ui.Keyboard;

import msignal.Signal.Signal0;

class MapController extends Sprite {

	// View state
	public var viewX:Float = 0;
	public var viewY:Float = 0;
	public var zoomLevel:Float = 1.0;

	// Zoom limits
	public static inline var MIN_ZOOM:Float = 0.1;
	public static inline var MAX_ZOOM:Float = 10.0;
	public static inline var ZOOM_STEP:Float = 0.1;

	// Pan speed for keyboard
	private static inline var PAN_SPEED:Float = 20.0;

	// The map sprite to control
	private var target:Sprite;

	// Background for mouse hit detection
	private var background:Shape;

	// Drag state
	private var dragging:Bool = false;
	private var dragStartX:Float = 0;
	private var dragStartY:Float = 0;
	private var viewStartX:Float = 0;
	private var viewStartY:Float = 0;

	// Keyboard state
	private var keysDown:Map<Int, Bool> = new Map();

	// Initial view for reset
	private var initialX:Float = 0;
	private var initialY:Float = 0;
	private var initialZoom:Float = 1.0;

	// Signal for zoom changes (for UI sync)
	public var onZoomChanged:Signal0 = new Signal0();

	// Available area (for centering calculations)
	private var areaWidth:Float = 800;
	private var areaHeight:Float = 600;

	public function new(target:Sprite) {
		super();

		// Create transparent background for mouse hit detection
		// This allows dragging anywhere, not just on visible map elements
		background = new Shape();
		background.graphics.beginFill(0x000000, 0.001); // Nearly invisible
		background.graphics.drawRect(-5000, -5000, 10000, 10000);
		background.graphics.endFill();
		addChild(background);

		this.target = target;
		addChild(target);

		// Store initial state
		initialX = target.x;
		initialY = target.y;
		initialZoom = target.scaleX;

		// Mouse events
		addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
		addEventListener(MouseEvent.MOUSE_WHEEL, onMouseWheel);
		addEventListener(MouseEvent.DOUBLE_CLICK, onDoubleClick);

		// Enable double-click
		doubleClickEnabled = true;

		// We need stage for global mouse events
		addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
	}

	private function onAddedToStage(_):Void {
		stage.addEventListener(MouseEvent.MOUSE_UP, onMouseUp);
		stage.addEventListener(MouseEvent.MOUSE_MOVE, onMouseMove);
		stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
		stage.addEventListener(KeyboardEvent.KEY_UP, onKeyUp);
		stage.addEventListener(Event.ENTER_FRAME, onEnterFrame);
	}

	public function setTarget(newTarget:Sprite):Void {
		if (target != null && contains(target)) {
			removeChild(target);
		}
		target = newTarget;
		if (target != null) {
			// Add after background (index 1)
			addChildAt(target, 1);
			// Reset view state
			viewX = 0;
			viewY = 0;
			zoomLevel = 1.0;
			applyTransform();
		}
	}

	public function setArea(w:Float, h:Float):Void {
		areaWidth = w;
		areaHeight = h;
	}

	// Mouse drag for panning
	private function onMouseDown(e:MouseEvent):Void {
		dragging = true;
		dragStartX = e.stageX;
		dragStartY = e.stageY;
		viewStartX = viewX;
		viewStartY = viewY;
	}

	private function onMouseUp(_):Void {
		dragging = false;
	}

	private function onMouseMove(e:MouseEvent):Void {
		// Always track mouse position for zoom-to-cursor
		lastMouseX = e.stageX - this.x;
		lastMouseY = e.stageY - this.y;

		if (dragging) {
			var dx = e.stageX - dragStartX;
			var dy = e.stageY - dragStartY;
			viewX = viewStartX + dx;
			viewY = viewStartY + dy;
			applyTransform();
		}
	}

	// Track last mouse position for zoom-to-cursor
	private var lastMouseX:Float = 0;
	private var lastMouseY:Float = 0;

	// Mouse wheel for zooming
	private function onMouseWheel(e:MouseEvent):Void {
		// Get mouse position in stage coordinates, then convert to local
		lastMouseX = e.stageX - this.x;
		lastMouseY = e.stageY - this.y;

		// Calculate zoom change
		var zoomDelta = e.delta > 0 ? ZOOM_STEP : -ZOOM_STEP;
		var newZoom = Math.max(MIN_ZOOM, Math.min(MAX_ZOOM, zoomLevel + zoomDelta * zoomLevel));

		if (newZoom != zoomLevel) {
			// Zoom toward mouse position
			var zoomRatio = newZoom / zoomLevel;

			// Adjust view position to zoom toward cursor
			viewX = lastMouseX - (lastMouseX - viewX) * zoomRatio;
			viewY = lastMouseY - (lastMouseY - viewY) * zoomRatio;

			zoomLevel = newZoom;
			applyTransform();
			onZoomChanged.dispatch();
		}
	}

	// Double-click to reset
	private function onDoubleClick(_):Void {
		resetView();
	}

	// Keyboard input
	private function onKeyDown(e:KeyboardEvent):Void {
		keysDown.set(e.keyCode, true);

		// Immediate actions
		switch (e.keyCode) {
			case Keyboard.R, Keyboard.HOME:
				resetView();
			case Keyboard.F:
				fitToScreen();
			case Keyboard.EQUAL, Keyboard.NUMPAD_ADD: // + key
				zoomIn();
			case Keyboard.MINUS, Keyboard.NUMPAD_SUBTRACT: // - key
				zoomOut();
			case Keyboard.Z:
				zoomIn();
			case Keyboard.X:
				zoomOut();
		}
	}

	private function onKeyUp(e:KeyboardEvent):Void {
		keysDown.set(e.keyCode, false);
	}

	// Frame update for continuous keyboard panning
	private function onEnterFrame(_):Void {
		var panX:Float = 0;
		var panY:Float = 0;

		if (keysDown.get(Keyboard.W) == true || keysDown.get(Keyboard.UP) == true) {
			panY = 1;
		}
		if (keysDown.get(Keyboard.S) == true || keysDown.get(Keyboard.DOWN) == true) {
			panY = -1;
		}
		if (keysDown.get(Keyboard.A) == true || keysDown.get(Keyboard.LEFT) == true) {
			panX = 1;
		}
		if (keysDown.get(Keyboard.D) == true || keysDown.get(Keyboard.RIGHT) == true) {
			panX = -1;
		}

		if (panX != 0 || panY != 0) {
			// Scale pan speed so it feels consistent regardless of zoom level
			// At high zoom, pan slower in screen pixels to maintain world-space speed
			var adjustedSpeed = PAN_SPEED / Math.sqrt(zoomLevel);
			viewX += panX * adjustedSpeed;
			viewY += panY * adjustedSpeed;
			applyTransform();
		}
	}

	// Public control methods
	public function zoomIn():Void {
		var newZoom = Math.min(MAX_ZOOM, zoomLevel * 1.2);
		if (newZoom != zoomLevel) {
			// Zoom toward last mouse position (or center if unknown)
			var focusX = lastMouseX > 0 ? lastMouseX : areaWidth / 2;
			var focusY = lastMouseY > 0 ? lastMouseY : areaHeight / 2;
			var zoomRatio = newZoom / zoomLevel;
			viewX = focusX - (focusX - viewX) * zoomRatio;
			viewY = focusY - (focusY - viewY) * zoomRatio;
			zoomLevel = newZoom;
			applyTransform();
			onZoomChanged.dispatch();
		}
	}

	public function zoomOut():Void {
		var newZoom = Math.max(MIN_ZOOM, zoomLevel / 1.2);
		if (newZoom != zoomLevel) {
			// Zoom from last mouse position (or center if unknown)
			var focusX = lastMouseX > 0 ? lastMouseX : areaWidth / 2;
			var focusY = lastMouseY > 0 ? lastMouseY : areaHeight / 2;
			var zoomRatio = newZoom / zoomLevel;
			viewX = focusX - (focusX - viewX) * zoomRatio;
			viewY = focusY - (focusY - viewY) * zoomRatio;
			zoomLevel = newZoom;
			applyTransform();
			onZoomChanged.dispatch();
		}
	}

	public function resetView():Void {
		viewX = 0;
		viewY = 0;
		zoomLevel = 1.0;
		applyTransform();
		onZoomChanged.dispatch();
	}

	public function fitToScreen():Void {
		resetView();
	}

	public function setZoom(zoom:Float):Void {
		var newZoom = Math.max(MIN_ZOOM, Math.min(MAX_ZOOM, zoom));
		if (newZoom != zoomLevel) {
			// Zoom toward last mouse position (or center if unknown)
			var focusX = lastMouseX > 0 ? lastMouseX : areaWidth / 2;
			var focusY = lastMouseY > 0 ? lastMouseY : areaHeight / 2;
			var zoomRatio = newZoom / zoomLevel;
			viewX = focusX - (focusX - viewX) * zoomRatio;
			viewY = focusY - (focusY - viewY) * zoomRatio;
			zoomLevel = newZoom;
			applyTransform();
		}
	}

	public function getZoomPercent():Float {
		return zoomLevel;
	}

	// Apply current view state to target
	private function applyTransform():Void {
		if (target == null) return;

		target.scaleX = initialZoom * zoomLevel;
		target.scaleY = initialZoom * zoomLevel;
		target.x = initialX * zoomLevel + viewX;
		target.y = initialY * zoomLevel + viewY;

		// Update cache mode based on zoom level for performance
		updateCacheMode();
	}

	// Set the initial/default transform (called after layout)
	public function setInitialTransform(x:Float, y:Float, scale:Float):Void {
		initialX = x;
		initialY = y;
		initialZoom = scale;
		applyTransform();
	}

	// Cache threshold for performance optimization
	private static inline var CACHE_ZOOM_THRESHOLD:Float = 3.0;
	private var cacheEnabled:Bool = false;

	// Update bitmap caching based on zoom level for performance
	private function updateCacheMode():Void {
		var shouldCache = zoomLevel > CACHE_ZOOM_THRESHOLD;
		if (shouldCache != cacheEnabled && target != null) {
			cacheEnabled = shouldCache;
			// Set cacheAsBitmap on target and all Shape children
			target.cacheAsBitmap = shouldCache;
			for (i in 0...target.numChildren) {
				var child = target.getChildAt(i);
				if (Std.isOfType(child, Shape)) {
					cast(child, Shape).cacheAsBitmap = shouldCache;
				}
			}
		}
	}
}
