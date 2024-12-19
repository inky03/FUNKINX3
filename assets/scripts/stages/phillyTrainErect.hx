var lightShader:RuntimeShader;
var colorShader:RuntimeShader;
var trainSound:FlxSound;
var lightColors:Array =[
	0xffb66f43,
	0xff329a6d,
	0xff932c28,
	0xff2663ac,
	0xff502d64
];

var trainMoving:Bool = false;
var trainFinishing:Bool = false;
var trainFrameTiming:Float = 0;
var trainCars:Int = 8;
var trainCooldown:Int = 0;

function createPost() {
	trainSound = new FlxSound().loadEmbedded(Paths.sound('train_passes', 'week3'));
	FlxG.sound.list.add(trainSound);

	lightShader = new RuntimeShader('building');
	lightShader.setFloat('alphaShit', 0);

	colorShader = new RuntimeShader('adjustColor');
	colorShader.setFloat('hue', -26);
	colorShader.setFloat('saturation', -16);
	colorShader.setFloat('contrast', 0);
	colorShader.setFloat('brightness', -5);

	var light:FunkinSprite = getNamedProp('lights');
	light.shader = lightShader;
	light.visible = false;

	getNamedProp('train').shader = colorShader;
	game.player1.shader = colorShader;
	game.player2.shader = colorShader;
	game.player3.shader = colorShader;
}

function update(elapsed:Float, paused:Bool){
	if (paused) return;
	var shaderInput:Float = (conductor.crochet / 1000) * elapsed * 1.5;
	lightShader.setFloat('alphaShit', lightShader.getFloat('alphaShit') + shaderInput);

	if (trainMoving)
	{
		trainFrameTiming += elapsed;

		if (trainFrameTiming >= 1 / 24)
		{
			updateTrainPos();
			trainFrameTiming = 0;
		}
	}
}

function beatHit(beat:Int){
	if (!trainMoving) trainCooldown += 1;

	if (beat % 8 == 4 && FlxG.random.bool(30) && !trainMoving && trainCooldown > 8) {
		trainCooldown = FlxG.random.int(-4, 0);
		trainStart();
	}

	if (beat % 4 == 0) {
		lightShader.setFloat('alphaShit', 0);

		var curLight:Int = FlxG.random.int(0, 4);
		getNamedProp('lights').visible = true;
		getNamedProp('lights').color = lightColors[curLight];
	}
}

function trainStart(){
	trainMoving = true;
	trainSound.play();
}

var startedMoving:Bool = false;

function updateTrainPos(){
	if (trainSound.time >= 4700){
		startedMoving = true;
		game.player3.playAnimationSteps('hairBlow', false, 4);
	}

	if (startedMoving){
		var train:FlxSprite = getNamedProp('train');
		train.x -= 400;

		if (train.x < -2000 && !trainFinishing)
		{
			train.x = -1150;
			trainCars -= 1;

			if (trainCars <= 0)
				trainFinishing = true;
		}

		if (train.x < -4000 && trainFinishing)
			trainReset();
	}
}

function trainReset(){
	game.player3.playAnimationSteps('hairFall', true, 4);
	game.player3.specialAnim = true;

	getNamedProp('train').x = FlxG.width + 200;
	trainMoving = false;
	trainCars = 8;
	trainFinishing = false;
	startedMoving = false;
}

function getNamedProp(name:String){
	var prop = stage.getProp(name);
	return prop;
}