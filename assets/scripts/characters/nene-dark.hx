import funkin.objects.stage.ABotVisualizer;
import funkin.backend.FunkinTypedSpriteGroup;

var PUPIL_STATE_LEFT:Int = 0;
var PUPIL_STATE_NORMAL:Int = 1;

var NENE_STATE_DEFAULT:Int = 0;
var NENE_STATE_PREPARE:Int = 1;
var NENE_STATE_RAISE:Int = 2;
var NENE_STATE_READY:Int = 3;
var NENE_STATE_LOWER:Int = 4;

var VULTURE_THRESHOLD = .25;

var light:Float = 0;
var animationFinished:Bool = false;

var aBotSpeaker:FunkinTypedSpriteGroup = new FunkinTypedSpriteGroup();
// abot elements
var aBotVis:ABotVisualizer = new ABotVisualizer();
var system:FunkinSprite = new FunkinSprite(-130, 316).loadAnimate('characters/aBot/aBotSystemDark');
var eyeWhites:FunkinSprite = new FunkinSprite(system.x + 40, system.y + 250).makeGraphic(160, 60, FlxColor.WHITE);
var eyePupils:FunkinSprite = new FunkinSprite(system.x + 56, system.y + 238).loadAnimate('characters/aBot/systemEyes');
var stereoBG:FunkinSprite = new FunkinSprite(system.x + 150, system.y + 30).loadTexture('characters/abot/stereoBG');
var systemSwapShader:RuntimeShader = new RuntimeShader('textureSwap');
var visAdjustColor:RuntimeShader = new RuntimeShader('adjustColor');

var lightNene:Character = new Character(x, y, 'nene', side, fallbackCharacter, false); // kinda messy but, whatever

function songEvent(e:SongEvent) {
	switch (e.type) {
		case 'songStart':
			aBotVis.snd = game.music.syncBase;
		case 'beatHit':
			system.playAnimation('bump', true);
		case 'changeSpotlight':
			if (e.sprite == game.player1.current) {
				if (eyePupils.getVar('state') != PUPIL_STATE_NORMAL) {
					eyePupils.setVar('state', PUPIL_STATE_NORMAL);
					eyePupils.playAnimation('lookNormal');
				}
			} else if (e.sprite == game.player2.current) {
				if (eyePupils.getVar('state') != PUPIL_STATE_LEFT) {
					eyePupils.setVar('state', PUPIL_STATE_LEFT);
					eyePupils.playAnimation('lookLeft');
				}
			}
		default:
	}
}

function create() {
	lightNene.bop = false;
	
	systemSwapShader.setSampler2D('image', Paths.bmd('characters/aBot/aBotSystem/spritemap1'));
	system.shader = systemSwapShader;
	stereoBG.color = 0xff616785;
	
	visAdjustColor.setFloat('saturation', -45);
	visAdjustColor.setFloat('brightness', -12);
	visAdjustColor.setFloat('hue', -26);
	for (mem in aBotVis)
		mem.shader = visAdjustColor;
	
	aBotVis.setPosition(system.x + 200, system.y + 84);
	setVar('state', NENE_STATE_DEFAULT);
	setVar('useLight', false);

	system.addAnimation('bump', 'Abot System');
	eyePupils.addAnimation('lookLeft', 'a bot eyes lookin', 24, false, [for (i in 0 ... 17) i]);
	eyePupils.addAnimation('lookNormal', 'a bot eyes lookin', 24, false, [for (i in 17 ... 30) i]);
	eyePupils.playAnimation('lookNormal');

	aBotSpeaker.add(eyeWhites);
	aBotSpeaker.add(eyePupils);
	aBotSpeaker.add(stereoBG);
	aBotSpeaker.add(aBotVis);
	aBotSpeaker.add(system);

	onAnimationComplete.add(animationFinishedC);
	onAnimationFrame.add(animationAdvancedC);
}
function update(elapsed:Float) {
	super.update(elapsed);
	lightNene.update(elapsed);
	aBotSpeaker.update(elapsed);
	
	if (shouldTransitionState())
		transitionState();
}
function draw() {
	light = getVar('light');
	systemSwapShader.setFloat('fadeAmount', light);
	eyeWhites.color = FlxColor.interpolate(0xff6f96ce, FlxColor.WHITE, light);
	
	aBotSpeaker.setPosition(x, y);
	aBotSpeaker.alpha = alpha;
	aBotSpeaker.draw();
	super.draw();
	lightNene.setPosition(x, y);
	lightNene.alpha = light;
	lightNene.draw();
}

function shouldTransitionState() {
	return (!game.inputDisabled && game.player1 != null && game.player1.current.loadedCharacter != 'pico-blazin');
}
function transitionState() {
	switch (getVar('state')) {
		case NENE_STATE_DEFAULT:
			if (game.health <= VULTURE_THRESHOLD)
				setState(NENE_STATE_PREPARE);
		case NENE_STATE_PREPARE:
			if (game.health > VULTURE_THRESHOLD) {
				setState(NENE_STATE_DEFAULT);
			} else {
				setState(NENE_STATE_RAISE);
				playAnimation('raiseKnife');
				animationFinished = false;
			}
		case NENE_STATE_RAISE:
			if (animationFinished) {
				setState(NENE_STATE_READY);
				animationFinished = false;
			}
		case NENE_STATE_READY:
			if (game.health > VULTURE_THRESHOLD) {
				setState(NENE_STATE_LOWER);
				playAnimation('lowerKnife');
			}
		case NENE_STATE_LOWER:
			if (animationFinished) {
				setState(NENE_STATE_DEFAULT);
				animationFinished = false;
			}
		default:
			setState(NENE_STATE_DEFAULT);
	}
}
function setState(state) {
	setVar('state', state);
}
var MIN_BLINK_DELAY:Int = 3;
var MAX_BLINK_DELAY:Int = 7;
var blinkCountdown:Int = MIN_BLINK_DELAY;
function dance(beat:Int = 0, forced:Bool = false) {
	var stopDance:Bool = true;
	
	switch (getVar('state')) {
		case NENE_STATE_DEFAULT:
			stopDance = false;
		case NENE_STATE_RAISE:
			if (currentAnimation != 'raiseKnife')
				playAnimation('danceLeft');
		case NENE_STATE_READY:
			if (blinkCountdown <= 0) {
				playAnimation('idleKnife', false);
				blinkCountdown = FlxG.random.int(MIN_BLINK_DELAY, MAX_BLINK_DELAY);
			} else {
				blinkCountdown --;
			}
	}
	
	if (stopDance)
		return false;
	
	return super.dance(beat, forced);
}
function playAnimation(anim:String, ?forced:Bool = false, ?reversed:Bool = false, ?frame:Int = 0) {
	super.playAnimation(anim, forced, reversed, frame);
	lightNene.playAnimation(anim, forced, reversed, frame);
}
function animationFinishedC(anim:String) {
	switch (getVar('state')) {
		case NENE_STATE_RAISE:
			if (anim == 'raiseKnife') {
				animationFinished = true;
				transitionState();
			}
		case NENE_STATE_LOWER:
			if (anim == 'lowerKnife') {
				animationFinished = true;
				transitionState();
			}
		default:
	}
}
function animationAdvancedC(frame:Int) {
	if (getVar('state') == NENE_STATE_PREPARE && currentAnimation == 'danceLeft' && frame == 13) {
		animationFinished = true;
		transitionState();
	}
}