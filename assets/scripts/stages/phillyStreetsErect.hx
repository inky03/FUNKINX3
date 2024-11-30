import flixel.math.FlxBasePoint;
import flixel.addons.display.FlxBackdrop;
import flixel.addons.display.FlxTiledSprite;

var scrollingSky:FlxTiledSprite;
var mist0:FlxBackdrop;
var mist1:FlxBackdrop;
var mist2:FlxBackdrop;
var mist3:FlxBackdrop;
var mist4:FlxBackdrop;
var mist5:FlxBackdrop;

var rainShader:RuntimeShader;
var colorShader:RuntimeShader;
var rainShaderStartIntensity:Float;
var rainShaderEndIntensity:Float;
var songLength:Float = 0;

var lightsStop:Bool = false;
var changeInterval:Int = 8;
var lastChange:Int = 0;

var carWaiting:Bool = false;
var carInterruptable:Bool = true;
var car2Interruptable:Bool = true;
var paperInterruptable:Bool = true;

function createPost() {
	resetCar(true, true);

	scrollingSky = new FlxTiledSprite(Paths.image('phillyStreets/erect/phillySkybox', 'weekend1'), 2922, 718, true, false);
	scrollingSky.setPosition(-650, -375);
	scrollingSky.scrollFactor.set(0.1, 0.1);
	scrollingSky.zIndex = 10;
	scrollingSky.scale.set(0.65, 0.65);
	stage.add(scrollingSky);

	rainShader = new RuntimeShader('rain');
	rainShader.setFloatArray('uScreenResolution', [FlxG.width, FlxG.height]);
	rainShader.setFloatArray('uCameraBounds', [0, 0, FlxG.width, FlxG.height]);
	game.camGame.filters = [new ShaderFilter(rainShader)];
	
	switch (PlayState.song.path) {
		case 'darnell':
			rainShaderStartIntensity = 0;
			rainShaderEndIntensity = .01;
		case 'lit-up':
			rainShaderStartIntensity = .01;
			rainShaderEndIntensity = .02;
		case '2hot':
			rainShaderStartIntensity = .02;
			rainShaderEndIntensity = .04;
	}
	songLength = PlayState.song.inst.length ?? 0;
	rainShader.setFloat('uScale', FlxG.height / 200);
	rainShader.setFloat('uIntensity', rainShaderStartIntensity);
	rainShader.setFloatArray('uRainColor', [0xa8 / 0xff, 0xad / 0xff, 0xb5 / 0xff]);

	colorShader = new RuntimeShader('adjustColor');
	colorShader.setFloat('hue', -5);
	colorShader.setFloat('saturation', -40);
	colorShader.setFloat('brightness', -20);
	colorShader.setFloat('contrast', -25);
	game.player1.shader = game.player2.shader = game.player3.shader = colorShader;

	mist0 = new FlxBackdrop(Paths.image('phillyStreets/erect/mistMid', 'weekend1'), FlxAxes.X);
	mist0.scrollFactor.set(1.2, 1.2);
	mist0.zIndex = 1000;
	mist0.alpha = .6;
	mist0.velocity.x = 172;
	stage.add(mist0);

	mist1 = new FlxBackdrop(Paths.image('phillyStreets/erect/mistMid', 'weekend1'), FlxAxes.X);
	mist1.scrollFactor.set(1.1, 1.1);
	mist1.zIndex = 1000;
	mist1.alpha = .6;
	mist1.velocity.x = 150;
	stage.add(mist1);
	
	mist2 = new FlxBackdrop(Paths.image('phillyStreets/erect/mistBack', 'weekend1'), FlxAxes.X);
	mist2.scrollFactor.set(1.2, 1.2);
	mist2.zIndex = 1001;
	mist2.alpha = .8;
	mist2.velocity.x = -80;
	stage.add(mist2);
	
	mist3 = new FlxBackdrop(Paths.image('phillyStreets/erect/mistMid', 'weekend1'), FlxAxes.X);
	mist3.scrollFactor.set(0.95, 0.95);
	mist3.zIndex = 99;
	mist3.alpha = .5;
	mist3.velocity.x = -50;
	mist3.scale.set(0.8, 0.8);
	stage.add(mist3);
	
	mist4 = new FlxBackdrop(Paths.image('phillyStreets/erect/mistBack', 'weekend1'), FlxAxes.X);
	mist4.scrollFactor.set(0.8, 0.8);
	mist4.zIndex = 88;
	mist4.alpha = 1;
	mist4.velocity.x = 40;
	mist4.scale.set(0.7, 0.7);
	stage.add(mist4);
	
	mist5 = new FlxBackdrop(Paths.image('phillyStreets/erect/mistMid', 'weekend1'), FlxAxes.X);
	mist5.scrollFactor.set(0.5, 0.5);
	mist5.zIndex = 39;
	mist5.alpha = 1;
	mist5.velocity.x = 20;
	mist5.scale.set(1.1, 1.1);

	for (mist in [mist0, mist1, mist2, mist3, mist4, mist5]) {
		mist.x = -650;
		mist.color = 0xff5c5c5c;
		mist.blend = BlendMode.ADD;
		stage.add(mist);
	}
	for (name => prop in stage.props) {
		if (!StringTools.endsWith(name, '_lightmap')) continue;
		prop.blend = BlendMode.ADD;
		prop.alpha = .6;
	}
	stage.getProp('grey1').blend = BlendMode.ADD;
	stage.getProp('grey2').blend = BlendMode.MULTIPLY;
	stage.getProp('phillyCars2').flipX = true;
	// flipX on animations is currently not implemented... setting on sprite

	stage.sortZIndex();
}

