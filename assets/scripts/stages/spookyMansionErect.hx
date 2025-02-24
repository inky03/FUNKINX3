using StringTools;

var lightningStrikeBeat:Int = 0;
var lightningStrikeOffset:Int = 8;

Paths.sound('thunder_1', 'week2');
Paths.sound('thunder_2', 'week2');

// TODO: reimplement the rain shader (its heavily modified and thus doesn't really work with sprites... oops!)
function createPost() {
	for (chara in stage.characters) 
		chara.current.setVar('light', 0);
	flashCharacters(0);
}

function setupStage(id:String, stage:Stage) {
	getNamedProp('bgLight').alpha = 0;
	getNamedProp('stairsLight').alpha = 0;
}

function beatHit(beat:Int) {
	if (beat == 4 && PlayState.chart.name.toLowerCase() == 'spookeez erect')
		doLightningStrike(false, beat);

	if (FlxG.random.bool(10) && beat > (lightningStrikeBeat + lightningStrikeOffset))
		doLightningStrike(true, beat);
}

function flashCharacters(alpha:Float, ?duration:Float = 0) {
	for (chara in stage.characters) {
		if (duration > 0) {
			FlxTween.num(chara.current.getVar('light') ?? 0, alpha, duration, null, (p:Float) -> chara.current.setVar('light', p));
		} else {
			chara.current.setVar('light', alpha);
		}
	}
}
function doLightningStrike(playSound:Bool, beat:Int) {
	if (playSound)
		FlxG.sound.play(Paths.sound('thunder_${FlxG.random.int(1, 2)}', 'week2'));
	
	getNamedProp('bgLight').alpha = getNamedProp('stairsLight').alpha = 1;
	flashCharacters(1);
	
	new FlxTimer().start(.06, (_) -> {
		getNamedProp('bgLight').alpha = getNamedProp('stairsLight').alpha = 0;
		flashCharacters(0);
	});
	new FlxTimer().start(.12, (_) -> {
		flashCharacters(1);
		getNamedProp('bgLight').alpha = getNamedProp('stairsLight').alpha = 1;
	    FlxTween.tween(getNamedProp('stairsLight'), {alpha: 0}, 1.5);
		FlxTween.tween(getNamedProp('bgLight'), {alpha: 0}, 1.5);
		flashCharacters(0, 1.5);
	});
	
	lightningStrikeBeat = beat;
	lightningStrikeOffset = FlxG.random.int(8, 24);
	
	for (chara in stage.characters)
		chara.playAnimationSteps('scared', true, 8);
}

function getNamedProp(name:String) {
	var prop = stage.getProp(name);
	return prop;
}