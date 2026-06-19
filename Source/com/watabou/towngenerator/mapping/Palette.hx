package com.watabou.towngenerator.mapping;

class Palette {

	public var paper	: Int;
	public var light	: Int;
	public var medium	: Int;
	public var dark		: Int;
	public var water	: Int;

	public inline function new( paper, light, medium, dark, water = -1 ) {
		this.paper	= paper;
		this.light	= light;
		this.medium	= medium;
		this.dark	= dark;
		// Default water color if not specified
		this.water	= water == -1 ? computeWaterColor(paper, medium) : water;
	}

	// Generate a default water color based on the palette
	private static function computeWaterColor(paper:Int, medium:Int):Int {
		// Blend toward blue from the paper color
		var pr = (paper >> 16) & 0xFF;
		var pg = (paper >> 8) & 0xFF;
		var pb = paper & 0xFF;

		// Add blue tint
		var r = Std.int(pr * 0.6);
		var g = Std.int(pg * 0.7);
		var b = Std.int(Math.min(255, pb * 0.8 + 80));

		return (r << 16) | (g << 8) | b;
	}

	// Parchment/default palette - muted blue-gray water
	public static var DEFAULT	= new Palette( 0xccc5b8, 0x99948a, 0x67635c, 0x1a1917, 0x7a9bb8 );
	// Blueprint - lighter blue water
	public static var BLUEPRINT	= new Palette( 0x455b8d, 0x7383aa, 0xa1abc6, 0xfcfbff, 0x6b8fc4 );
	// Black and white - gray water
	public static var BW		= new Palette( 0xffffff, 0xcccccc, 0x888888, 0x000000, 0xaabbcc );
	// Ink - bluish gray water
	public static var INK		= new Palette( 0xcccac2, 0x9a979b, 0x6c6974, 0x130f26, 0x8899aa );
	// Night - dark teal water
	public static var NIGHT		= new Palette( 0x000000, 0x402306, 0x674b14, 0x99913d, 0x1a3a4a );
	// Ancient - muted teal water
	public static var ANCIENT	= new Palette( 0xccc5a3, 0xa69974, 0x806f4d, 0x342414, 0x6a8a7a );
	// Colour - blue-green water
	public static var COLOUR	= new Palette( 0xfff2c8, 0xd6a36e, 0x869a81, 0x4c5950, 0x5a8ab0 );
	// Simple - blue water
	public static var SIMPLE	= new Palette( 0xffffff, 0x000000, 0x000000, 0x000000, 0x4488cc );
}
