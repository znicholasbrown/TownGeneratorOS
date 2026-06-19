package com.watabou.towngenerator;

import openfl.display.Sprite;
import openfl.events.MouseEvent;

#if html5
import js.Browser;
import js.html.FileReader;
import js.html.InputElement;
#end

import com.watabou.coogee.Scene;

import com.watabou.towngenerator.building.Model;
import com.watabou.towngenerator.mapping.CityMap;
import com.watabou.towngenerator.mapping.ImportedCityMap;
import com.watabou.towngenerator.settings.GeneratorSettings;
import com.watabou.towngenerator.ui.SettingsPanel;
import com.watabou.towngenerator.ui.Tooltip;
import com.watabou.towngenerator.export.CityExporter;
import com.watabou.towngenerator.importing.CityImporter;
import com.watabou.towngenerator.importing.ImportedCity;

class TownScene extends Scene {

	private var map:CityMap;
	private var importedMap:ImportedCityMap;
	private var importedCity:ImportedCity;
	private var showingImported:Bool = false;
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

		// Create settings panel
		settingsPanel = new SettingsPanel();
		settingsPanel.onGenerate.add(regenerateCity);
		settingsPanel.onClose.add(togglePanel);
		settingsPanel.onExport.add(exportCity);
		settingsPanel.onImport.add(importCity);

		// Add panel to our container
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

		// Clear imported city if showing one
		if (showingImported && importedMap != null && contains(importedMap)) {
			removeChild(importedMap);
			importedMap = null;
			importedCity = null;
			showingImported = false;
		}

		// Recreate the map
		if (map != null && contains(map)) {
			removeChild(map);
		}
		map = new CityMap(Model.instance);
		addChildAt(map, 0);

		layout();
	}

	private function exportCity():Void {
		#if html5
		// Export current city to JSON
		var json = CityExporter.toJSON(Model.instance);

		// Create download
		var blob = new js.html.Blob([json], {type: "application/json"});
		var url = js.html.URL.createObjectURL(blob);
		var link = Browser.document.createAnchorElement();
		link.href = url;
		link.download = "city_export.json";
		link.click();
		js.html.URL.revokeObjectURL(url);
		#else
		trace("Export is only supported in HTML5 target");
		#end
	}

	private function importCity():Void {
		#if html5
		// Create file input
		var input:InputElement = cast Browser.document.createElement("input");
		input.type = "file";
		input.accept = ".json,application/json";
		input.onchange = function(_) {
			if (input.files != null && input.files.length > 0) {
				var file = input.files[0];
				var reader = new FileReader();
				reader.onload = function(_) {
					var jsonStr:String = cast reader.result;
					loadImportedCity(jsonStr);
				};
				reader.readAsText(file);
			}
		};
		input.click();
		#else
		trace("Import is only supported in HTML5 target");
		#end
	}

	private function loadImportedCity(jsonStr:String):Void {
		importedCity = CityImporter.fromJSON(jsonStr);
		if (importedCity == null) {
			trace("Failed to parse JSON");
			return;
		}

		// Clear existing maps
		if (map != null && contains(map)) {
			removeChild(map);
		}
		if (importedMap != null && contains(importedMap)) {
			removeChild(importedMap);
		}

		// Create imported city map
		importedMap = new ImportedCityMap(importedCity);
		addChildAt(importedMap, 0);
		showingImported = true;

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

		if (showingImported && importedMap != null) {
			// Layout for imported city
			var cityWidth = importedCity.getWidth();
			var cityHeight = importedCity.getHeight();
			var center = importedCity.getCenter();

			// Scale to fit
			var scaleX = mapAreaWidth / cityWidth * 0.9;
			var scaleY = rHeight / cityHeight * 0.9;
			var sc = Math.min(scaleX, scaleY);

			importedMap.scaleX = sc;
			importedMap.scaleY = sc;

			// Center the map
			importedMap.x = mapAreaWidth / 2 - center.x * sc;
			importedMap.y = rHeight / 2 - center.y * sc;
		} else if (map != null) {
			// Layout for generated city
			// Center map in available space
			map.x = mapAreaWidth / 2;
			map.y = rHeight / 2;

			// Scale map to fit
			var scaleX = mapAreaWidth / Model.instance.cityRadius;
			var scaleY = rHeight / Model.instance.cityRadius;
			var scMin = Math.min(scaleX, scaleY);
			var scMax = Math.max(scaleX, scaleY);
			scale = (scMax / scMin > 2 ? scMax / 2 : scMin) * 0.5;
		}

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
