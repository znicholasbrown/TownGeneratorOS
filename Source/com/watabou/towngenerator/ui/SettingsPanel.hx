package com.watabou.towngenerator.ui;

import openfl.display.Sprite;
import openfl.display.Shape;
import openfl.display.Graphics;
import openfl.events.MouseEvent;
import openfl.events.Event;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.text.TextFieldType;

import msignal.Signal.Signal0;

import com.watabou.towngenerator.settings.GeneratorSettings;
import com.watabou.towngenerator.settings.FeatureMode;
import com.watabou.towngenerator.mapping.Palette;
import com.watabou.towngenerator.mapping.CityMap;

class SettingsPanel extends Sprite {

	public var onGenerate:Signal0 = new Signal0();
	public var onClose:Signal0 = new Signal0();
	public var onExport:Signal0 = new Signal0();
	public var onImport:Signal0 = new Signal0();

	private var settings:GeneratorSettings;
	private var palette:Palette;

	private var panelWidth:Float = 260;
	private var panelHeight:Float = 600;

	// UI elements
	private var sizeSlider:SimpleSlider;
	private var seedInput:SimpleInput;
	private var plazaToggle:SimpleToggle;
	private var citadelToggle:SimpleToggle;
	private var wallsToggle:SimpleToggle;
	private var generateBtn:SimpleButton;
	private var paletteButtons:Array<PaletteButton>;

	// Tab state
	private var currentTab:Int = 0;
	private var tabButtons:Array<TabButton>;
	private var tabContents:Array<Sprite>;

	public function new() {
		super();

		settings = GeneratorSettings.instance;
		palette = settings.palette;

		buildPanel();
	}

	private function buildPanel():Void {
		// Background
		var bg = new Shape();
		drawPanelBackground(bg.graphics);
		addChild(bg);

		// Header
		var header = buildHeader();
		addChild(header);

		// Tab bar
		buildTabBar();

		// Tab contents
		buildTabs();

		// Show first tab
		showTab(0);
	}

	private function drawPanelBackground(g:Graphics):Void {
		g.beginFill(palette.paper);
		g.lineStyle(2, palette.dark);
		g.drawRect(0, 0, panelWidth, panelHeight);
		g.endFill();
	}

	private function buildHeader():Sprite {
		var header = new Sprite();
		var g = header.graphics;

		g.beginFill(palette.medium);
		g.drawRect(0, 0, panelWidth, 28);
		g.endFill();

		// Title
		var title = createLabel("SETTINGS", palette.paper, true);
		title.x = 10;
		title.y = 4;
		header.addChild(title);

		// Close button
		var closeBtn = new SimpleButton("X", 20, 20, function() {
			onClose.dispatch();
		}, palette);
		closeBtn.x = panelWidth - 26;
		closeBtn.y = 4;
		header.addChild(closeBtn);

		return header;
	}

	private function buildTabBar():Void {
		var tabBar = new Sprite();
		tabBar.y = 28;
		addChild(tabBar);

		var g = tabBar.graphics;
		g.beginFill(palette.medium);
		g.drawRect(0, 0, panelWidth, 26);
		g.endFill();

		tabButtons = [];
		var tabNames = ["Gen", "Wards", "Detail", "Style"];
		var tabWidth = panelWidth / tabNames.length;

		for (i in 0...tabNames.length) {
			var tab = new TabButton(tabNames[i], Std.int(tabWidth), 26, i, function(idx:Int) {
				showTab(idx);
			}, palette);
			tab.x = i * tabWidth;
			tabBar.addChild(tab);
			tabButtons.push(tab);
		}
	}

	private function buildTabs():Void {
		tabContents = [];

		// Generation tab
		var genTab = buildGenerationTab();
		genTab.visible = false;
		addChild(genTab);
		tabContents.push(genTab);

		// Wards tab (simplified for now)
		var wardsTab = buildWardsTab();
		wardsTab.visible = false;
		addChild(wardsTab);
		tabContents.push(wardsTab);

		// Details tab
		var detailsTab = buildDetailsTab();
		detailsTab.visible = false;
		addChild(detailsTab);
		tabContents.push(detailsTab);

		// Style tab
		var styleTab = buildStyleTab();
		styleTab.visible = false;
		addChild(styleTab);
		tabContents.push(styleTab);
	}

	private function showTab(idx:Int):Void {
		currentTab = idx;

		for (i in 0...tabContents.length) {
			tabContents[i].visible = (i == idx);
		}

		for (i in 0...tabButtons.length) {
			tabButtons[i].setSelected(i == idx);
		}
	}

