package;

import flixel.addons.transition.FlxTransitionableState;
import flixel.util.FlxSignal.FlxTypedSignal;
import flixel.addons.ui.FlxUIState;

class MusicBeatState extends FlxUIState {
	public var curStep:Int = -1;
	public var curBeat:Int = -1;
	public var curBar:Int = -1;
	public var paused:Bool = false;

	public var stepHit:FlxTypedSignal<Int->Void> = new FlxTypedSignal<Int->Void>();
	public var beatHit:FlxTypedSignal<Int->Void> = new FlxTypedSignal<Int->Void>();
	public var barHit:FlxTypedSignal<Int->Void> = new FlxTypedSignal<Int->Void>();
	
	override function create() {
		super.create();
	}
	
	public function resetMusic() {
		curBar = -1;
		curBeat = -1;
		curStep = -1;
		Conductor.songPosition = 0;
	}
	
	override function update(elapsed:Float) {
		super.update(elapsed);
		if (paused) return;
		
		updateMetronome(elapsed * 1000);
	}
	
	public function updateMetronome(elapsedMS:Float = 0) {
		var prevStep:Int = curStep;
		var prevBeat:Int = curBeat;
		var prevBar:Int = curBar;

		Conductor.songPosition += elapsedMS;
		
		curStep = Math.floor(Conductor.metronome.step);
		curBeat = Math.floor(Conductor.metronome.beat);
		curBar = Math.floor(Conductor.metronome.bar);
		
		if (prevBar != curBar) barHit.dispatch(curBar);
		if (prevBeat != curBeat) beatHit.dispatch(curBeat);
		if (prevStep != curStep) stepHit.dispatch(curStep);
	}
}