package com.watabou.towngenerator;

import openfl.system.Capabilities;

import com.watabou.coogee.Game;
import com.watabou.coogee.BitmapText.BitmapFont;

import com.watabou.towngenerator.building.Model;
import com.watabou.towngenerator.mapping.CityMap;
import com.watabou.towngenerator.settings.GeneratorSettings;

class Main extends Game {

	public static var uiFont	: BitmapFont;

	public function new () {
		StateManager.pullParams();
		StateManager.pushParams();

		stage.color = CityMap.palette.paper;

		uiFont = BitmapFont.get( "font", CityMap.palette.paper );
		uiFont.letterSpacing = 1;
		uiFont.baseLine = 8;

		// Listen for palette changes to update stage color
		GeneratorSettings.instance.onChange.add(function() {
			stage.color = CityMap.palette.paper;
		});

		new Model( GeneratorSettings.instance.size, GeneratorSettings.instance.seed );

		super( TownScene );
	}

	override public function getScale( w:Int, h:Int ):Float {
		// Cap scale to 2x max to keep UI readable
		return Math.min(2, Std.int( Capabilities.screenDPI / 72 ));
	}
}