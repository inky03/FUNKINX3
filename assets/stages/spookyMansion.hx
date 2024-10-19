var thunderSound1:FlxSound;
var thunderSound2:FlxSound;
var lightningStrikeBeat:Int = 0;
var lightningStrikeOffset:Int = 8;

var boyfriend = game.player1;
var girlfriend = game.player2;
function create() {
    thunderSound1 = new flixel.sound.FlxSound().loadEmbedded(Paths.sound('thunder_1', 'week2'));
	FlxG.sound.list.add(thunderSound1);
    thunderSound2 = new flixel.sound.FlxSound().loadEmbedded(Paths.sound('thunder_', 'week2'));
	FlxG.sound.list.add(thunderSound2);
}

function beatHit(beat:Int){
		if (beat == 4 && game.song.name == "spookeez")
            doLightningStrike(false, beat);

		if (FlxG.random.bool(10) && beat > (lightningStrikeBeat + lightningStrikeOffset))
            doLightningStrike(true, beat);
	}

function doLightningStrike(playSound:Bool, beat:Int):Void{
	if (playSound)
	{
        if(FlxG.random.bool(2)){
            thunderSound2.play(true);
        }else{
            thunderSound1.play(true);
        }
	}

	getNamedProp('halloweenBG').animation.play('lightning');

	lightningStrikeBeat = beat;
	lightningStrikeOffset = FlxG.random.int(8, 24);

	if (boyfriend.animationList.exists('scared')) {
		boyfriend.playAnimation('scared', true);
	}

	if (girlfriend.animationList.exists('scared')) {
		girlfriend.playAnimation('scared', true);
	}
}

function getNamedProp(name:String){
    var prop = game.stage.getProp(name);
    return prop;
}