	private function buildGenerationTab():Sprite {
		var tab = new Sprite();
		tab.y = 54;
		var yPos:Float = 10;

		// City Size
		var sizeLabel = createLabel("City Size", palette.dark, true);
		sizeLabel.x = 10;
		sizeLabel.y = yPos;
		tab.addChild(sizeLabel);
		yPos += 22;

		sizeSlider = new SimpleSlider(6, 40, settings.size, 200, function(v:Float) {
			settings.size = Std.int(v);
		}, palette);
		sizeSlider.x = 10;
		sizeSlider.y = yPos;
		tab.addChild(sizeSlider);
		yPos += 30;

		// Seed
		var seedLabel = createLabel("Seed (blank = random)", palette.dark, true);
		seedLabel.x = 10;
		seedLabel.y = yPos;
		tab.addChild(seedLabel);
		yPos += 22;

		seedInput = new SimpleInput(140, settings.seed > 0 ? Std.string(settings.seed) : "", function(text:String) {
			var val = Std.parseInt(text);
			settings.seed = val != null ? val : -1;
		}, palette);
		seedInput.x = 10;
		seedInput.y = yPos;
		tab.addChild(seedInput);

		var randomBtn = new SimpleButton("Random", 60, 22, function() {
			settings.seed = -1;
			seedInput.setText("");
		}, palette);
		randomBtn.x = 160;
		randomBtn.y = yPos;
		tab.addChild(randomBtn);
		yPos += 35;

		// Features
		var featuresLabel = createLabel("Features", palette.dark, true);
		featuresLabel.x = 10;
		featuresLabel.y = yPos;
		tab.addChild(featuresLabel);
		yPos += 22;

		plazaToggle = new SimpleToggle("Central Plaza", settings.plazaMode != FeatureMode.Never, function(on:Bool) {
			settings.plazaMode = on ? FeatureMode.Always : FeatureMode.Never;
		}, palette);
		plazaToggle.x = 10;
		plazaToggle.y = yPos;
		tab.addChild(plazaToggle);
		yPos += 26;

		citadelToggle = new SimpleToggle("Castle/Citadel", settings.citadelMode != FeatureMode.Never, function(on:Bool) {
			settings.citadelMode = on ? FeatureMode.Always : FeatureMode.Never;
		}, palette);
		citadelToggle.x = 10;
		citadelToggle.y = yPos;
		tab.addChild(citadelToggle);
		yPos += 26;

		wallsToggle = new SimpleToggle("City Walls", settings.wallsMode != FeatureMode.Never, function(on:Bool) {
			settings.wallsMode = on ? FeatureMode.Always : FeatureMode.Never;
		}, palette);
		wallsToggle.x = 10;
		wallsToggle.y = yPos;
		tab.addChild(wallsToggle);
		yPos += 40;

		// Generate button
		generateBtn = new SimpleButton("GENERATE", 220, 36, function() {
			onGenerate.dispatch();
		}, palette, true);
		generateBtn.x = 10;
		generateBtn.y = yPos;
		tab.addChild(generateBtn);
		yPos += 50;

		// Import/Export section
		var ioLabel = createLabel("Import / Export", palette.dark, true);
		ioLabel.x = 10;
		ioLabel.y = yPos;
		tab.addChild(ioLabel);
		yPos += 22;

		var exportBtn = new SimpleButton("Export JSON", 105, 28, function() {
			onExport.dispatch();
		}, palette);
		exportBtn.x = 10;
		exportBtn.y = yPos;
		tab.addChild(exportBtn);

		var importBtn = new SimpleButton("Import JSON", 105, 28, function() {
			onImport.dispatch();
		}, palette);
		importBtn.x = 125;
		importBtn.y = yPos;
		tab.addChild(importBtn);

		return tab;
	}

	private function buildWardsTab():Sprite {
		var tab = new Sprite();
		tab.y = 54;
		var yPos:Float = 10;

		var label = createLabel("Ward Distribution", palette.dark, true);
		label.x = 10;
		label.y = yPos;
		tab.addChild(label);
		yPos += 26;

		// Preset selector (simplified)
		var presetLabel = createLabel("Preset:", palette.dark, false);
		presetLabel.x = 10;
		presetLabel.y = yPos;
		tab.addChild(presetLabel);
		yPos += 26;

		var presets = ["balanced", "commercial", "military", "noble", "slums"];
		var presetLabels = ["Balanced", "Commercial", "Military", "Noble", "Slums"];

		for (i in 0...presets.length) {
			var preset = presets[i];
			var btn = new SimpleButton(presetLabels[i], 100, 24, function() {
				settings.applyPreset(preset);
			}, palette);
			btn.x = 10 + (i % 2) * 110;
			btn.y = yPos + Std.int(i / 2) * 30;
			tab.addChild(btn);
		}

		return tab;
	}

