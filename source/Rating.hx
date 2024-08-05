package;

class Rating extends FunkinSprite {
	public var rating:String;
	public var tween:FlxTween;
	
	public function new(x:Float = 0, y:Float = 0, path:String = 'sick', startDelay:Float = 1) {
		super(x, y);
		rating = path;
		loadTexture(path);
		offset.set(width * .5, height * .5);
		
		acceleration.y = 550;
		velocity.y = -FlxG.random.int(140, 175);
		velocity.x = FlxG.random.int(0, 10);
		
		tween = FlxTween.tween(this, {alpha: 0}, .2, {onComplete: (tween:FlxTween) -> { this.onComplete(tween); }, startDelay: startDelay});
	}
	
	//override if you need to remove it from a group, etc
	public dynamic function onComplete(tween:FlxTween) {
		destroy();
	}
}

class ComboNumber extends Rating {
	public function new(x:Float = 0, y: Float = 0, number:Int = 0, startDelay:Float = 1) {
		super(x, y, 'num${number}', startDelay);
		
		acceleration.y = FlxG.random.int(200, 300);
		velocity.y = -FlxG.random.int(140, 160);
		velocity.x = FlxG.random.float(-5, 5);
	}
}