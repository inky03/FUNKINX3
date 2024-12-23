package funkin.backend.play;

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
}