using StringTools;

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
				dance();
			}
		}
	}
	
	public function timeAnimSteps(steps:Float = 4) {
		animReset = steps * Conductor.stepCrochet * .001;
	}
	public override function playAnimation(anim:String, forced:Bool = false) {
		if (anim.startsWith('sing') && (animation.exists(anim) && (forced || animation.name != anim))) timeAnimSteps(singForSteps);
		super.playAnimation(anim, forced);
	}
	public function dance(beat:Int = 0) {
		if (animReset > 0) return false;
		if (sway)
			playAnimation(beat % 2 == 0 ? 'danceLeft' : 'danceRight');
		else if (beat % 2 == 0)
			playAnimation('idle');
		return true;
	}

	public function useDefault() {
		loadAtlas('characters/BOYFRIEND');
		animation.addByPrefix('idle', 'BF idle dance', 24, false);
		var singAnimations:Array<String> = ['LEFT', 'DOWN', 'UP', 'RIGHT'];
		for (ani in singAnimations) {
			animation.addByPrefix('sing${ani}', 'BF NOTE ${ani}0', 24, false);
			animation.addByPrefix('sing${ani}miss', 'BF NOTE ${ani} MISS', 24, false);
		}
		offsets.set('idle', FlxPoint.get(-5, 0));
		offsets.set('singLEFT', FlxPoint.get(5, -6));
		offsets.set('singDOWN', FlxPoint.get(-20, -51));
		offsets.set('singUP', FlxPoint.get(-46, 27));
		offsets.set('singRIGHT', FlxPoint.get(-48, -7));
		offsets.set('singLEFTmiss', FlxPoint.get(7, 19));
		offsets.set('singDOWNmiss', FlxPoint.get(-15, -19));
		offsets.set('singUPmiss', FlxPoint.get(-46, 27));
		offsets.set('singRIGHTmiss', FlxPoint.get(-44, 19));
		playAnimation('idle');
	}
}