package funkin.backend.rhythm;

import funkin.backend.rhythm.TempoChange;

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
		beat = relBeat + lastBeat;
		step = beat * 4;
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
		step = newBeat * 4;
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

	public function convertMeasure(value:Float, input:Measure, output:Measure):Float {
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

enum Measure {
	STEP;
	BEAT;
	BAR;
	MS;
}