class Character extends FunkinSprite {
	public var sway:Bool = false;
	public var animReset:Float = 0;
	public var singForSteps:Float = 4;
	
	public function new(x:Float, y:Float, character:String = '') {
		super(x, y);
	}
	
	public override function update(elapsed:Float) {
		super.update(elapsed);
		if (animReset > 0) {
			animReset -= elapsed;
			if (animReset <= 0) {
				animReset = 0;
				dance(0);
			}
		}
	}
	
	public function timeAnimSteps(steps:Float) {
		animReset = steps * Conductor.stepCrochet * .001;
	}
	public override function playAnimation(anim:String, forced:Bool = false) {
		if (anim != 'idle' && (forced || (animation.exists(anim) && animation.name != anim))) timeAnimSteps(singForSteps);
		super.playAnimation(anim, forced);
	}
	public function dance(beat:Int) {
		if (animReset <= 0 && beat % 2 == 0) {
			playAnimation('idle');
		}
	}
}