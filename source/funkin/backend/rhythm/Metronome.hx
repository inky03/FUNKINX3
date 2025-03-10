package funkin.backend.rhythm;

import funkin.backend.rhythm.TempoChange;

class Metronome {
	public var tempoChanges:Array<TempoChange>;
	public var step:Float;
	public var beat:Float;
	public var bar:Float;
	public var ms:Float;
	
	public var bpm:Float; // QUARTER notes per min.
	public var timeSignature:TimeSignature;
	
	inline public function getCrochet(bpm:Float, denominator:Int = 4) return (60000 / bpm / denominator * 4);
	public function new(newBPM:Float = 100, newNum:Int = 4, newDen:Int = 4) {
		bpm = newBPM;
		step = 0;
		beat = 0;
		bar = 0;
		timeSignature = new TimeSignature(newNum, newDen);
		tempoChanges = [new TempoChange(0, newBPM, new TimeSignature(newNum, newDen))];
	}
	
	public function setStep(newStep:Float) {
		setBeat(newStep * .25);
		return step = newStep;
	}
	
	public function getMeasureBeats(time:Float, ?measure:Measure = MS):Array<Float> {
		var targetBar:Int = Std.int(convertMeasure(time, measure, BAR));
		var beatsArray:Array<Float> = [];
		
		for (bar in 0...targetBar)
			beatsArray.push(convertMeasure(bar, BAR, BEAT));
		
		return beatsArray;
	}
	
	public function setBar(newBar:Float):Float {
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
			lastBar = tempBar;
			
			if (change.changeBPM) bpm = change.bpm;
			if (change.changeSign) timeSignature.copyFrom(change.timeSignature);
		}
		
		var crochet:Float = getCrochet(bpm, timeSignature.denominator);
		var relBeat = (newBar - lastBar) * timeSignature.numerator;
		beat = relBeat + lastBeat;
		step = beat * 4;
		ms = relBeat * crochet + lastMS;
		
		return bar = newBar;
	}
	
	public function setBeat(newBeat:Float):Float {
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
	
	public function setMS(newMS:Float):Float { //todo: optimize (dont recalculate every bpm change every update)
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

	public function convertMeasure(time:Float, input:Measure, output:Measure):Float {
		var prevBPM:Float = bpm;
		var prevNum:Int = timeSignature.numerator;
		var prevDen:Int = timeSignature.denominator;
		var prevStep:Float = step;
		var prevBeat:Float = beat;
		var prevBar:Float = bar;
		var prevMS:Float = ms;
		var target:Float;
		switch (input) { // uh. yeah.
			case STEP: setStep(time);
			case BEAT: setBeat(time);
			case BAR: setBar(time);
			case MS: setMS(time);
		}
		switch (output) {
			case MS: target = ms;
			case BAR: target = bar;
			case BEAT: target = beat;
			case STEP: target = step;
		}
		ms = prevMS;
		bar = prevBar;
		beat = prevBeat;
		step = prevStep;
		timeSignature.set(prevNum, prevDen);
		bpm = prevBPM;
		return target;
	}
	
	public function sortTempoChanges() {
		tempoChanges.sort((a:TempoChange, b:TempoChange) -> Std.int(a.beatTime) - Std.int(b.beatTime));
	}
}

enum abstract Measure(String) to String {
	var STEP = 'step';
	var BEAT = 'beat';
	var BAR = 'bar';
	var MS = 'ms';
}