package funkin.backend.play;

import funkin.backend.play.ScoreSystem;
import flixel.util.FlxSignal.FlxTypedSignal;

class ScoreHandler {
	public var score:Float = 0;
	public var accuracyMod:Float = 0;
	public var accuracyDiv:Float = 0;
	public var hits(default, set):Int = 0;
	public var combo(default, set):Int = 0;
	public var misses(default, set):Int = 0;
	@:isVar public var accuracy(get, never):Float = 0;
	public var ratingCount:Map<String, Int> = [];
	
	public var onMissesChange:FlxTypedSignal<Int -> Void> = new FlxTypedSignal();
	public var onComboChange:FlxTypedSignal<Int -> Void> = new FlxTypedSignal();
	public var onHit:FlxTypedSignal<Int -> Void> = new FlxTypedSignal();
	
	public var system:ScoreSystem;

	public function new(?system:ScoreSystem) {
		this.system = (system ?? new ScoreSystem());
	}
	public function reset() {
		score = accuracyMod = accuracyDiv = combo = misses = 0;
		ratingCount.clear();
	}
	
	public function applyScore(score:Score) {
		this.hits += (score.hits ?? 0);
		this.score += (score.score ?? 0);
		this.misses += (score.misses ?? 0);
		
		if (score.rating != null)
			countRating(score.rating);
		if (score.accuracyMod != null)
			addMod(score.accuracyMod);
		if (score.breaksCombo != null && score.breaksCombo) {
			combo = 0;
		} else {
			combo += score.hits;
		}
	}
	
	public function judgeNoteHit(note:funkin.objects.play.Note, time:Float):Score {
		return system.judgeHit(time, note.hitWindow);
	}
	public function judgeNoteMiss(note:funkin.objects.play.Note):Score {
		return system.judgeMiss(note);
	}
	public function judgeNoteGhost():Score {
		return system.judgeGhost();
	}
	public function getHitWindow(rating:String) {
		return system.hitFromName(rating);
	}
	public function getRatingCount(rating:String) {
		return ratingCount.get(rating) ?? 0;
	}
	public function countRating(rating:String, mod:Int = 1) {
		ratingCount.set(rating, getRatingCount(rating) + mod);
	}
	public function addMod(mod:Float = 0, div:Float = 1) {
		accuracyMod += mod;
		accuracyDiv += div;
	}
	
	function set_hits(newHits:Int):Int {
		if (newHits == hits)
			return newHits;
		onHit.dispatch(newHits);
		return hits = newHits;
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