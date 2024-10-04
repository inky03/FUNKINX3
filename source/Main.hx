package;

import flixel.FlxGame;
import lib.DiscordRPC;
import openfl.display.Sprite;

class Main extends Sprite {
	public static var engineVersion = '0.0.2';
	
	public function new() {
		super();
		Sys.println('WE REALLY OUT HERE - GAME STARTED ON ${Date.now().toString()}');

		Mods.refresh();
		DiscordRPC.prepare();
		var game:FlxGame = new FlxGame(0, 0, PlayState);
		@:privateAccess game._customSoundTray = FunkinSoundTray;
		addChild(game);
		addChild(new DebugDisplay(10, 3, 0xFFFFFF));

		FlxG.maxElapsed = 1;
		FlxG.drawFramerate = 240;
		FlxG.updateFramerate = 240;
		// FlxG.fixedTimestep = false;
	}
}
