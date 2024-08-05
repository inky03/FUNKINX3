package;

class Conductor {
	public static var songPosition(default, set):Float = 0;
	public static var crochet:Float = 600;
	public static var stepCrochet:Float = crochet * .25;
	public static var metronome:Metronome = new Metronome();
	
	inline public static function getCrochet(bpm:Float, denominator:Int) return (60000 / bpm / denominator * 4);
	inline public static function recalculateCrochet(BPM:Float, numerator:Int, denominator:Int) {
		crochet = getCrochet(BPM, denominator);
		stepCrochet = crochet * .25; //step is ALWAYS 1/4 of a beat. doesnt matter
	}
	public static function set_songPosition(newMS:Float) {
		metronome.updateFromMS(newMS);
		recalculateCrochet(metronome.bpm, metronome.numerator, metronome.denominator);
		return songPosition = newMS;
	}
}

class Metronome {
	public var tempoChanges:Array<TempoChange>;
	public var step:Float;
	public var beat:Float;
	public var bar:Float;
	public var bpm:Float;
	
	//time signatures
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
	public function updateFromMS(ms:Float) { //todo: optimize (dont recalculate every bpm change every update)
		var firstChange = tempoChanges[0];
		if (firstChange == null) return;
		
		bpm = firstChange.bpm;
		numerator = firstChange.numerator;
		denominator = firstChange.denominator;
		
		var lastBeat:Float = 0;
		var lastBar:Float = 0;
		var lastMS:Float = 0;
		var tempMS:Float = 0;
		
		for (change in tempoChanges) {
			tempMS += (change.beatTime - lastBeat) * getCrochet(bpm, denominator);
			if (tempMS > ms) break;
			
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
		var relBeat = (ms - lastMS) / crochet;
		beat = relBeat + lastBeat;
		step = beat * 4;
		bar = relBeat / numerator + lastBar;
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