function update(elapsed, paused) {
	if (paused) return;

	var stupid:Float = 50;
	var time:Float = conductor.songPosition / 1000;
	mist0.y = 660 + (FlxMath.fastSin(time * .35) * 70) + stupid;
	mist1.y = 500 + (FlxMath.fastSin(time * .3) * 80) + stupid;
	mist2.y = 540 + (FlxMath.fastSin(time * .4) * 60) + stupid;
	mist3.y = 230 + (FlxMath.fastSin(time * .3) * 70) + stupid;
	mist4.y = 170 + (FlxMath.fastSin(time * .35) * 50) + stupid;
	mist5.y = -20 + (FlxMath.fastSin(time * .08) * 50) + stupid;

	var cam:FlxCamera = game.camGame;
	var rainIntensity:Float = FlxMath.remapToRange(conductor.songPosition, 0, songLength, rainShaderStartIntensity, rainShaderEndIntensity);
	rainShader.setFloatArray('uCameraBounds', [cam.viewLeft, cam.viewTop, cam.viewRight, cam.viewBottom]);
	rainShader.setFloat('uIntensity', rainIntensity);
	rainShader.setFloat('uTime', time);
}

function beatHit(beat) {
	var canChangeLights:Bool = (beat == (lastChange + changeInterval));

	if (FlxG.random.bool(10) && !canChangeLights && carInterruptable) {
		if(lightsStop == false)
			driveCar(stage.getProp('phillyCars'));
		else
			driveCarLights(stage.getProp('phillyCars'));
	}

	if (FlxG.random.bool(10) && !canChangeLights && car2Interruptable && !lightsStop)
		driveCarBack(stage.getProp('phillyCars2'));

	if (canChangeLights)
		changeLights(beat);

	if (FlxG.random.bool(0.6) && paperInterruptable)
		paperBlow();
}

function paperBlow() {
	trace('blowing thos paper');
	var paper = stage.getProp('paper');
	paper.alpha = 1;
	paper.playAnimation('paperBlow');
	paper.y = 608 + FlxG.random.float(-150,150);
	paperInterruptable = false;
	new FlxTimer().start(2, (_) -> {
		paperInterruptable = true;
		paper.alpha = 0;
	});
}

function changeLights(beat) {
	lastChange = beat;
	lightsStop = !lightsStop;

	if (lightsStop) {
		stage.getProp('phillyTraffic').animation.play('tored');
		changeInterval = 20;
	} else {
		stage.getProp('phillyTraffic').animation.play('togreen');
		changeInterval = 30;

		if (carWaiting == true)
			finishCarLights(stage.getProp('phillyCars'));
	}
}

function resetCar(left:Bool, right:Bool) {
	if (left) {
		carWaiting = false;
		carInterruptable = true;
		var cars = stage.getProp('phillyCars');
		if (cars != null) {
			FlxTween.cancelTweensOf(cars);
			cars.x = 1200;
			cars.y = 818;
			cars.angle = 0;
		}
	}

	if (right) {
		car2Interruptable = true;
		var cars2 = stage.getProp('phillyCars2');
		if (cars2 != null) {
			FlxTween.cancelTweensOf(cars2);
			cars2.x = 1200;
			cars2.y = 818;
			cars2.angle = 0;
		}
	}
}

