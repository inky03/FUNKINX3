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
			timeScale = syncTracker.pitch;
			if (Math.abs(songPosition - syncTracker.time) > maxDisparity * timeScale)
				songPosition = syncTracker.time;
		}
	}
	
	public function get_crochet():Float { return (metronome.getCrochet(metronome.bpm, metronome.timeSignature.denominator)); }
	public function get_stepCrochet():Float { return (crochet * .25); }
	
	public function get_songPosition():Float { return metronome.ms; }
	public function set_songPosition(newMS:Float):Float { return metronome.setMS(newMS); }
	public function get_timeSignature():TimeSignature { return metronome.timeSignature; }
	public function get_bpm():Float { return metronome.bpm; }
	
	public function resetToDefault() {
		metronome = new Metronome();
	}
}