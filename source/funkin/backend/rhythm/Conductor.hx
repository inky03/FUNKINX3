package funkin.backend.rhythm;

import funkin.backend.rhythm.TempoChange;

class Conductor {
	public var timeScale:Float = 1;
	public var paused:Bool = false;
	public var bpm(get, never):Float;
	public var crochet(get, never):Float;
	public var stepCrochet(get, never):Float;
	public var timeSignature(get, never):TimeSignature;
	@:isVar public var songPosition(get, set):Float = 0;
	
	public var metronome:Metronome;
	public var syncTracker:FlxSound;
	public var maxDisparity:Float = 33.34;
	public static var global(default, never):Conductor = new Conductor();
	
	public function new(?metronome:Metronome) {
		this.metronome = metronome ?? new Metronome();
	}
	public function update(elapsedMS:Float) {
		if (paused) return;
		songPosition += Math.min(elapsedMS, 250) * timeScale;
		if (syncTracker != null && syncTracker.playing) {
			if (Math.abs(songPosition - syncTracker.time) > maxDisparity * timeScale)
				songPosition = syncTracker.time;
		}
	}
	
	public function get_crochet() return (metronome.getCrochet(metronome.bpm, metronome.timeSignature.denominator));
	public function get_stepCrochet() return (crochet * .25);
	
	public function get_songPosition() return metronome.ms;
	public function set_songPosition(newMS:Float) return metronome.setMS(newMS);
	public function get_timeSignature() return metronome.timeSignature;
	public function get_bpm() return metronome.bpm;
	
	public function resetToDefault() {
		metronome = new Metronome();
	}
}