package funkin.backend;

class FunkinGame extends flixel.FlxGame {
	public function new(width:Int = 0, height:Int = 0, ?initialState:flixel.util.typeLimit.NextState.InitialState, updateFramerate:Int = 60, drawFramerate:Int = 60, skipSplash:Bool = false, startFullscreen:Bool = false) {
		super(width, height, initialState, updateFramerate, drawFramerate, skipSplash, startFullscreen);
		
		#if FLX_SOUND_TRAY
		_customSoundTray = funkin.backend.FunkinSoundTray;
		#end
	}
	
	function crashGame(mes:String = 'Triggered a manual crash') {
		throw mes;
	}
}