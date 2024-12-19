import flixel.addons.display.FlxBackdrop;

var colorShader:RuntimeShader;
var mist1:FlxBackdrop;
var mist2:FlxBackdrop;
var mist3:FlxBackdrop;
var mist4:FlxBackdrop;
var mist5:FlxBackdrop;

var fastCarCanDrive:Bool = false;
var shootingStarOffset:Int = 2;
var shootingStarBeat:Int = 0;

function setupStage(id:String, stage:Stage) {
	Paths.sound('carPass0', 'week4');
	Paths.sound('carPass1', 'week4');
	
	// todo: whatever shader shit is in the base stage
	colorShader = new RuntimeShader('adjustColor');
	colorShader.setFloat('hue', -30);
	colorShader.setFloat('saturation', -20);
	colorShader.setFloat('brightness', -30);
	
	for (k => char in stage.characters)
		char.shader = colorShader;
	for (prop in ['limoDancer1', 'limoDancer2', 'limoDancer3', 'limoDancer4', 'limoDancer5', 'fastCar'])
		stage.props[prop].shader = colorShader;
	
	stage.add(mist1 = new FlxBackdrop(Paths.image('limo/erect/mistMid', 'week4'), FlxAxes.X));
	mist1.setPosition(-650, -100);
	mist1.scrollFactor.set(1.1, 1.1);
	mist1.zIndex = 400;
	mist1.blend = 0;
	mist1.color = 0xFFc6bfde;
	mist1.alpha = 0.4;
	mist1.velocity.x = 1700;
	
	stage.add(mist2 = new FlxBackdrop(Paths.image('limo/erect/mistBack', 'week4'), FlxAxes.X));
	mist2.setPosition(-650, -100);
	mist2.scrollFactor.set(1.2, 1.2);
	mist2.zIndex = 401;
	mist2.blend = 0;
	mist2.color = 0xFF6a4da1;
	mist2.velocity.x = 2100;
	mist1.scale.set(1.3, 1.3);
	
	stage.add(mist3 = new FlxBackdrop(Paths.image('limo/erect/mistMid', 'week4'), FlxAxes.X));
	mist3.scrollFactor.set(0.8, 0.8);
	mist3.setPosition(-650, -100);
   	mist3.blend = BlendMode.ADD;
	mist3.color = 0xFFa7d9be;
	mist3.zIndex = 99;
	mist3.alpha = 0.5;
	mist3.velocity.x = 900;
	mist3.scale.set(1.5, 1.5);
	
	stage.add(mist4 = new FlxBackdrop(Paths.image('limo/erect/mistBack', 'week4'), FlxAxes.X));
	mist4.scrollFactor.set(0.6, 0.6);
	mist4.setPosition(-650, -380);
	mist4.blend = BlendMode.ADD;
	mist4.color = 0xFF9c77c7;
	mist4.zIndex = 98;
	mist4.velocity.x = 700;
	mist4.scale.set(1.5, 1.5);
	
	stage.add(mist5 = new FlxBackdrop(Paths.image('limo/erect/mistMid', 'week4'), FlxAxes.X));
	mist5.scrollFactor.set(0.2, 0.2);
	mist5.setPosition(-650, -400);
   	mist5.blend = BlendMode.ADD;
	mist5.color = 0xFFE7A480;
	mist5.zIndex = 15;
	mist5.velocity.x = 100;
	mist5.scale.set(1.5, 1.5);
	
	stage.props['shootingStar'].blend = BlendMode.ADD;
	
	resetFastCar();
}

function stepHit()
	camGame.targetOffset.set(FlxG.random.float(-3, 3), FlxG.random.float(-3, 3));

function beatHit(beat:Int) {
	if (FlxG.random.bool(10) && fastCarCanDrive)
		fastCarDrive();
	
	if (FlxG.random.bool(10) && beat > shootingStarBeat + shootingStarOffset)
		doShootingStar(beat);
}

function update(elapsed:Float, paused:Bool, dead:Bool) {
	if (paused || dead) return;
	
	var _timer:Float = conductor.songPosition * .001;
	mist1.y = 100 + (Math.sin(_timer) * 200);
	mist2.y = 0 + (Math.sin(_timer * 0.8) * 100);
	mist3.y = -20 + (Math.sin(_timer * 0.5) * 200);
	mist4.y = -180 + (Math.sin(_timer * 0.4) * 300);
	mist5.y = -450 + (Math.sin(_timer * 0.2) * 150);
}

function resetFastCar() {
	var fastCar:StageProp = stage.props['fastCar'];
	if (fastCar == null)
		return;
	
	fastCar.active = true;

	fastCar.x = -12600;
	fastCar.y = FlxG.random.int(140, 250);
	fastCar.velocity.x = 0;
	fastCarCanDrive = true;
}

function fastCarDrive() {
	FlxG.sound.play(Paths.sound('carPass${FlxG.random.int(0, 1)}', 'week4'), .7);

	var fastCar:StageProp = stage.props['fastCar'];
	fastCar.velocity.x = (FlxG.random.int(170, 220) / FlxG.elapsed) * 3;
	fastCarCanDrive = false;
	new FlxTimer().start(2, () -> { resetFastCar(); });
}

function doShootingStar(beat:Int) {
	var shootingStar:StageProp = stage.props['shootingStar'];
	shootingStar.x = FlxG.random.int(50,900);
	shootingStar.y = FlxG.random.int(-10,20);
	shootingStar.flipX = FlxG.random.bool(50);
	shootingStar.playAnimation('shooting star');

	shootingStarBeat = beat;
	shootingStarOffset = FlxG.random.int(4, 8);
}