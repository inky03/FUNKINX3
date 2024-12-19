import flixel.group.FlxTypedSpriteGroup;
import flixel.effects.FlxFlicker;
import Type;

var explosiveCans:Bool = false;
function opponentNoteEventPre(e:NoteEvent) {
	var note:Note = e.note;
	if (note == null) return;
	
	var noteKind:String = e.note.noteKind;
	if (!StringTools.startsWith(noteKind, 'weekend-1')) return;
	
	switch (e.type) {
		case NoteEventType.SPAWNED:
			note.visible = false;
			var msTime:Float = e.note.msTime;
			switch (noteKind) {
				case "weekend-1-lightcan":
					if (explosiveCans)
						scheduleSound(Paths.sound('Darnell_Lighter', 'weekend1'), msTime - 65);
				case "weekend-1-kickcan":
					scheduleSound(Paths.sound('Kick_Can_UP', 'weekend1'), msTime - 50);
				case "weekend-1-kneecan":
					scheduleSound(Paths.sound('Kick_Can_FORWARD', 'weekend1'), msTime - 22);
			}
		case NoteEventType.HIT:
			var darn:Character = e.targetCharacter;
			e.animateReceptor = false;
			e.playAnimation = false;
			switch (noteKind) {
				case 'weekend-1-lightcan':
					if (explosiveCans) {
						darn.playAnimation('lightCan', true);
						darn.specialAnim = true;
					}
				case 'weekend-1-kickcan':
					darn.playAnimation('kickCan', true);
					darn.specialAnim = true;
					spawnCan();
				case 'weekend-1-kneecan':
					darn.playAnimation('kneeCan', true);
			}
		default:
	}
}

var deathByCan:Bool = false;
var gunCocked:Bool = false;
function playerNoteEventPre(e:NoteEvent) {
	switch (e.type) {
		case NoteEventType.HIT:
			switch (e.note.noteKind) {
				case 'weekend-1-cockgun':
					e.playAnimation = false;
					gunCocked = true;
				case 'weekend-1-firegun':
					if (!gunCocked) {
						e.cancel();
						e.note.goodHit = false;
					}
					e.playAnimation = false;
			}
		case NoteEventType.LOST:
			if (e.note.noteKind == 'weekend-1-firegun') {
				e.playAnimation = false;
				switch (PlayState.song.difficulty) {
					case 'hard':
						e.note.healthLoss = .45;
					case 'normal':
						e.note.healthLoss = .25;
					default:
				}
				if (health - e.note.healthLoss <= 0)
					deathByCan = true;
				gunCocked = false;
			}
		default:
	}
}
function playerNoteEvent(e:NoteEvent) {
	var note:Note = e.note;
	if (note == null || e.cancelled) return;
	
	var noteKind:String = e.note.noteKind;
	if (!StringTools.startsWith(noteKind, 'weekend-1')) return;
	
	var pico:Character = e.targetCharacter;
	switch (e.type) {
		case NoteEventType.HIT:
			switch (noteKind) {
				case 'weekend-1-cockgun':
					FlxG.sound.play(Paths.sound('Gun_Prep', 'weekend1'));
					pico.playAnimation('cock', true);
					pico.specialAnim = true;
					makePicoFade(pico);
				case 'weekend-1-firegun':
					FlxG.sound.play(Paths.sound('shot${FlxG.random.int(1, 4)}', 'weekend1'));
					pico.playAnimation('shoot', true);
					pico.specialAnim = true;
					shootNextCan(pico);
				default:
			}
		case NoteEventType.LOST:
			switch (noteKind) {
				case 'weekend-1-firegun':
					FlxG.sound.play(Paths.sound('Pico_Bonk', 'weekend1'));
					pico.playAnimation('shootMISS', true);
					pico.specialAnim = true;
					missNextCan(pico);
				default:
			}
		default:
	}
}

for (i in 1...5) Paths.sound('shot$i', 'weekend1');
Paths.sound('Pico_Bonk', 'weekend1');
Paths.sound('Kick_Can_UP', 'weekend1');
Paths.sound('Darnell_Lighter', 'weekend1');
Paths.sound('Kick_Can_FORWARD', 'weekend1');
Paths.sparrowAtlas('PicoBullet', 'weekend1');
Paths.sparrowAtlas('CanImpactParticle', 'weekend1');
Paths.sparrowAtlas('spraypaintExplosionEZ', 'weekend1');
FunkinAnimate.cacheAnimate('spraycanAtlas', 'weekend1');
var scheduledSounds:Array<Dynamic> = [];

