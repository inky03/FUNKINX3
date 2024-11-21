package;

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
}

class Options {
	public static var defaultData:OptionsData = {};
	public static var data:OptionsData = {};
}