package;

class Conductor {
	@:isVar public static var songPosition(get, set):Float = 0;
	public static var crochet(get, never):Float;
	public static var stepCrochet(get, never):Float;
	public static var metronome:Metronome = new Metronome();
	
	public static function get_crochet() return (metronome.getCrochet(metronome.bpm, metronome.denominator));
	public static function get_stepCrochet() return (crochet * .25);
	
	public static function get_songPosition() return metronome.ms;
	public static function set_songPosition(newMS:Float) {
		metronome.setMS(newMS);
		return songPosition = newMS;
	}
	public static function resetToDefault() {
		metronome = new Metronome();
	}
	public static function convertMeasure(value:Float, input:MetronomeMeasure, output:MetronomeMeasure, ?baseMetronome:Metronome) {
		baseMetronome = baseMetronome ?? Conductor.metronome;
		var prevMS:Float = baseMetronome.ms;
		var target:Float = 0;
		switch (input) {
			case STEP: baseMetronome.setStep(value);
			case BEAT: baseMetronome.setBeat(value);
			case BAR: baseMetronome.setBar(value);
			case MS: baseMetronome.setMS(value);
			default:
		}
		switch (output) {
			case STEP: target = baseMetronome.step;
			case BEAT: target = baseMetronome.beat;
			case BAR: target = baseMetronome.bar;
			case MS: target = baseMetronome.ms; //why
			default:
		}
		baseMetronome.setMS(prevMS);
		return target;
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
	public var numerator:Int;
	public var denominator:Int;
	
	inline public function getCrochet(bpm:Float, denominator:Int) return (60000 / bpm / denominator * 4);
	public function new(newBPM:Float = 100, newNum:Int = 4, newDenom:Int = 4) {
		bpm = newBPM;
		step = 0;
		beat = 0;
		bar = 0;
		numerator = newNum;
		denominator = newDenom;
		tempoChanges = [new TempoChange(0, 100, 4, 4)];
	}
	
	public function setStep(newStep:Float) {
		setBeat(newStep * 4);
		return step = newStep;
	}
	
	public function setBeat(newBeat:Float) {
		if (beat == newBeat) return newBeat;
		
		var firstChange:TempoChange = tempoChanges[0];
		bpm = firstChange.bpm;
		numerator = firstChange.numerator;
		denominator = firstChange.denominator;
		
		var tempBeat:Float = 0;
		var lastBeat:Float = 0;
		var lastBar:Float = 0;
		var lastMS:Float = 0;
		
		for (change in tempoChanges) {
			tempBeat += (change.beatTime - lastBeat);
			if (tempBeat > newBeat) break;
			
			lastBeat = tempBeat;
			lastBar += (change.beatTime - lastBeat) / numerator;
			lastMS += (change.beatTime - lastBeat) * getCrochet(bpm, denominator);
			
			if (change.changeBPM) bpm = change.bpm;
			if (change.changeTimeSign) {
				numerator = change.numerator;
				denominator = change.denominator;
			}
		}
		
		var crochet:Float = getCrochet(bpm, denominator);
		var relBeat = newBeat - lastBeat;
		step = beat * 4;
		ms = relBeat * crochet + lastMS;
		bar = relBeat / numerator + lastBar;
		
		return beat = newBeat;
	}
	
	public function setBar(newBar:Float) {
		if (bar == newBar) return newBar;
		
		var firstChange:TempoChange = tempoChanges[0];
		bpm = firstChange.bpm;
		numerator = firstChange.numerator;
		denominator = firstChange.denominator;
		
		var lastBeat:Float = 0;
		var tempBar:Float = 0;
		var lastBar:Float = 0;
		var lastMS:Float = 0;
		
		for (change in tempoChanges) {
			tempBar += (change.beatTime - lastBeat) / numerator;
			if (tempBar > newBar) break;
			
			lastBeat = change.beatTime;
			lastMS += (change.beatTime - lastBeat) * getCrochet(bpm, denominator);
			
			if (change.changeBPM) bpm = change.bpm;
			if (change.changeTimeSign) {
				numerator = change.numerator;
				denominator = change.denominator;
			}
		}
		
		var crochet:Float = getCrochet(bpm, denominator);
		var relBeat = (newBar - lastBeat) * numerator;
		step = bar * 4;
		beat = relBeat + lastBeat;
		ms = relBeat * crochet + lastMS;
		
		return bar = newBar;
	}
	
	public function setMS(newMS:Float) { //todo: optimize (dont recalculate every bpm change every update)
		if (ms == newMS) return newMS;
		
		var firstChange:TempoChange = tempoChanges[0];
		bpm = firstChange.bpm;
		numerator = firstChange.numerator;
		denominator = firstChange.denominator;
		
		var lastBeat:Float = 0;
		var lastBar:Float = 0;
		var lastMS:Float = 0;
		var tempMS:Float = 0;
		
		for (change in tempoChanges) {
			tempMS += (change.beatTime - lastBeat) * getCrochet(bpm, denominator);
			if (tempMS > newMS) break;
			
			lastMS = tempMS;
			lastBar += (change.beatTime - lastBeat) / numerator;
			lastBeat = change.beatTime;
			
			if (change.changeBPM) bpm = change.bpm;
			if (change.changeTimeSign) {
				numerator = change.numerator;
				denominator = change.denominator;
			}
		}
		
		var crochet:Float = getCrochet(bpm, denominator);
		var relBeat = (newMS - lastMS) / crochet;
		beat = relBeat + lastBeat;
		step = beat * 4;
		bar = relBeat / numerator + lastBar;
		
		return ms = newMS;
	}
}

class TempoChange {
	public var beatTime:Float;
	
	public var changeBPM(default, null):Bool = false;
	public var bpm(default, set):Float;
	
	public var changeTimeSign(default, null):Bool = false;
	public var numerator(default, set):Int;
	public var denominator(default, set):Int;
	
	public function new(beat:Float, bpm:Float = 0, numerator:Int = 0, denominator:Int = 0) {
		this.bpm = bpm;
		this.beatTime = beat;
		setTimeSignature(numerator, denominator);
	}
	public function set_bpm(newBPM:Float) {
		this.changeBPM = (newBPM > 0);
		return bpm = newBPM;
	}
	public function set_numerator(newNum:Int) {
		this.changeTimeSign = (newNum > 0 && denominator > 0);
		return numerator = newNum;
	}
	public function set_denominator(newDenom:Int) {
		this.changeTimeSign = (numerator > 0 && newDenom > 0);
		return denominator = newDenom;
	}
	public function setTimeSignature(newNum:Int = 0, newDenom:Int = 0) {
		this.numerator = newNum;
		this.denominator = newDenom;
	}
}