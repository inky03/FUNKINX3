package;

import flixel.input.keyboard.FlxKey;

class Controls {
	public static function keybindFromArray(array:Array<Array<FlxKey>>, key:FlxKey) {
		for (i in 0...array.length) {
			for (bind in array[i]) {
				if (bind == key) return i;
			}
		}
		return -1;
	}
}