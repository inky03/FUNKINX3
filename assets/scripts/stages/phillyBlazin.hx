import flixel.addons.display.FlxTiledSprite;

var scrollingSky:FlxBackdrop;
var rainShader:RuntimeShader;

var rainTimer:Float = 0;
var rainTimeScale:Float = 1;
var lightningTimer:Float = 3;
var lightningActive:Bool = true;

var picoAlt:Bool = false;
var darnellAlt:Bool = false;
var cantUppercut:Bool = false;

function createPost() {
	var skyAdditive = stage.getProp('skyAdditive');
	skyAdditive.blend = BlendMode.ADD;
	skyAdditive.visible = false;

	var lightning = stage.getProp('lightning');
	lightning.visible = false;

	var foregroundMultiply = stage.getProp('foregroundMultiply');
	foregroundMultiply.blend = BlendMode.MULTIPLY;
	foregroundMultiply.visible = false;

	var additionalLighten = stage.getProp('additionalLighten');
	additionalLighten.blend = BlendMode.ADD;
	additionalLighten.visible = false;

	stage.add(scrollingSky = new FlxTiledSprite(Paths.image('phillyBlazin/skyBlur', 'weekend1'), 2000, 359, true, false));
	scrollingSky.setPosition(-500, -120);
	scrollingSky.scrollFactor.set(0, 0);
	scrollingSky.zIndex = 10;

	rainShader = new RuntimeShader('rain');
	rainShader.setFloat('uScale', FlxG.height / 200);
	rainShader.setFloat('uIntensity', .5);
	rainShader.setFloatArray('uScreenResolution', [FlxG.width, FlxG.height]);
	rainShader.setFloatArray('uCameraBounds', [0, 0, FlxG.width, FlxG.height]);
	rainShader.setFloatArray('uRainColor', [0x66 / 0xff, 0x80 / 0xff, 0xcc / 0xff]);
	game.camGame.filters = [new ShaderFilter(rainShader)];

	game.player1.setPosition(1200, 1300);
	game.player2.setPosition(1280, 1300); // uh?
	game.player1.color = game.player2.color = 0xffdedede;
	game.player3.color = 0xff888888;
	game.ratingGroup.x += 560;
	game.ratingGroup.y -= 320;

	stage.sortZIndex();
}

function opponentNoteEvent(e:NoteEvent) {
	darnellAnim(e);
	picoAnim(e);
}
function playerNoteEvent(e:NoteEvent) {
	if (e.type == NoteEventType.HIT) rainTimeScale += 0.7;
	darnellAnim(e);
	picoAnim(e);
}

function hitShake()
	game.camGame.shake(0.0025, 0.15);
function blockShake()
	game.camGame.shake(0.002, 0.1);
