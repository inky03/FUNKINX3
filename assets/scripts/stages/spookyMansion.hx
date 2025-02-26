var lightningStrikeBeat:Int = 0;
var lightningStrikeOffset:Int = 8;

Paths.sound('thunder_1', 'week2');
Paths.sound('thunder_2', 'week2');

function beatHit(beat:Int) {
	if (beat == 4 && PlayState.chart.name.toLowerCase() == 'spookeez')
		doLightningStrike(false, beat);

	if (FlxG.random.bool(10) && beat > (lightningStrikeBeat + lightningStrikeOffset))
		doLightningStrike(true, beat);
}

function doLightningStrike(playSound:Bool, beat:Int) {
	if (playSound)
		FlxG.sound.play(Paths.sound('thunder_${FlxG.random.int(1, 2)}', 'week2'));

	getNamedProp('halloweenBG').animation.play('lightning');

	lightningStrikeBeat = beat;
	lightningStrikeOffset = FlxG.random.int(8, 24);

	for (chara in stage.characters)
		chara.playAnimationSteps('scared', true, 8);
}

function getNamedProp(name:String) {
	var prop = stage.getProp(name);
	return prop;
}