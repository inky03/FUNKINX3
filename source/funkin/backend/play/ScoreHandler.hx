package funkin.backend.play;

import funkin.backend.play.Scoring;
import flixel.util.FlxSignal.FlxTypedSignal;

using Lambda;

class ScoreHandler {
	public var score:Float = 0;
	public var accuracyMod:Float = 0;
	public var accuracyDiv:Float = 0;
	public var combo(default, set):Int = 0;
	public var misses(default, set):Int = 0;
	@:isVar public var accuracy(get, never):Float = 0;
	public var ratingCount:Map<String, Int> = [];
	
	public var onMissesChange:FlxTypedSignal<Int -> Void> = new FlxTypedSignal();
	public var onComboChange:FlxTypedSignal<Int -> Void> = new FlxTypedSignal();
	
	public var hitWindows:Array<HitWindow> = [];
	public var holdScorePerSecond:Float;
	public var system:ScoringSystem;

	public function new(system:ScoringSystem = LEGACY) {
		this.system = system;
		this.hitWindows = switch (system) {
			case EMI:
				holdScorePerSecond = 250;
				Scoring.emiDefault();
			case PBOT1:
				holdScorePerSecond = 250;
				Scoring.pbotDefault();
			default:
				holdScorePerSecond = 0;
				Scoring.legacyDefault();
		}
	}
	public function reset() {
		score = accuracyMod = accuracyDiv = combo = misses = 0;
		ratingCount.clear();
	}
	
	public function judgeNoteHit(note:funkin.objects.play.Note, time:Float):Score {
		return switch (system) {
			case EMI | WEEK7 | LEGACY:
				var score:Score = Scoring.judgeLegacy(hitWindows, note.hitWindow, time);
				// todo : fun stuff!
				score;
			case PBOT1:
				var score:Score = Scoring.judgePBOT1(hitWindows, note.hitWindow, time);
				score;
		}
	}
	public function judgeNoteMiss(note:funkin.objects.play.Note):Score {
		return switch (system) {
			case EMI:
				{score: -50};
			default:
				{score: -10};
		}
	}
	public function getHitWindow(rating:String)
		return hitWindows.find((win:HitWindow) -> win.rating == rating);
	public function getRatingCount(rating:String)
		return ratingCount.get(rating) ?? 0;
	public function countRating(rating:String, mod:Int = 1)
		ratingCount.set(rating, getRatingCount(rating) + mod);
	public function addMod(mod:Float = 0, div:Float = 1) {
		accuracyMod += mod;
		accuracyDiv += div;
	}
	
	function set_combo(newCombo:Int):Int {
		if (newCombo == combo)
			return newCombo;
		onComboChange.dispatch(newCombo);
		return combo = newCombo;
	}
	function set_misses(newMisses:Int):Int {
		if (newMisses == misses)
			return newMisses;
		onMissesChange.dispatch(newMisses);
		return misses = newMisses;
	}
	function get_accuracy():Float {
		if (accuracyMod > 0 && accuracyDiv > 0)
			return (accuracyMod / accuracyDiv * 100);
		return 0;
	}
}