function picoAnim(e:NoteEvent) {
	if (e.type != NoteEventType.HIT && e.type != NoteEventType.LOST) return;

	var missed:Bool = e.type == NoteEventType.LOST;
	var alt:String = (picoAlt ? '2' : '1');
	var pico:Character = game.player1;
	var kind:String = e.note.noteKind;
	var front:Bool = false;

	if (cantUppercut) {
		cantUppercut = false;
		pico.playAnimationSteps(missed ? 'hitHigh' : 'block', true);
		pico.zIndex = 2000;
		stage.sortZIndex();
		return;
	}
	switch (kind) {
		case 'weekend-1-punchlow', 'weekend-1-punchlowblocked', 'weekend-1-punchlowdodged', 'weekend-1-punchlowspin':
			if (missed) {
				pico.playAnimationSteps('hitLow', true);
			} else {
				pico.playAnimationSteps('punchLow$alt', true);
				picoAlt = !picoAlt;
				front = true;
			}
		case 'weekend-1-punchhigh', 'weekend-1-punchhighblocked', 'weekend-1-punchhighdodged', 'weekend-1-punchhighspin':
			if (missed) {
				pico.playAnimationSteps('hitHigh', true);
			} else {
				pico.playAnimationSteps('punchHigh$alt', true);
				picoAlt = !picoAlt;
				front = true;
			}

		case 'weekend-1-blocklow': pico.playAnimationSteps(missed ? 'hitLow' : 'block', true);
		case 'weekend-1-blockhigh': pico.playAnimationSteps(missed ? 'hitHigh' : 'block', true);
		case 'weekend-1-blockspin': pico.playAnimationSteps(missed ? 'hitSpin' : 'block', true);
		
		case 'weekend-1-dodgelow': pico.playAnimationSteps(missed ? 'hitLow' : 'dodge', true);
		case 'weekend-1-dodgehigh': pico.playAnimationSteps(missed ? 'hitHigh' : 'dodge', true);
		case 'weekend-1-dodgespin': pico.playAnimationSteps(missed ? 'hitSpin' : 'dodge', true);

		case 'weekend-1-hithigh': pico.playAnimationSteps('hitHigh', true);
		case 'weekend-1-hitlow': pico.playAnimationSteps('hitLow', true);
		case 'weekend-1-hitspin': pico.playAnimationSteps('hitSpin', true);

		case 'weekend-1-picouppercutprep': pico.playAnimationSteps('uppercutPrep', true); cantUppercut = missed;
		case 'weekend-1-picouppercut': picoUppercut(!missed); front = true;

		case 'weekend-1-darnelluppercutprep', 'weekend-1-reversefakeout': pico.playAnimation('idle', true);
		case 'weekend-1-darnelluppercut': pico.playAnimationSteps('uppercutHit', true);

		case 'weekend-1-fakeout': pico.playAnimationSteps(missed ? 'hitHigh' : 'fakeout', true);
		case 'weekend-1-taunt':
			if (pico.currentAnimation == 'fakeout')
				pico.playAnimationSteps('taunt', true);
			else
				pico.playAnimation('idle', true);
		case 'weekend-1-tauntforce': pico.playAnimationSteps('taunt', true);

		case 'weekend-1-idle': pico.playAnimation('idle', true);
	}
	game.player1.zIndex = (front ? 3001 : 2000);
	stage.sortZIndex();
}
function picoUppercut(hit:Bool) {
	game.player1.playAnimationSteps('uppercut', true);
	if (hit)
		game.camGame.shake(0.005, 0.25);
}
function darnellAnim(e:NoteEvent) {
	if (e.type != NoteEventType.HIT && e.type != NoteEventType.LOST) return;

	var missed:Bool = e.type == NoteEventType.LOST;
	var alt:String = (darnellAlt ? '2' : '1');
	var darn:Character = game.player2;
	var kind:String = e.note.noteKind;

	if (cantUppercut) {
		darn.playAnimationSteps('punchHigh$alt', true);
		darnellAlt = !darnellAlt;
		return;
	}
	switch (kind) {
		case 'weekend-1-punchlow', 'weekend-1-punchlowblocked', 'weekend-1-punchlowdodged', 'weekend-1-punchlowspin':
			if (missed) {
				darn.playAnimationSteps('punchLow$alt', true);
				darnellAlt = !darnellAlt;
				hitShake();
			} else {
				switch (kind) {
					case 'weekend-1-punchlow': darn.playAnimationSteps('hitLow', true); hitShake();
					case 'weekend-1-punchlowblocked': darn.playAnimationSteps('block', true); blockShake();
					case 'weekend-1-punchlowdodged': darn.playAnimationSteps('dodge', true);
					case 'weekend-1-punchlowspin': darn.playAnimationSteps('hitSpin', true); hitShake();
				}
			}
		case 'weekend-1-punchhigh', 'weekend-1-punchhighblocked', 'weekend-1-punchhighdodged', 'weekend-1-punchhighspin':
			if (missed) {
				darn.playAnimationSteps('punchHigh$alt', true);
				darnellAlt = !darnellAlt;
				hitShake();
			} else {
				switch (kind) {
					case 'weekend-1-punchhigh': darn.playAnimationSteps('hitHigh', true); hitShake();
					case 'weekend-1-punchhighblocked': darn.playAnimationSteps('block', true); blockShake();
					case 'weekend-1-punchhighdodged': darn.playAnimationSteps('dodge', true);
					case 'weekend-1-punchhighspin': darn.playAnimationSteps('hitSpin', true); hitShake();
				}
			}

		case 'weekend-1-blocklow', 'weekend-1-dodgelow', 'weekend-1-hitlow':
			darn.playAnimationSteps('punchLow$alt', true);
			darnellAlt = !darnellAlt;
		case 'weekend-1-blockhigh', 'weekend-1-dodgehigh', 'weekend-1-blockspin', 'weekend-1-dodgespin', 'weekend-1-hithigh', 'weekend-1-hitspin':
			darn.playAnimationSteps('punchHigh$alt', true);
			darnellAlt = !darnellAlt;

		case 'weekend-1-darnelluppercutprep': darn.playAnimation('uppercutPrep', true);
		case 'weekend-1-darnelluppercut': darn.playAnimationSteps('uppercut', true); game.camGame.shake(0.005, 0.25);

		case 'weekend-1-picouppercut': darn.playAnimationSteps(missed ? 'dodge' : 'uppercutHit', true);

		case 'weekend-1-fakeout':
			if (missed) {
				darn.playAnimationSteps('punchHigh$alt', true);
				darnellAlt = !darnellAlt;
				hitShake();
			} else {
				darn.playAnimationSteps('cringe', true);
			}
		case 'weekend-1-taunt':
			if (darn.currentAnimation == 'cringe')
				darn.playAnimationSteps('pissed', true);
			else
				darn.playAnimation('idle', true);
		case 'weekend-1-tauntforce': darn.playAnimationSteps('pissed', true);

		case 'weekend-1-idle': darn.playAnimation('idle', true);
	}
}

