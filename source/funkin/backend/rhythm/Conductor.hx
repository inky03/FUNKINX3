package funkin.backend.rhythm;

import funkin.backend.rhythm.Metronome;
import funkin.backend.rhythm.TempoChange;

import flixel.util.FlxSignal.FlxTypedSignal;

class Conductor {
	public var timeScale:Float = 1;
	public var paused:Bool = false;
	public var bpm(get, never):Float;
	public var crochet(get, never):Float;
	public var stepCrochet(get, never):Float;
	public var timeSignature(get, never):TimeSignature;
	@:isVar public var songPosition(get, set):Float = 0;
	@:isVar public var tempoChanges(get, set):Array<TempoChange>;
	
	@:isVar public var step(get, set):Float;
	@:isVar public var beat(get, set):Float;
	@:isVar public var bar(get, set):Float;
	// @:isVar public var ms(get, set):Float;
	
	public var dispatchEvents:Bool = true;
	public var barHit:FlxTypedSignal<Int -> Void> = new FlxTypedSignal();
	public var beatHit:FlxTypedSignal<Int -> Void> = new FlxTypedSignal();
	public var stepHit:FlxTypedSignal<Int -> Void> = new FlxTypedSignal();
	public var advance:FlxTypedSignal<Float -> Void> = new FlxTypedSignal();
	
	public var metronome:Metronome;
	public var syncTracker:FlxSound;
	public var maxDisparity:Float = 33.34;
	public static var global(default, never):Conductor = new Conductor();
	
	public function new(?metronome:Metronome) {
		this.metronome = metronome ?? new Metronome();
	}
	public function update(elapsedMS:Float) {
		if (paused) return;
		
		var prevStep:Int = Math.floor(metronome.step);
		var prevBeat:Int = Math.floor(metronome.beat);
		var prevBar:Int = Math.floor(metronome.bar);
		
		songPosition += Math.min(elapsedMS, 250) * timeScale;
		if (syncTracker != null) {
			timeScale = syncTracker.pitch;
			if (syncTracker.playing && Math.abs(metronome.ms - syncTracker.time) > maxDisparity * timeScale)
				songPosition = syncTracker.time;
		}
		
		if (dispatchEvents) {
			advance.dispatch(metronome.ms);
			
			var curBar:Int = Math.floor(metronome.bar);
			var curBeat:Int = Math.floor(metronome.beat);
			var curStep:Int = Math.floor(metronome.step);
			
			if (prevBar != curBar) barHit.dispatch(curBar);
			if (prevBeat != curBeat) beatHit.dispatch(curBeat);
			if (prevStep != curStep) stepHit.dispatch(curStep);
		}
	}
	
	public function convertMeasure(time:Float, input:Measure, output:Measure):Float { return metronome.convertMeasure(time, input, output); }
	public function getMeasureBeats(time:Float, ?measure:Measure = MS):Array<Float> { return metronome.getMeasureBeats(time, measure); }
	
	public function get_crochet():Float { return metronome.getCrochet(metronome.bpm, metronome.timeSignature.denominator); }
	public function get_stepCrochet():Float { return (crochet * .25); }
	
	public function get_tempoChanges():Array<TempoChange> { return metronome.tempoChanges; }
	public function set_tempoChanges(newArray:Array<TempoChange>):Array<TempoChange> { return metronome.tempoChanges = newArray; }
	public function get_songPosition():Float { return metronome.ms; }
	public function set_songPosition(newMS:Float):Float { return metronome.setMS(newMS); }
	public function get_timeSignature():TimeSignature { return metronome.timeSignature; }
	public function get_bpm():Float { return metronome.bpm; }
	
	// public function get_ms():Float { return metronome.ms; }
	public function get_bar():Float { return metronome.bar; }
	public function get_beat():Float { return metronome.beat; }
	public function get_step():Float { return metronome.step; }
	public function set_step(newStep:Float):Float { return metronome.setStep(newStep); }
	public function set_beat(newBeat:Float):Float { return metronome.setBeat(newBeat); }
	public function set_bar(newBar:Float):Float { return metronome.setBar(newBar); }
	// public function set_ms(newMS:Float):Float { return metronome.setMS(newMS); }
	
	public function resetToDefault() {
		metronome = new Metronome();
	}
	
	public function sortTempoChanges() {
		metronome.sortTempoChanges();
	}
}