	private function buildDetailsTab():Sprite {
		var tab = new Sprite();
		tab.y = 54;
		var yPos:Float = 10;

		// Street widths
		var streetLabel = createLabel("Street Widths", palette.dark, true);
		streetLabel.x = 10;
		streetLabel.y = yPos;
		tab.addChild(streetLabel);
		yPos += 22;

		tab.addChild(createSliderRow("Main:", 1.0, 4.0, settings.mainStreetWidth, yPos, function(v) { settings.mainStreetWidth = v; }));
		yPos += 26;

		tab.addChild(createSliderRow("Regular:", 0.5, 2.0, settings.regularStreetWidth, yPos, function(v) { settings.regularStreetWidth = v; }));
		yPos += 26;

		tab.addChild(createSliderRow("Alley:", 0.3, 1.0, settings.alleyWidth, yPos, function(v) { settings.alleyWidth = v; }));
		yPos += 35;

		// Building style
		var buildingLabel = createLabel("Building Style", palette.dark, true);
		buildingLabel.x = 10;
		buildingLabel.y = yPos;
		tab.addChild(buildingLabel);
		yPos += 22;

		tab.addChild(createSliderRow("Chaos:", 0.0, 2.0, settings.gridChaosMultiplier, yPos, function(v) { settings.gridChaosMultiplier = v; }));
		yPos += 26;

		tab.addChild(createSliderRow("Size Var:", 0.0, 2.0, settings.sizeVariationMultiplier, yPos, function(v) { settings.sizeVariationMultiplier = v; }));
		yPos += 26;

		tab.addChild(createSliderRow("Empty:", 0.0, 2.0, settings.emptyLotMultiplier, yPos, function(v) { settings.emptyLotMultiplier = v; }));

		return tab;
	}

	private function createSliderRow(labelText:String, min:Float, max:Float, initial:Float, yPos:Float, onChange:Float->Void):Sprite {
		var row = new Sprite();
		row.y = yPos;

		var label = createLabel(labelText, palette.dark, false);
		label.x = 10;
		row.addChild(label);

		var slider = new SimpleSlider(min, max, initial, 140, onChange, palette);
		slider.x = 70;
		row.addChild(slider);

		return row;
	}

	private function buildStyleTab():Sprite {
		var tab = new Sprite();
		tab.y = 54;
		var yPos:Float = 10;

		var label = createLabel("Color Palette", palette.dark, true);
		label.x = 10;
		label.y = yPos;
		tab.addChild(label);
		yPos += 26;

		paletteButtons = [];
		var paletteNames = GeneratorSettings.PALETTE_NAMES;
		var paletteLabels = GeneratorSettings.PALETTE_LABELS;

		for (i in 0...paletteNames.length) {
			var name = paletteNames[i];
			var palLabel = paletteLabels.get(name);
			var pal = GeneratorSettings.PALETTES.get(name);

			var btn = new PaletteButton(palLabel, pal, 110, 28, function() {
				settings.setPaletteByName(name);
				updatePaletteSelection();
			}, palette);
			btn.x = 10 + (i % 2) * 120;
			btn.y = yPos + Std.int(i / 2) * 34;
			tab.addChild(btn);
			paletteButtons.push(btn);
		}

		return tab;
	}

	private function updatePaletteSelection():Void {
		// Update visual state of palette buttons
		for (btn in paletteButtons) {
			btn.setSelected(btn.getPalette() == settings.palette);
		}
	}

	private function createLabel(text:String, color:Int, bold:Bool):TextField {
		var tf = new TextField();
		var format = new TextFormat("_sans", 12, color, bold);
		tf.defaultTextFormat = format;
		tf.text = text;
		tf.selectable = false;
		tf.width = 200;
		tf.height = 20;
		return tf;
	}

	public function setHeight(h:Float):Void {
		panelHeight = h;
		// Redraw background
		graphics.clear();
		drawPanelBackground(graphics);
	}
}

// Simple UI components

class SimpleButton extends Sprite {
	private var callback:Void->Void;
	private var palette:Palette;
	private var primary:Bool;
	private var w:Float;
	private var h:Float;