var picoFade:FlxSprite = new FlxSprite();
var sprayCans:FlxTypedGroup = new FlxSpriteGroup();
var casingGroup:FlxSpriteGroup = new FlxSpriteGroup();

function scheduleSound(snd:Sound, time:Float) {
	if (snd == null) return;
	
	var snd:FlxSound = FunkinSound.load(snd);
	scheduledSounds.push({sound: snd, targetTime: time});
}
function updatePost() {
	while (scheduledSounds.length > 0 && scheduledSounds[0].targetTime < conductorInUse.songPosition) {
		var info:Dynamic = scheduledSounds.shift();
		info.sound.play();
	}
}
function setupStage(stageId:String, stage:Stage) {
	sprayCans.zIndex = stage.getProp('spraycanPile').zIndex - 1;
	casingGroup.zIndex = 1900;
	stage.add(casingGroup);
	stage.add(sprayCans);
	stage.add(picoFade);
}
function createPost() {
	switch (PlayState.song.difficulty) {
		case 'hard', 'normal':
			explosiveCans = true;
		default:
	}
	
	casingGroup.x = player1.x + 250;
	casingGroup.y = player1.y + 100;
	player1.preloadAnimAsset('cock');
	player1.preloadAnimAsset('shoot');
	player1.preloadAnimAsset('shootMISS');
	player1.onAnimationFrame.add((frame:Int) -> { picoFrame(player1, frame); });
	player1.onAnimationComplete.add((anim:String) -> { picoAnim(player1, anim); });
}
function picoFrame(pico:Character, frame:Int) {
	if (pico.currentAnimation == "cock" && frame == 3)
		spawnCasing();
}
function picoAnim(pico:Character, anim:String) {
	if (deathByCan) return;
	
	if (anim == 'shootMISS') {
		picoFlicker = FlxFlicker.flicker(pico, 1, 1 / 30, true, true, (_) -> {
			picoFlicker = FlxFlicker.flicker(pico, 0.5, 1 / 60, true, true, (_) -> { picoFlicker = null; });
		});
	}
}
function makePicoFade(chara:Character) {
	picoFade.zIndex = chara.zIndex - 3;
	picoFade.frames = chara.frames;
	picoFade.frame = chara.frame;
	picoFade.scale.set(1, 1);
	picoFade.updateHitbox();
	picoFade.x = chara.x;
	picoFade.y = chara.y;
	picoFade.alpha = .3;
	stage.sortZIndex();
	FlxTween.cancelTweensOf(picoFade);
	FlxTween.cancelTweensOf(picoFade.scale);
	FlxTween.tween(picoFade.scale, {x: 1.3, y: 1.3}, .4);
	FlxTween.tween(picoFade, {alpha: 0}, .4);
}

var CAN_ARCING:Int = 0;
var CAN_BLOCKED:Int = 1;
var CAN_IMPACTED:Int = 2;