function carVariantDuration(variant:Int) {
	// set different values of speed for the car types
	return switch (variant) {
		case 1: FlxG.random.float(1, 1.7);
		case 2: FlxG.random.float(0.6, 1.2);
		case 3: FlxG.random.float(1.5, 2.5);
		case 4: FlxG.random.float(1.5, 2.5);
		default: 2;
	}
}

function driveCar(sprite:FlxSprite) {
	carInterruptable = false;
	FlxTween.cancelTweensOf(sprite);

	var variant:Int = FlxG.random.int(1,4);
	sprite.playAnimation('car' + variant);

	// random arbitrary values for getting the cars in place
	// could just add them to the points but im LAZY!!!!!!
	var offset:Array<Float> = [306.6, 168.3];
	// start/end rotation
	var rotations:Array<Int> = [-8, 18];
	// the path to move the car on
	var path:Array<FlxBasePoint> = [
		FlxBasePoint.get(1570 - offset[0], 1049 - offset[1] - 30),
		FlxBasePoint.get(2400 - offset[0], 980 - offset[1] - 50),
		FlxBasePoint.get(3102 - offset[0], 1127 - offset[1] + 40)
	];

	var duration:Float = carVariantDuration(variant);
	FlxTween.angle(sprite, rotations[0], rotations[1], duration, null);
	FlxTween.quadPath(sprite, path, duration, true, {
		onComplete: (_) -> { carInterruptable = true; }
	});
}

function driveCarBack(sprite:FlxSprite) {
	car2Interruptable = false;
	FlxTween.cancelTweensOf(sprite);

	var variant:Int = FlxG.random.int(1,4);
	sprite.playAnimation('car' + variant);

	var offset:Array<Float> = [306.6, 168.3];
	var rotations:Array<Int> = [18, -8];
	
	var path:Array<FlxBasePoint> = [
		FlxBasePoint.get(3102 - offset[0], 1127 - offset[1] + 60),
		FlxBasePoint.get(2400 - offset[0], 980 - offset[1] - 30),
		FlxBasePoint.get(1570 - offset[0], 1049 - offset[1] - 10)
	];

	var duration:Float = carVariantDuration(variant);
	FlxTween.angle(sprite, rotations[0], rotations[1], duration);
	FlxTween.quadPath(sprite, path, duration, true, {
		onComplete: (_) -> { car2Interruptable = true; }
	});
}

function driveCarLights(sprite:FlxSprite) {
	carInterruptable = false;
	FlxTween.cancelTweensOf(sprite);

	var variant:Int = FlxG.random.int(1,4);
	sprite.playAnimation('car' + variant);

	var rotations:Array<Int> = [-7, -5];
	var offset:Array<Float> = [306.6, 168.3];

	var path:Array<FlxBasePoint> = [
		FlxBasePoint.get(1500 - offset[0] - 20, 1049 - offset[1] - 20),
		FlxBasePoint.get(1770 - offset[0] - 80, 994 - offset[1] + 10),
		FlxBasePoint.get(1950 - offset[0] - 80, 980 - offset[1] + 15)
	];

	var duration:Float = carVariantDuration(variant);
	FlxTween.angle(sprite, rotations[0], rotations[1], duration, {ease: FlxEase.cubeOut});
	FlxTween.quadPath(sprite, path, duration, true, {
		ease: FlxEase.cubeOut,
		onComplete: (_) -> {
			carWaiting = true;
			if (lightsStop == false) finishCarLights(sprite);
		}
    });
}

function finishCarLights(sprite:FlxSprite) {
	carWaiting = false;
	var duration:Float = FlxG.random.float(1.8, 3);
	var rotations:Array<Int> = [-5, 18];
	var offset:Array<Float> = [306.6, 168.3];
	var startdelay:Float = FlxG.random.float(0.2, 1.2);

	var path:Array<FlxBasePoint> = [
		FlxBasePoint.get(1950 - offset[0] - 80, 980 - offset[1] + 15),
		FlxBasePoint.get(2400 - offset[0], 980 - offset[1] - 50),
		FlxBasePoint.get(3102 - offset[0], 1127 - offset[1] + 40)
	];

	FlxTween.angle(sprite, rotations[0], rotations[1], duration, {ease: FlxEase.sineIn, startDelay: startdelay});
	FlxTween.quadPath(sprite, path, duration, true, {
		ease: FlxEase.sineIn,
		startDelay: startdelay,
		onComplete: (_) -> { carInterruptable = true; }
	});
}