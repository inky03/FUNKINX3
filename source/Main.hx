package;

import flixel.FlxGame;
import openfl.display.Sprite;

class Main extends Sprite {
	public static var engineVersion = '0.0.1';
	
	public function new() {
		super();
		DiscordRPC.prepare();
		addChild(new FlxGame(0, 0, PlayState));
		addChild(new DebugDisplay(10, 3, 0xFFFFFF));
	}
}