function death() {
	game.camFocusTarget.x += 250;
	game.camFocusTarget.y -= 750;
}
function deathPost() {
	game.camFocusTarget.y -= 450;
	game.camGame.filters = [];
}

function update(elapsed, paused, dead) {
	if (paused || dead) return;

	rainTimeScale = Util.smoothLerp(rainTimeScale, 0.02, 3 * elapsed);
	rainTimer += elapsed * rainTimeScale;
	scrollingSky.scrollX -= elapsed * 35;

	if (lightningActive) lightningTimer -= elapsed;
	else lightningTimer = 1;

	if (lightningTimer <= 0) {
		applyLightning();
		lightningTimer = FlxG.random.float(7, 15);
	}

	var cam:FunkinCamera = game.camGame;
	rainShader.setFloatArray('uCameraBounds', [cam.viewLeft, cam.viewTop, cam.viewRight, cam.viewBottom]);
	rainShader.setFloat('uTime', rainTimer);
}

function applyLightning():Void {
	var lightning:StageProp = stage.getProp('lightning');
	var skyAdditive:StageProp = stage.getProp('skyAdditive');
	var additionalLighten:StageProp = stage.getProp('additionalLighten');
	var foregroundMultiply:StageProp = stage.getProp('foregroundMultiply');

	var LIGHTNING_FULL_DURATION:Float = 1.5;
	var LIGHTNING_FADE_DURATION:Float = 0.3;

	skyAdditive.alpha = .7;
	skyAdditive.visible = true;
	FlxTween.tween(skyAdditive, {alpha: 0}, LIGHTNING_FULL_DURATION, {onComplete: cleanupLightning});

	foregroundMultiply.alpha = .64;
	foregroundMultiply.visible = true;
	FlxTween.tween(foregroundMultiply, {alpha: 0}, LIGHTNING_FULL_DURATION);

	additionalLighten.alpha = .3;
	additionalLighten.visible = true;
	FlxTween.tween(additionalLighten, {alpha: 0}, LIGHTNING_FADE_DURATION);

	lightning.visible = true;
	lightning.playAnimation('strike');

	if (FlxG.random.bool(65)) lightning.x = FlxG.random.int(-250, 280);
	else lightning.x = FlxG.random.int(780, 900);

	FlxTween.color(game.player1, LIGHTNING_FADE_DURATION, 0xFF606060, 0xffdedede);
	FlxTween.color(game.player2, LIGHTNING_FADE_DURATION, 0xFF606060, 0xffdedede);
	FlxTween.color(game.player3, LIGHTNING_FADE_DURATION, 0xff606060, 0xff888888);

	FlxG.sound.play(Paths.sound('Lightning${FlxG.random.int(1, 3)}', 'weekend1'));
}

function cleanupLightning(tween:FlxTween) {
	for (name in ['skyAdditive', 'foregroundMultiply', 'additionalLighten', 'lightning'])
		stage.getProp(name).visible = false;
}