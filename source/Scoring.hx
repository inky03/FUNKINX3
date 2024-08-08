package;

class Scoring {
	public static var safeFrames:Float = 10;
	
	public static function legacyDefault() {
		var windows:Array<HitWindow> = [
			new HitWindow('sick', 350, .3, 1),
			new HitWindow('good', 200, .6, .8, .75),
			new HitWindow('bad', 100, .9, .5, .5),
			new HitWindow('shit', 50, 1, .2, 0),
			new HitWindow('shit', 50, 1, .2, -.75) //HORRIBLE
		];
		windows[0].splash = true;
		windows[2].breaksCombo = true;
		windows[3].breaksCombo = true;
		windows[4].breaksCombo = true;
		
		return windows;
	}
	public static function emiDefault() {
		var windows = legacyDefault();
		windows.unshift(new HitWindow('killer', 500, .06, 1));
		windows[0].splash = true;
		
		return windows;
	}
	public static function judgeLegacy(windows:Array<HitWindow>, hitWindow:Float, time:Float) {
		for (window in windows) if (Math.abs(time) <= window.threshold * hitWindow) return window;
		return windows[windows.length - 1];
	}
}

class HitWindow {
	public var count:Int;
	public var score:Float;
	public var health:Float;
	public var rating:String;
	public var threshold:Float;
	public var accuracyMod:Float;
	public var splash:Bool = false;
	public var breaksCombo:Bool = false;
	
	public function new(rating:String, score:Float, threshold:Float, ratingMod:Float, health:Float = 1) {
		this.count = 0;
		this.score = score;
		this.health = health;
		this.rating = rating;
		this.threshold = threshold;
		this.accuracyMod = ratingMod;
	}
}