package com.watabou.towngenerator;

import openfl.display.Sprite;
import openfl.events.MouseEvent;

import com.watabou.coogee.Scene;

import com.watabou.towngenerator.building.Model;
import com.watabou.towngenerator.mapping.CityMap;
import com.watabou.towngenerator.settings.GeneratorSettings;
import com.watabou.towngenerator.ui.SettingsPanel;
import com.watabou.towngenerator.ui.Tooltip;

class TownScene extends Scene {

	private var map:CityMap;
	private var settingsPanel:SettingsPanel;
	private var panelContainer:Sprite;
	private var toggleButton:Sprite;
	private var panelVisible:Bool = true;

	private static inline var PANEL_WIDTH:Float = 280;

	public function new() {
		super();

		// City map
		map = new CityMap(Model.instance);
		addChild(map);

		// Tooltip for ward info
		addChild(new Tooltip());

		// Settings panel container
		panelContainer = new Sprite();
		addChild(panelContainer);

		// Create HaxeUI settings panel
		settingsPanel = new SettingsPanel();
		settingsPanel.onGenerate.add(regenerateCity);
		settingsPanel.onClose.add(togglePanel);

		// Add panel to HaxeUI root and then to our container
		panelContainer.addChild(settingsPanel);

		// Toggle button
		toggleButton = createToggleButton();
		addChild(toggleButton);
	}

	private function createToggleButton():Sprite {
		var btn = new Sprite();
		var g = btn.graphics;

		// Draw hamburger menu icon
		g.beginFill(0x67635c);
		g.drawRect(0, 0, 32, 32);
		g.endFill();

		g.beginFill(0xccc5b8);
		g.drawRect(6, 8, 20, 3);
		g.drawRect(6, 14, 20, 3);
		g.drawRect(6, 20, 20, 3);
		g.endFill();

		btn.buttonMode = true;
		btn.addEventListener(MouseEvent.CLICK, function(_) { togglePanel(); });

		return btn;
	}

	private function togglePanel():Void {
		panelVisible = !panelVisible;
		panelContainer.visible = panelVisible;
		layout();
	}

	private function regenerateCity():Void {
		var settings = GeneratorSettings.instance;

		// Create new model with current settings
		new Model(settings.size, settings.seed);

		// Recreate the map
		if (map != null && contains(map)) {
			removeChild(map);
		}
		map = new CityMap(Model.instance);
		addChildAt(map, 0);

		layout();
	}

	private var scale(get, set):Float;

	private inline function get_scale():Float {
		return map.scaleX;
	}

	private function set_scale(value:Float):Float {
		return (map.scaleX = map.scaleY = value);
	}

	override public function layout():Void {
		// Calculate available space for map
		var mapAreaWidth = panelVisible ? rWidth - PANEL_WIDTH : rWidth;

		// Center map in available space
		map.x = mapAreaWidth / 2;
		map.y = rHeight / 2;

		// Scale map to fit
		var scaleX = mapAreaWidth / Model.instance.cityRadius;
		var scaleY = rHeight / Model.instance.cityRadius;
		var scMin = Math.min(scaleX, scaleY);
		var scMax = Math.max(scaleX, scaleY);
		scale = (scMax / scMin > 2 ? scMax / 2 : scMin) * 0.5;

		// Position settings panel on the right
		panelContainer.x = rWidth - PANEL_WIDTH;
		panelContainer.y = 0;
		settingsPanel.height = rHeight;

		// Position toggle button
		if (panelVisible) {
			toggleButton.x = rWidth - PANEL_WIDTH - 36;
		} else {
			toggleButton.x = rWidth - 36;
		}
		toggleButton.y = 4;
	}
}
