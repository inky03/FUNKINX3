package funkin.backend.play;

import funkin.backend.play.Scoring;

using Lambda;

class ScoreHandler {
	public var ratingCount:Map<String, Int> = [];
	public var hitWindows:Array<HitWindow> = [];
	public var system:ScoringSystem;

	public var holdScorePerSecond:Float;

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
	public function countRating(rating:String)
		ratingCount.set(rating, getRatingCount(rating) + 1);
}