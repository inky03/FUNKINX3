import funkin.backend.MusicHandler;
import funkin.backend.DiscordRPC;

using StringTools;

var lightShader:RuntimeShader;
var colorShader:RuntimeShader;
var trainSound:FlxSound;
var lightColors:Array = [
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

var bloodPool:FunkinSprite;
var inCutscene:Bool = false;
var playerExploded:Bool = false;

var cutsceneConductor:Conductor = null;

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
	
	if (player1.character.startsWith('pico') && player2.character.startsWith('pico')) {
		conductorInUse.paused = true;
		inCutscene = true;
		picoCutscene();
	}
}
function picoCutscene() {
	DiscordRPC.state = 'Watching cutscene';
	autoUpdateRPC = false;
	pauseDisabled = true;
	
	cutsceneConductor = new Conductor();
	MusicHandler.applyMeta(cutsceneConductor, MusicHandler.loadMeta('cutscene'));
	cutsceneConductor.beatHit.add((beat:Int) -> {
		if (player3 != null)
			player3.dance(beat);
	});
	player3.dance(0);
	
	var cutsceneMusic:FunkinSound;
	var explode:Bool = FlxG.random.bool(8);
	var playerShoots:Bool = FlxG.random.bool(50);
	setupPicoSprite(player1, 'Player', playerShoots, explode);
	setupPicoSprite(player2, 'Opponent', !playerShoots, explode).x += 35;
	camFocusTarget.y = player2.current.getMidpoint().y + player2.stageCameraOffset.y;
	
	var cigGuy:CharacterGroup = (playerShoots ? player2 : player1);
	var shootGuy:CharacterGroup = (playerShoots ? player1 : player2);
	
	// cutsceneTimerManager my nuts
	camGame.pauseFollowLerp = false;
	new FlxTimer().start(4, (_) -> focusOnCharacter(cigGuy.current));
	new FlxTimer().start(6.3, (_) -> focusOnCharacter(shootGuy.current));
	new FlxTimer().start(8.75, (_) -> {
		focusOnCharacter(cigGuy.current);
		if (explode && player3 != null)
			player3.playAnimation('drop70', true);
	});
	
	if (explode) {
		cutsceneMusic = FunkinSound.load(Paths.music('cutscene/cutscene2', 'week3'), true);
		
		bloodPool = new FunkinSprite().loadAnimate('philly/erect/bloodPool', 'week3');
		bloodPool.onAnimationComplete.addOnce((_) -> bloodPool.setVar('element', bloodPool.anim.curSymbol.getElement(0)));
		bloodPool.addAnimation('pool', 'poolAnim');
		bloodPool.zIndex = cigGuy.zIndex - 2;
		bloodPool.visible = false;
		stage.insertZIndex(bloodPool);
		
		new FlxTimer().start(11.2, (_) -> {
			if (explode) {
				bloodPool.playAnimation('pool');
				bloodPool.visible = true;
			}
		});
		
		bloodPool.y += 235;
		if (playerShoots) {
			player2.volume = 0;
			opponentStrumline.cpu = false;
			bloodPool.shader = player2.shader;
			bloodPool.x = player2.current.x - 1485;
		} else {
			bloodPool.shader = player1.shader;
			bloodPool.x = player1.current.x - 800;
		}
	} else {
		cutsceneMusic = FunkinSound.load(Paths.music('cutscene/cutscene', 'week3'), true);
		
		var cigarette:FunkinSprite = new FunkinSprite().loadAtlas('philly/erect/cigarette', 'week3');
		cigarette.addAnimation('spit', 'cigarette spit');
		cigarette.zIndex = cigGuy.zIndex + 5;
		cigarette.shader = cigGuy.shader;
		cigarette.visible = false;
		
		cigarette.setPosition(cigGuy.x, cigGuy.y - 270);
		
		if (playerShoots) {
			cigarette.flipX = true;
			cigarette.x += 185;
		} else {
			cigarette.x -= cigarette.frameWidth + 185;
		}
		
		stage.add(cigarette);
		
		new FlxTimer().start(11.5, (_) -> {
			cigarette.playAnimation('spit');
			cigarette.visible = true;
			new FlxTimer().start(.15, (_) -> {
				cigarette.zIndex = shootGuy.zIndex - 5;
				stage.sortZIndex();
			});
		});
	}
	
	player3.conductorInUse = cutsceneConductor;
	cutsceneConductor.syncTracker = cutsceneMusic;
	cutsceneMusic.play();
	stage.sortZIndex();
	
	FunkinSound.playOnce(Paths.sound('cutscene/picoGasp', 'week3'), 1);
	
	new FlxTimer().start(12, (_) -> {
		if (!explode || playerShoots) {
			player3.conductorInUse = conductorInUse;
			conductorInUse.paused = false;
			cutsceneMusic.fadeOut(0.5, 0);
			cutsceneConductor = null;
			
			autoUpdateRPC = true;
			refreshRPCDetails();
			
			new FlxTimer().start(1, (_) -> {
				inCutscene = false;
				pauseDisabled = false;
				cutsceneMusic.stop();
					
				for (chara in stage.characters) {
					if (chara.current.getVar('dead') == true) continue;
					
					var picoSprite:FunkinSprite = chara.current.getVar('picoSprite');
					if (picoSprite != null) {
						chara.current.extraData.remove('picoSprite');
						picoSprite.destroy();
					}
					chara.visible = true;
				}
			});
		} else {
			new FlxTimer().start(1, (_) -> camHUD.fade(FlxColor.BLACK, 1, false, null, true));
			new FlxTimer().start(2, (_) -> game.finishSong());
		}
	});
}
function setupPicoSprite(chara:CharacterGroup, suffix:String, shoots:Bool, willExplode:Bool) {
	var picoSprite:FunkinSprite = new FunkinSprite().loadAnimate('philly/erect/pico_doppleganger', 'week3');
	var anim:String = 'cigarette';
	if (shoots) {
		anim = 'shoot';
		
		new FlxTimer().start(6.29, (_) -> FunkinSound.load(Paths.sound('cutscene/picoShoot', 'week3'), 1, false, true, true));
		new FlxTimer().start(10.33, (_) -> FunkinSound.load(Paths.sound('cutscene/picoSpin', 'week3'), 1, false, true, true));
	} else if (willExplode) {
		anim = 'explode';
		chara.current.setVar('dead', true);
		picoSprite.addAnimation('dead-loop', 'loop$suffix', 24, true);
		
		new FlxTimer().start(3.7, (_) -> FunkinSound.load(Paths.sound('cutscene/picoCigarette2', 'week3'), 1, false, true, true));
        new FlxTimer().start(8.75, (_) -> {
        	FunkinSound.load(Paths.sound('cutscene/picoExplode', 'week3'), 1, false, true, true);
        	if (chara == player1) {
        		DiscordRPC.state = 'Genius!';
        		playerExploded = true;
        		health = 0;
        	}
        	if (player3 != null) {
        		player3.playAnimation('drop70', true);
        		player3.specialAnim = true;
        	}
        });
	} else {
		new FlxTimer().start(3.7, (_) -> FunkinSound.load(Paths.sound('cutscene/picoCigarette', 'week3'), 1, false, true, true));
	}
	
	picoSprite.addAnimation(anim, '$anim$suffix');
	picoSprite.playAnimation(anim);
	picoSprite.shader = chara.shader;
	picoSprite.setPosition(chara.current.x + 48, chara.current.y + 400);
	picoSprite.zIndex = chara.zIndex;
	stage.add(picoSprite);
	chara.visible = false;
	chara.current.setVar('picoSprite', picoSprite);
	
	picoSprite.onAnimationComplete.add((name:String) -> {
		if (name == 'explode')
			picoSprite.playAnimation('dead-loop');
	});
	
	return picoSprite;
}
function deathPre() {
	if (inCutscene || playerExploded)
		return STOP;
}

function update(elapsed:Float, paused:Bool) {
	if (paused) return;
	
	if (cutsceneConductor != null)
		cutsceneConductor.update(elapsed);
	
	var shaderInput:Float = (conductor.crochet / 1000) * elapsed * 1.5;
	lightShader.setFloat('alphaShit', lightShader.getFloat('alphaShit') + shaderInput);

	if (trainMoving) {
		trainFrameTiming += elapsed;

		if (trainFrameTiming >= 1 / 24) {
			updateTrainPos();
			trainFrameTiming = 0;
		}
	}
}
function updatePost(elapsed:Float, paused:Bool) {
	if (paused) return;
	
	if (bloodPool != null && bloodPool.getVar('element') != null) {
		var val:Float = .02 * elapsed;
		var el = bloodPool.getVar('element');
		var mat = el.matrix;
		
		// TODO: use origin instead of this shit
		mat.a += val;
		mat.d += val;
		bloodPool.offset.y += val * 620;
		bloodPool.offset.x += val * 1350; // no one gaf
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