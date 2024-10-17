package;

import flixel.input.keyboard.FlxKey;

@:structInit class SettingsData {
	public var downscroll:Bool = false;
	public var middlescroll:Bool = false;
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

class Settings {
	public static var defaultData:SettingsData = {};
	public static var data:SettingsData = {};
}