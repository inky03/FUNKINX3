package;

import flixel.FlxGame;
import openfl.display.Sprite;
#if hxdiscord_rpc import lib.DiscordRPC; #end

class Main extends Sprite {
	public static var engineVersion = '0.0.2';
	
	public function new() {
		super();
		#if hxdiscord_rpc
		DiscordRPC.prepare();
		#end
		Sys.println('WE REALLY OUT HERE - GAME STARTED ON ${Date.now().toString()}');

		Mods.refresh();
		addChild(new FlxGame(0, 0, PlayState));
		addChild(new DebugDisplay(10, 3, 0xFFFFFF));

		FlxG.maxElapsed = 1;
		FlxG.drawFramerate = 240;
		FlxG.updateFramerate = 240;
		// FlxG.fixedTimestep = false;
	}
}
