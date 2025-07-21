package funkin.backend.play;

import funkin.objects.play.Note;

// modern scoring system (PBOT1)
class ModernScoreSystem extends ScoreSystem {
	public var scoringOffset:Float = 54.99;
	public var scoringSlope:Float = .080;
	
	public var maxScore:Float = 500;
	public var minScore:Float = 9;
	
	public var perfectThreshold:Float = 5;
	public var missThreshold:Float = 160;
	
	public function new() {
		super();
		name = 'PBOT1';
		useMilliseconds = true;
	}
	
	public override function makeHitWindows():Array<HitWindow> {
		var hitWindows:Array<HitWindow> = [
			new HitWindow('killer', 0, 		12.5,		1,		2 / 1.5),
			new HitWindow('sick', 	0, 		45,			1,		1),
			new HitWindow('good', 	0, 		90,			.8,		.75 / 1.5),
			new HitWindow('bad', 	0, 		135,		.5,		0),
			new HitWindow('shit', 	0, 		160,		.2,		-1 / 1.5),
			new HitWindow('shit', 	0, 		160,		0,		-2) // HORRIBLE (key mashing)
		]; // score is 0 because its calculated in judging !
		hitWindows[0].splash = hitWindows[1].splash = true;
		hitWindows[3].breaksCombo = hitWindows[4].breaksCombo = hitWindows[5].breaksCombo = true;
		
		return hitWindows;
	}
	
	public override function judgeHit(time:Float, hitWindow:Float):Score {
		var hit:HitWindow = hitFromTime(time, hitWindow);

		var score:Float;
		var accuracyMod:Float;
		var absTime:Float = Math.abs(time);
		
		if (absTime <= perfectThreshold) {
			score = maxScore;
			accuracyMod = 1;
		} else if (absTime >= missThreshold) {
			score = minScore;
			accuracyMod = 0;
		} else {
			var factor:Float = (1 - (1 / (1 + Math.exp(-scoringSlope * (absTime - scoringOffset)))));
			score = Math.max(Math.floor(maxScore * factor + minScore), 0);
			accuracyMod = (score / maxScore);
		}
		
		return {
			hits: 1,
			hitWindow: hit,
			rating: hit.rating,
			healthMod: hit.healthMod,
			breaksCombo: hit.breaksCombo,
			
			accuracyMod: accuracyMod,
			score: score
		};
	}
	
	public override function judgeMiss(note:Note):Score {
		var miss:Score = super.judgeMiss(note);
		miss.score = -100;
		return miss;
	}
}

// emi scoring system (fx3)
class EmiScoreSystem extends ScoreSystem {
	public function new() {
		super();
		name = 'Emi';
	}
	
	public override function makeHitWindows():Array<HitWindow> {
		var hitWindows:Array<HitWindow> = [
			new HitWindow('killer', 500, 	.06, 	1,		1),
			new HitWindow('sick', 	350, 	.3, 	1,		.75),
			new HitWindow('good', 	200, 	.6, 	.8,		.25),
			new HitWindow('bad', 	100, 	.9, 	.5,		-.25),
			new HitWindow('shit', 	50, 	1,  	.2,		-.5),
			new HitWindow('shit', 	-50, 	1,  	0,		-2) // HORRIBLE (key mashing)
		];
		hitWindows[0].splash = hitWindows[1].splash = true;
		hitWindows[3].breaksCombo = hitWindows[4].breaksCombo = hitWindows[5].breaksCombo = true;
		
		return hitWindows;
	}
	
	public override function judgeMiss(note:Note):Score {
		var miss:Score = super.judgeMiss(note);
		miss.score = -50;
		return miss;
	}
}

// legacy scoring system
class LegacyScoreSystem extends ScoreSystem {
	public function new() {
		super();
		name = 'Legacy';
		holdScoring = false;
	}
	
	public override function makeHitWindows():Array<HitWindow> {
		var hitWindows:Array<HitWindow> = [
			new HitWindow('sick', 	350, 	.2, 	1),
			new HitWindow('good', 	200, 	.75, 	1),
			new HitWindow('bad', 	100, 	.9, 	1),
			new HitWindow('shit', 	50, 	1,  	1)
		];
		hitWindows[0].splash = true;
		
		return hitWindows;
	}
}