function spawnCasing() {
	var casing:FunkinSprite = new FunkinSprite().loadAtlas('PicoBullet', 'weekend1');
	casing.addAnimation('idle', 'Bullet');
	casing.addAnimation('pop', 'Pop');
	casing.playAnimation('pop');
	casing.onAnimationFrame.add((frame:Int) -> {
		if (casing.currentAnimation == 'pop' && frame >= 40)
			startCasingRoll(casing);
	});
	casingGroup.add(casing);
}
function startCasingRoll(casing:FunkinSprite) {
	casing.x = casing.x + casing.frame.offset.x - 1;
	casing.y = casing.y + casing.frame.offset.y + 1;

	casing.angle = 125.1;
	
	var randomFactorA = FlxG.random.float(3, 10);
	var randomFactorB = FlxG.random.float(1.0, 2.0);
	casing.angularVelocity = 100;
	casing.velocity.x = 20 * randomFactorB;
	casing.drag.x = randomFactorA * randomFactorB;
	casing.angularDrag = (casing.drag.x / casing.velocity.x) * 100;
	
	casing.playAnimation('idle');
}
function spawnCan() {
	var spraycanPile:StageProp = stage.getProp('spraycanPile');
	var can:FunkinSprite = new FunkinSprite().loadAnimate('spraycanAtlas', 'weekend1');
	can.addAnimation('start', 'Can Start');
	can.addAnimation('shot', 'Can Shot');
	can.addAnimation('hit', 'Hit Pico');
	can.playAnimation('start', true);
	can.onAnimationComplete.add((anim:String) -> {
		if (anim == 'shot' || anim == 'hit') {
			sprayCans.remove(can, true);
			can.destroy();
		} else if (anim == 'start') {
			can.playAnimation('hit', true);
		}
	});
	
	can.extraData['state'] = CAN_ARCING;
	can.x = spraycanPile.x + 560;
	can.y = spraycanPile.y - 140;
	sprayCans.add(can);
}
function getNextCan(?state:Int = CAN_ARCING) {
	for (can in sprayCans.members) {
		if (can.state == state)
			return can;
	}
	return null;
}
function shootNextCan(pico:Character) {
	var can:FunkinSprite = getNextCan();
	if (can != null) {
		can.extraData['state'] = CAN_BLOCKED;
		can.playAnimation('shot');
	}
	new FlxTimer().start(1 / 24, (_) -> { darkenStage(); });
}
function missNextCan(pico:Character) {
	var can:FunkinSprite = getNextCan();
	if (can != null) {
		can.extraData['state'] = CAN_IMPACTED;
		
		if (explosiveCans) {
			var explodeEZ:FunkinSprite = new FunkinSprite().loadAtlas('spraypaintExplosionEZ', 'weekend1');
			explodeEZ.addAnimation('idle', 'explosion round 1 short', 24, false);
			explodeEZ.playAnimation('idle');
			explodeEZ.setPosition(pico.x - 340, pico.y - 300);
			stage.add(explodeEZ);
			
			explodeEZ.onAnimationComplete.add((anim:String) -> {
				stage.remove(explodeEZ);
				explodeEZ.kill();
			});
		}
	}
	camGame.shake(.02, .1);
}
function darkenStage() {
	for (prop in stage.props) {
		prop.color = 0xff111111;
		new FlxTimer().start(1 / 24, (_) -> {
			prop.color = 0xff222222;
			FlxTween.color(prop, 1.4, 0xff222222, 0xffffffff);
		});
	}
}

var singed:FlxSound;
var picoDeath:FunkinSprite;
function death(instant:Bool, gameOver:GameOverSubState) {
	if (deathByCan) {
		gameOver.soundPath = 'gameplay/gameOver/gameOverStart-pico-explode';
		gameOver.startMusicPath = 'gameplay/gameOver/gameOverStart-pico-explode';
		gameOver.deathAnimationPostfix = 'Explosion';
		
		if (!instant) {
			for (can in sprayCans.members) {
				can.anim.timeScale = 0;
			}
			player1.animation.timeScale = 0;
			FlxTween.shake(player1, .1, .3, FlxAxes.X, {onUpdate: (t) -> {
				player1.spriteOffset.x = player1.animOffset.x + FlxG.random.float(-75, 75) * (1 - FlxEase.elasticInOut(t.percent));
			}, onComplete: (t) -> {
				player1.spriteOffset.x = player1.animOffset.x;
				player1.spriteOffset.y = player1.animOffset.y;
			}});
		}
	}
}
function deathCreate(instant:Bool, gameOver:GameOverSubState) {
	if (!deathByCan) return;
	
	player1.animation.timeScale = 1;
	picoDeath = new FunkinSprite(player1.x + 270, player1.y + 170).loadAnimate('characters/picoExplosionDeath', 'weekend1');
	picoDeath.addAnimation('loop', 'Loop Start', 24, true);
	picoDeath.addAnimation('confirm', 'Confirm');
	picoDeath.addAnimation('intro', 'intro');
	picoDeath.playAnimation('intro');
	picoDeath.updateHitbox();
	picoDeath.onAnimationComplete.add((anim:String) -> {
		if (anim == 'intro')
			picoDeath.playAnimation('loop');
	});
	gameOver.remove(player1);
	gameOver.add(picoDeath);
	
	singed = new FlxSound().loadEmbedded(Paths.sound('singed_loop', 'weekend1'));
	FlxG.sound.list.add(singed);
	singed.looped = true;
	new FlxTimer().start(3, (_) -> {
		gameOver.startGameOver();
		if (singed != null)
			singed.play();
	});
}
function deathConfirm() {
	if (!deathByCan) return;
	
	picoDeath.playAnimation('confirm');
	if (singed != null) {
		singed.stop();
		singed = null;
	}
}