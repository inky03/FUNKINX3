package funkin.backend.rhythm;

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