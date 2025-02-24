package funkin.backend;

class FunkinGame extends flixel.FlxGame {
	var _time:Float = -1;
	
	public function new(width:Int = 0, height:Int = 0, ?initialState:flixel.util.typeLimit.NextState.InitialState, updateFramerate:Int = 60, drawFramerate:Int = 60, skipSplash:Bool = false, startFullscreen:Bool = false) {
		super(width, height, initialState, updateFramerate, drawFramerate, skipSplash, startFullscreen);
		_customSoundTray = funkin.backend.FunkinSoundTray;
	}
	
	override function switchState() {
		_time = -1;
		super.switchState();
	}
	
	function crashGame(mes:String = 'Triggered a manual crash') {
		throw mes;
	}
	
	override function update():Void {
		if (!_state.active || !_state.exists)
			return;
		
		if (FlxG.keys.pressed.SHIFT && FlxG.keys.justPressed.F2)
			crashGame();

		if (_nextState != null)
			switchState();

		#if FLX_DEBUG
		if (FlxG.debugger.visible)
			ticks = getTicks();
		#end
		
		var curTime:Float = haxe.Timer.stamp();
		var realTime:Float = 0;
		if (_time >= 0)
			realTime = Math.min(curTime - _time, FlxG.maxElapsed);
		_elapsedMS = realTime * 1000;
		_time = curTime;
		_total = ticks;
		
		updateElapsed();

		FlxG.signals.preUpdate.dispatch();

		updateInput();

		#if FLX_POST_PROCESS
		if (postProcesses[0] != null)
			postProcesses[0].update(realTime);
		#end

		#if FLX_SOUND_SYSTEM
		FlxG.sound.update(realTime);
		#end
		FlxG.plugins.update(realTime);

		_state.tryUpdate(realTime);

		FlxG.cameras.update(realTime);
		FlxG.signals.postUpdate.dispatch();

		#if FLX_DEBUG
		debugger.stats.flixelUpdate(getTicks() - ticks);
		#end

		#if FLX_POINTER_INPUT
		var len = FlxG.swipes.length;
		while (len-- > 0) {
			final swipe = FlxG.swipes.pop();
			if (swipe != null)
				swipe.destroy();
		}
		#end

		filters = filtersEnabled ? _filters : null;
	}
}