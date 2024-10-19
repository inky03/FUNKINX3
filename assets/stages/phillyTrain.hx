var lights:Int = 5;
var lightShader:RuntimeShader;
var lightColors:Array =[
	0xfffba633,
	0xff31a2fd,
	0xff31fd8c,
	0xfffb33f5,
	0xfffd4531
];

var trainSound:FlxSound;
var trainMoving:Bool = false;
var trainFinishing:Bool = false;
var trainFrameTiming:Float = 0;
var trainCars:Int = 8;
var trainCooldown:Int = 0;

function createPost() {
	trainSound = new flixel.sound.FlxSound().loadEmbedded(Paths.sound('train_passes', 'week3'));
	FlxG.sound.list.add(trainSound);

    lightShader = new RuntimeShader('building');
    lightShader.setFloat('alphaShit', 0.0);

	var light:FlxSprite = getNamedProp('lights');
	light.shader = lightShader;
	light.visible = false;
}

function update(elapsed:Float, paused:Bool){
	if (paused) return;
	var shaderInput:Float = (Conductor.crochet / 1000) * elapsed * 1.5;
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

	if (beat % 8 == 4 && FlxG.random.bool(30) && !trainMoving && trainCooldown > 8){
		trainCooldown = FlxG.random.int(-4, 0);
		trainStart();
	}

	if (beat % 4 == 0){
		getNamedProp('lights').visible = true;
		lightShader.setFloat('alphaShit', 0.0);

		curLight = FlxG.random.int(0, 4);
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
        game.player3.playAnimation('hairBlow');
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
	game.player3.playAnimation('hairFall');
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