// custom scoring system (scripting purposes)
class CustomScoreSystem extends ScoreSystem {
	public var customJudgeHit:Float -> Float -> Score = null;
	public var customJudgeMiss:Note -> Score = null;
	public var customJudgeGhost:Void -> Score = null;
	
	public function new(name:String = 'Custom', ?customHitWindows:Array<HitWindow>) {
		super();
		this.name = name;
		this.hitWindows = (customHitWindows ?? hitWindows);
	}
	
	public override function judgeHit(time:Float, range:Float):Score {
		if (customJudgeHit != null)
			return customJudgeHit(time, range);
		return super.judgeHit(time, range);
	}
	
	public override function judgeMiss(note:Note):Score {
		if (customJudgeMiss != null)
			return customJudgeMiss(note);
		return super.judgeMiss(note);
	}
	
	public override function judgeGhost():Score {
		if (customJudgeGhost != null)
			return customJudgeGhost();
		return super.judgeGhost();
	}
}

// default scoring system
class ScoreSystem {
	public static var safeFrames:Float = 10;
	
	public var name:String = 'Default';
	
	public var holdScoring:Bool = true;
	public var holdLeniencyMS:Float = 75;
	public var holdScorePerSecond:Float = 250;
	public var useMilliseconds:Bool = false;
	
	public var hitWindows:Array<HitWindow>;
	
	public function new() {
		hitWindows = makeHitWindows();
	}
	
	public function makeHitWindows():Array<HitWindow> {
		var hitWindows:Array<HitWindow> = [
			new HitWindow('sick', 	350, 	.2, 	1),
			new HitWindow('good', 	200, 	.75, 	.8),
			new HitWindow('bad', 	100, 	.9, 	.5),
			new HitWindow('shit', 	50, 	1,  	.2),
			new HitWindow('shit', 	0,		1,  	0) // HORRIBLE (key mashing)
		];
		hitWindows[0].splash = true;
		
		return hitWindows;
	}
	
	public function hitFromName(name:String):HitWindow {
		return Lambda.find(hitWindows, (window:HitWindow) -> window.rating == name);
	}
	
	public function hitFromTime(time:Float, range:Float):HitWindow {
		if (useMilliseconds) range = 1;
		
		for (window in hitWindows) {
			if (Math.abs(time) <= window.threshold * range)
				return window;
		}
		
		return hitWindows[hitWindows.length - 1];
	}
	
	public function judgeHit(time:Float, range:Float):Score {
		var hit:HitWindow = hitFromTime(time, range);
		
		return {
			hits: 1,
			hitWindow: hit,
			rating: hit.rating,
			healthMod: hit.healthMod,
			accuracyMod: hit.accuracyMod,
			breaksCombo: hit.breaksCombo,
			score: hit.score
		};
	}
	
	public function judgeMiss(note:Note):Score {
		return {
			score: -10,
			misses: 1,
			accuracyMod: 0,
			breaksCombo: true
		}
	}
	
	public function judgeGhost():Score {
		return {
			score: -10,
			healthMod: -.01
		}
	}
	
	public function toString():String {
		return 'ScoreSystem($name)';
	}
}

class HitWindow {
	public var count:Int;
	public var score:Float;
	public var rating:String;
	public var threshold:Float;
	public var healthMod:Float;
	public var accuracyMod:Float;
	public var splash:Bool = false;
	public var breaksCombo:Bool = false;
	
	public function new(rating:String, score:Float, threshold:Float, ratingMod:Float, healthMod:Float = 1) {
		this.count = 0;
		this.score = score;
		this.rating = rating;
		this.threshold = threshold;
		this.healthMod = healthMod;
		this.accuracyMod = ratingMod;
	}
	
	public function toString():String {
		return 'HitWindow($rating | ${Math.round(accuracyMod * 10000) / 100}%)';
	}
}

typedef Score = {
	var ?rating:String;
	var ?hitWindow:HitWindow;
	var ?accuracyMod:Float;
	var ?breaksCombo:Bool;
	var ?healthMod:Float;
	var ?score:Float;
	var ?misses:Int;
	var ?hits:Int;
}