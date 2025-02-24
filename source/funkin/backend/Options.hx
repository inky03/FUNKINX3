package funkin.backend;

import flixel.input.keyboard.FlxKey;

@:structInit class OptionsData {
	public var xtendScore:Bool = false;
	public var downscroll:Bool = false;
	public var middlescroll:Bool = false;
	public var ghostTapping:Bool = true;
	public var antialiasing:Bool = true;
	public var keybinds:Map<String, Dynamic> = [
		'4k' => [
			[A, LEFT],
			[S, DOWN],
			[W, UP, K],
			[D, RIGHT, L]
		]
	];
	
	var canMod:Bool = false;
	public function new(mod:Bool = false) {
		canMod = mod;
	}
}

class Options {
	public static var defaultData:OptionsData = new OptionsData();
	public static var data:OptionsData = new OptionsData(true);
}