package;

import flixel.addons.ui.FlxUIState;
import flixel.addons.transition.FlxTransitionableState;

class MusicBeatState extends FlxUIState {
	public var curStep:Int = -1;
	public var curBeat:Int = -1;
	public var curBar:Int = -1;
	public var paused:Bool = false;
	
	override function create() {
		super.create();
	}
	
	public function resetMusic() {
		curBar = -1;
		curBeat = -1;
		curStep = -1;
		Conductor.songPosition = 0;
	}
	public function stepHit(step:Int) {
	}
	public function beatHit(beat:Int) {
	}
	public function barHit(bar:Int) {
	}
	
	override function update(elapsed:Float) {
		super.update(elapsed);
		if (paused) return;
		
		updateMetronome(elapsed * 1000);
	}
	
	public function updateMetronome(elapsedMS:Float = 0) {
		var prevStep = curStep;
		var prevBeat = curBeat;
		var prevBar = curBar;
		Conductor.songPosition += elapsedMS;
		
		curStep = Math.floor(Conductor.metronome.step);
		curBeat = Math.floor(Conductor.metronome.beat);
		curBar = Math.floor(Conductor.metronome.bar);
		if (prevBar != curBar) barHit(curBar);
		if (prevBeat != curBeat) beatHit(curBeat);
		if (prevStep != curStep) stepHit(curStep);
	}
}