	public function new(text:String, width:Float, height:Float, onClick:Void->Void, pal:Palette, primary:Bool = false) {
		super();
		this.callback = onClick;
		this.palette = pal;
		this.primary = primary;
		this.w = width;
		this.h = height;

		draw(false);

		var label = new TextField();
		label.defaultTextFormat = new TextFormat("_sans", 11, primary ? pal.paper : pal.paper, true);
		label.text = text;
		label.selectable = false;
		label.width = width;
		label.height = height;
		label.x = 4;
		label.y = (height - 14) / 2;
		addChild(label);

		buttonMode = true;
		addEventListener(MouseEvent.CLICK, onClicked);
		addEventListener(MouseEvent.MOUSE_OVER, onOver);
		addEventListener(MouseEvent.MOUSE_OUT, onOut);
	}

	private function draw(hover:Bool):Void {
		graphics.clear();
		var bgColor = primary ? (hover ? palette.medium : palette.dark) : (hover ? palette.light : palette.medium);
		graphics.beginFill(bgColor);
		graphics.lineStyle(1, palette.dark);
		graphics.drawRect(0, 0, w, h);
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

class SimpleSlider extends Sprite {
	private var min:Float;
	private var max:Float;
	private var value:Float;
	private var sliderWidth:Float;
	private var callback:Float->Void;
	private var palette:Palette;
	private var thumb:Sprite;
	private var dragging:Bool = false;
	private var valueLabel:TextField;

	public function new(min:Float, max:Float, initial:Float, width:Float, onChange:Float->Void, pal:Palette) {
		super();
		this.min = min;
		this.max = max;
		this.value = initial;
		this.sliderWidth = width;
		this.callback = onChange;
		this.palette = pal;

		// Track
		graphics.beginFill(pal.light);
		graphics.lineStyle(1, pal.dark);
		graphics.drawRect(0, 8, width, 6);
		graphics.endFill();

		// Thumb
		thumb = new Sprite();
		thumb.graphics.beginFill(pal.dark);
		thumb.graphics.drawRect(-6, 0, 12, 18);
		thumb.graphics.endFill();
		thumb.buttonMode = true;
		addChild(thumb);

		// Value label
		valueLabel = new TextField();
		valueLabel.defaultTextFormat = new TextFormat("_sans", 10, pal.medium);
		valueLabel.selectable = false;
		valueLabel.width = 40;
		valueLabel.height = 16;
		valueLabel.x = width + 5;
		valueLabel.y = 2;
		addChild(valueLabel);

		updateThumb();

		thumb.addEventListener(MouseEvent.MOUSE_DOWN, onThumbDown);
		addEventListener(MouseEvent.CLICK, onTrackClick);
	}

	private function updateThumb():Void {
		var ratio = (value - min) / (max - min);
		thumb.x = ratio * sliderWidth;
		valueLabel.text = Std.string(Math.round(value * 10) / 10);
	}

	private function onThumbDown(e:MouseEvent):Void {
		dragging = true;
		stage.addEventListener(MouseEvent.MOUSE_MOVE, onDrag);
		stage.addEventListener(MouseEvent.MOUSE_UP, onDragEnd);
	}

	private function onDrag(e:MouseEvent):Void {
		if (dragging) {
			var localX = globalToLocal(new openfl.geom.Point(e.stageX, e.stageY)).x;
			var ratio = Math.max(0, Math.min(1, localX / sliderWidth));
			value = min + ratio * (max - min);
			updateThumb();
			if (callback != null) callback(value);
		}
	}

	private function onDragEnd(_):Void {
		dragging = false;
		stage.removeEventListener(MouseEvent.MOUSE_MOVE, onDrag);
		stage.removeEventListener(MouseEvent.MOUSE_UP, onDragEnd);
	}

	private function onTrackClick(e:MouseEvent):Void {
		if (!dragging) {
			var ratio = Math.max(0, Math.min(1, e.localX / sliderWidth));
			value = min + ratio * (max - min);
			updateThumb();
			if (callback != null) callback(value);
		}
	}
}

class SimpleToggle extends Sprite {
	private var checked:Bool;
	private var callback:Bool->Void;
	private var palette:Palette;
	private var checkBox:Shape;

	public function new(text:String, initial:Bool, onChange:Bool->Void, pal:Palette) {
		super();
		this.checked = initial;
		this.callback = onChange;
		this.palette = pal;

		checkBox = new Shape();
		addChild(checkBox);
		drawCheckbox();

		var label = new TextField();
		label.defaultTextFormat = new TextFormat("_sans", 11, pal.dark);
		label.text = text;
		label.selectable = false;
		label.width = 200;
		label.height = 18;
		label.x = 22;
		label.y = 0;
		addChild(label);

		buttonMode = true;
		addEventListener(MouseEvent.CLICK, onClick);
	}

	private function drawCheckbox():Void {
		var g = checkBox.graphics;
		g.clear();
		g.beginFill(checked ? palette.dark : palette.paper);
		g.lineStyle(2, palette.dark);
		g.drawRect(0, 0, 16, 16);
		g.endFill();

		if (checked) {
			g.lineStyle(2, palette.paper);
			g.moveTo(3, 8);
			g.lineTo(6, 12);
			g.lineTo(13, 4);
		}
	}

	private function onClick(_):Void {
		checked = !checked;
		drawCheckbox();
		if (callback != null) callback(checked);
	}
}

class SimpleInput extends Sprite {
	private var input:TextField;
	private var callback:String->Void;

	public function new(width:Float, initial:String, onChange:String->Void, pal:Palette) {
		super();
		this.callback = onChange;

		graphics.beginFill(pal.paper);
		graphics.lineStyle(1, pal.dark);
		graphics.drawRect(0, 0, width, 22);
		graphics.endFill();

		input = new TextField();
		input.type = TextFieldType.INPUT;
		input.defaultTextFormat = new TextFormat("_sans", 11, pal.dark);
		input.text = initial;
		input.width = width - 8;
		input.height = 18;
		input.x = 4;
		input.y = 2;
		addChild(input);

		input.addEventListener(Event.CHANGE, onChanged);
	}

	private function onChanged(_):Void {
		if (callback != null) callback(input.text);
	}

	public function setText(text:String):Void {
		input.text = text;
	}
}

class TabButton extends Sprite {
	private var selected:Bool = false;
	private var palette:Palette;
	private var index:Int;
	private var w:Float;
	private var h:Float;
	private var label:TextField;

	public function new(text:String, width:Int, height:Int, idx:Int, onClick:Int->Void, pal:Palette) {
		super();
		this.palette = pal;
		this.index = idx;
		this.w = width;
		this.h = height;

		draw();

		label = new TextField();
		label.defaultTextFormat = new TextFormat("_sans", 10, pal.paper, true);
		label.text = text;
		label.selectable = false;
		label.width = width;
		label.height = height;
		label.x = 4;
		label.y = 5;
		addChild(label);

		buttonMode = true;
		addEventListener(MouseEvent.CLICK, function(_) { onClick(idx); });
	}

	private function draw():Void {
		graphics.clear();
		graphics.beginFill(selected ? palette.paper : palette.medium);
		graphics.drawRect(0, 0, w, h);
		graphics.endFill();
	}

	public function setSelected(sel:Bool):Void {
		selected = sel;
		draw();
		var format = new TextFormat("_sans", 10, selected ? palette.dark : palette.paper, true);
		label.setTextFormat(format);
	}
}

class PaletteButton extends Sprite {
	private var pal:Palette;
	private var selected:Bool = false;
	private var parentPal:Palette;
	private var w:Float;
	private var h:Float;
	private var callback:Void->Void;

	public function new(text:String, palette:Palette, width:Float, height:Float, onClick:Void->Void, parentPalette:Palette) {
		super();
		this.pal = palette;
		this.parentPal = parentPalette;
		this.w = width;
		this.h = height;
		this.callback = onClick;

		draw();

		// Color swatch
		var swatch = new Shape();
		swatch.graphics.beginFill(palette.paper);
		swatch.graphics.drawRect(4, 4, 16, 16);
		swatch.graphics.beginFill(palette.dark);
		swatch.graphics.drawRect(4, 12, 16, 8);
		swatch.graphics.endFill();
		addChild(swatch);

		var label = new TextField();
		label.defaultTextFormat = new TextFormat("_sans", 9, parentPalette.dark);
		label.text = text;
		label.selectable = false;
		label.width = width - 24;
		label.height = height;
		label.x = 24;
		label.y = 6;
		addChild(label);

		buttonMode = true;
		addEventListener(MouseEvent.CLICK, function(_) { if (callback != null) callback(); });
	}

	private function draw():Void {
		graphics.clear();
		graphics.beginFill(parentPal.paper);
		graphics.lineStyle(selected ? 3 : 1, selected ? parentPal.medium : parentPal.dark);
		graphics.drawRect(0, 0, w, h);
		graphics.endFill();
	}

	public function setSelected(sel:Bool):Void {
		selected = sel;
		draw();
	}

	public function getPalette():Palette {
		return pal;
	}
}
