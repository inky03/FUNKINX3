package;

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

enum MetronomeMeasure {
	STEP;
	BEAT;
	BAR;
	MS;
}

class Metronome {
	public var tempoChanges:Array<TempoChange>;
	public var step:Float;
	public var beat:Float;
	public var bar:Float;
	public var ms:Float;
	
	public var bpm:Float;
	public var timeSignature:TimeSignature;
	
	inline public function getCrochet(bpm:Float, denominator:Int = 4) return (60000 / bpm / denominator * 4);
	public function new(newBPM:Float = 100, newNum:Int = 4, newDenom:Int = 4) {
		bpm = newBPM;
		step = 0;
		beat = 0;
		bar = 0;
		timeSignature = new TimeSignature();
		timeSignature.numerator = newNum;
		timeSignature.denominator = newDenom;
		tempoChanges = [new TempoChange(0, newBPM, new TimeSignature(newNum, newDenom))];
	}
	
	public function setStep(newStep:Float) {
		setBeat(newStep * .25);
		return step = newStep;
	}
	
	public function setBar(newBar:Float) {
		if (bar == newBar) return newBar;
		
		var firstChange:TempoChange = tempoChanges[0];
		bpm = firstChange.bpm;
		timeSignature.copyFrom(firstChange.timeSignature);
		
		var lastBeat:Float = 0;
		var tempBar:Float = 0;
		var lastBar:Float = 0;
		var lastMS:Float = 0;
		
		for (change in tempoChanges) {
			tempBar += (change.beatTime - lastBeat) / timeSignature.numerator;
			if (tempBar > newBar) break;
			
			lastMS += (change.beatTime - lastBeat) * getCrochet(bpm, timeSignature.denominator);
			lastBeat = change.beatTime;
			
			if (change.changeBPM) bpm = change.bpm;
			if (change.changeSign) timeSignature.copyFrom(change.timeSignature);
		}
		
		var crochet:Float = getCrochet(bpm, timeSignature.denominator);
		var relBeat = (newBar - lastBeat) * timeSignature.numerator;
		step = bar * 4;
		beat = relBeat + lastBeat;
		ms = relBeat * crochet + lastMS;
		
		return bar = newBar;
	}
	
	public function setBeat(newBeat:Float) {
		if (beat == newBeat) return newBeat;
		
		var firstChange:TempoChange = tempoChanges[0];
		bpm = firstChange.bpm;
		timeSignature.copyFrom(firstChange.timeSignature);
		
		var tempBeat:Float = 0;
		var lastBeat:Float = 0;
		var lastBar:Float = 0;
		var lastMS:Float = 0;
		
		for (change in tempoChanges) {
			tempBeat += (change.beatTime - lastBeat);
			if (tempBeat > newBeat) break;
			
			lastBar += (change.beatTime - lastBeat) / timeSignature.numerator;
			lastMS += (change.beatTime - lastBeat) * getCrochet(bpm, timeSignature.denominator);
			lastBeat = tempBeat;
			
			if (change.changeBPM) bpm = change.bpm;
			if (change.changeSign) timeSignature.copyFrom(change.timeSignature);
		}
		
		var crochet:Float = getCrochet(bpm, timeSignature.denominator);
		var relBeat = newBeat - lastBeat;
		step = beat * 4;
		ms = relBeat * crochet + lastMS;
		bar = relBeat / timeSignature.numerator + lastBar;
		
		return beat = newBeat;
	}
	
	public function setMS(newMS:Float) { //todo: optimize (dont recalculate every bpm change every update)
		if (ms == newMS) return newMS;
		
		var firstChange:TempoChange = tempoChanges[0];
		bpm = firstChange.bpm;
		timeSignature.copyFrom(firstChange.timeSignature);
		
		var lastBeat:Float = 0;
		var lastBar:Float = 0;
		var lastMS:Float = 0;
		var tempMS:Float = 0;
		
		for (change in tempoChanges) {
			tempMS += (change.beatTime - lastBeat) * getCrochet(bpm, timeSignature.denominator);
			if (tempMS > newMS) break;
			
			lastMS = tempMS;
			lastBar += (change.beatTime - lastBeat) / timeSignature.numerator;
			lastBeat = change.beatTime;
			
			if (change.changeBPM) bpm = change.bpm;
			if (change.changeSign) timeSignature.copyFrom(change.timeSignature);
		}
		
		var crochet:Float = getCrochet(bpm, timeSignature.denominator);
		var relBeat = (newMS - lastMS) / crochet;
		beat = relBeat + lastBeat;
		step = beat * 4;
		bar = relBeat / timeSignature.numerator + lastBar;
		
		return ms = newMS;
	}

	public function convertMeasure(value:Float, input:MetronomeMeasure, output:MetronomeMeasure):Float {
		var prevStep:Float = step;
		var prevBeat:Float = beat;
		var prevBar:Float = bar;
		var prevMS:Float = ms;
		var target:Float = 0;
		switch (input) { // uh. yeah.
			case STEP: setStep(value);
			case BEAT: setBeat(value);
			case BAR: setBar(value);
			case MS: setMS(value);
			default:
		}
		switch (output) {
			case STEP: target = step;
			case BEAT: target = beat;
			case BAR: target = bar;
			case MS: target = ms;
			default:
		}
		step = prevStep;
		beat = prevBeat;
		bar = prevBar;
		ms = prevMS;
		return target;
	}
}

class TempoChange {
	public var beatTime:Float;
	
	public var changeBPM(get, never):Bool;
	public var changeSign(get, never):Bool;

	public var bpm:Null<Float>;
	public var timeSignature:Null<TimeSignature>;
	
	public function new(beat:Float, ?bpm:Float, ?timeSignature:TimeSignature) {
		this.bpm = bpm;
		this.beatTime = beat;
		this.timeSignature = timeSignature;
	}
	public function setTimeSignature(newNum:Int = 4, newDenom:Int = 4) {
		if (timeSignature == null) return timeSignature = new TimeSignature(newNum, newDenom);
		timeSignature.numerator = newNum;
		timeSignature.denominator = newDenom;
		return timeSignature;
	}
	public function get_changeBPM()
		return (bpm != null);
	public function get_changeSign()
		return (timeSignature != null);
}

class TimeSignature { //should this be a class?
	public var numerator(default, set):Int;
	public var denominator(default, set):Int;

	public function new(num:Int = 4, denom:Int = 4) {
		numerator = num;
		denominator = denom;
	}
	public function set_numerator(newNum:Int) {
		return numerator = Std.int(Math.max(newNum, 1));
	}
	public function set_denominator(newDenom:Int) {
		return denominator = Std.int(Math.max(newDenom, 1));
	}
	public function copyFrom(sign:Null<TimeSignature>) {
		if (sign == null) return this;
		numerator = sign.numerator;
		denominator = sign.denominator;
		return this;
	}
	public function toString() {
		return '$numerator/$denominator';
	}
	public function fromString(str:String) {
		var split:Array<String> = str.split('/');
		numerator = Std.parseInt(split[0] ?? '4');
		denominator = Std.parseInt(split[1] ?? '4');
		return this;
	}
}