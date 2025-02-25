package funkin.states;

import funkin.backend.Mods;
import funkin.objects.Alphabet;
import funkin.shaders.HSBShift;

import openfl.display.BitmapData;
import flixel.util.FlxGradient;
import flixel.effects.FlxFlicker;
import flixel.graphics.FlxGraphic;

using Lambda;

class ModMenuState extends FunkinState {
	public static var selectedMod:String = '';
	
	public var pane:ModPane;
	public var capsules:FlxTypedSpriteGroup<ModCapsule>;
	public var capsuleSpacing:Float = 110;
	public var capsuleCam:FunkinCamera;
	public var target:FlxObject = null;
	public var selection:Int;
	
	var lastShiftTime:Float = 0;
	
	var heldCapsule:ModCapsule = null;
	var modList:Array<Mod>;
	
	public override function create() {
		super.create();
		
		stepHit.add(stepHitEvent);
		conductorInUse.syncTracker = FlxG.sound.music;
		
		var bg:FunkinSprite = new FunkinSprite().loadTexture('mainmenu/bgPurple');
		bg.setGraphicSize(bg.width * 1.1);
		bg.scrollFactor.set();
		bg.updateHitbox();
		bg.screenCenter();
		add(bg);
		
		var theOtherBG:FunkinSprite = new FunkinSprite(0, 40).loadTexture('modmenu/bg');
		theOtherBG.x = FlxG.width * .5 - theOtherBG.width - 20;
		theOtherBG.color = FlxColor.fromRGB(70, 80, 90);
		theOtherBG.blend = MULTIPLY;
		add(theOtherBG);
		
		pane = new ModPane();
		pane.screenCenter(Y);
		pane.x = FlxG.width * .5 + 20;
		add(pane);
		
		capsuleCam = new FunkinCamera(0, theOtherBG.y + 20, FlxG.width, Std.int(theOtherBG.height - 40));
		capsuleCam.target = target = new FlxObject(FlxG.width * .5, FlxG.height * .5);
		capsuleCam.followLerp = 11;
		capsuleCam.bgColor = 0;
		FlxG.cameras.add(capsuleCam, false);
		
		modList = Mods.get();
		capsules = new FlxTypedSpriteGroup();
		capsules.camera = capsuleCam;
		
		selection = Std.int(Math.max(modList.findIndex((mod:Mod) -> selectedMod == mod.directory), 0));
		
		for (i => mod in modList) {
			var capsule:ModCapsule = new ModCapsule(0, 0, mod);
			capsule.x -= capsule.width;
			capsules.add(capsule);
		}
		repositionCapsules(true);
		// add(capsules);
		select();
		capsuleCam.snapToTarget();
		for (capsule in capsules) {
			capsule.x = (capsule.selected ? -50 : -160);
			capsule.updateSelected(true);
		}
		shiftCapsules();

		DiscordRPC.presence.details = 'In the mod menu';
		DiscordRPC.dirty = true;
	}
	
	public function stepHitEvent(step:Int) {
		if (lastShiftTime > conductorInUse.syncTracker.time + 200)
			lastShiftTime -= conductorInUse.syncTracker.length;
		
		var mod:Int = 0;
		if (conductorInUse.syncTracker.time - lastShiftTime > conductorInUse.stepCrochet * 3) {
			if (FlxG.keys.pressed.DOWN) mod = 1;
			if (FlxG.keys.pressed.UP) mod = -1;
		}
		
		if (mod != 0)
			(FlxG.keys.pressed.CONTROL ? shift : select)(mod);
	}
	
	public override function update(elapsed:Float) {
		if (FlxG.keys.justPressed.ESCAPE) {
			FlxG.switchState(MainMenuState.new);
			return;
		}
		
		var shifting:Bool = FlxG.keys.pressed.CONTROL;
		if (shifting) {
			capsuleCam.zoomTarget = 1.04;
			capsuleCam.zoomFollowLerp = 15;
		} else {
			capsuleCam.zoomTarget = 1;
			capsuleCam.zoomFollowLerp = 12;
		}
		if (FlxG.keys.justPressed.UP || FlxG.keys.justPressed.DOWN) {
			(shifting ? shift : select)(FlxG.keys.justPressed.DOWN ? 1 : -1);
			lastShiftTime = FlxG.sound.music.time;
		}
		
		var selectedCapsule:ModCapsule = capsules.members[selection];
		if (selectedCapsule != null) {
			selectedCapsule.shifting = shifting;
			target.y = selectedCapsule.targetY + selectedCapsule.height * .5;
			if (FlxG.keys.justPressed.ENTER) {
				selectedCapsule.powerButton.playAnimation('push', true);
				heldCapsule = selectedCapsule;
				if (!selectedCapsule.shifting)
					selectedCapsule.glowRing(true);
			}
			if (FlxG.keys.justReleased.ENTER) {
				selectedCapsule.enabled = !selectedCapsule.enabled;
				if (!selectedCapsule.shifting)
					selectedCapsule.glowRing(false);
			}
		}
		
		// someone please help me write this state's code so that it is actually good
		super.update(elapsed);
		capsules.update(elapsed);
		shiftCapsules(elapsed);
	}
	public override function draw() {
		target.x = (capsuleCam.scroll.x = (capsuleCam.width * .5 - 20) * (1 - capsuleCam.zoom)) + capsuleCam.width * .5; // Yea
		super.draw();
		if (capsules.length > 0) {
			var i:Int = 0;
			while (i < selection)
				capsules.members[i ++].draw();
			i = capsules.length;
			while (i > selection)
				capsules.members[-- i].draw();
			capsules.members[selection].draw();
		}
	}
	public override function destroy() {
		var pos:Int = 0;
		for (capsule in capsules) {
			if (capsule.mod != null) {
				modList.remove(capsule.mod);
				modList.insert(pos ++, capsule.mod);
			}
		}
		super.destroy();
	}
	
	public function shiftCapsules(elapsed:Float = -1) {
		var instant:Bool;
		var shifting:Bool = FlxG.keys.pressed.CONTROL;
		for (i => capsule in capsules.members) {
			if (Math.abs(i - selection) > 7) {
				if (alive) capsule.kill();
				continue;
			}
			if (!capsule.alive) {
				capsule.revive();
				instant = true;
			} else {
				instant = false;
			}
			
			var centerDist:Float = capsule.targetY + capsule.height * .5 - target.y;
			centerDist = FlxMath.lerp(0, centerDist, Math.min(Math.abs(centerDist) / capsuleCam.height * .5, .5));
			if (shifting)
				centerDist *= 1.1;
			
			var targetY:Float = capsule.targetY;
			var targetX:Float = (capsule.shifting ? -30 : (capsule.selected ? -50 : -160));
			var targetButtonX:Float = (capsule.shifting ? -10 : (capsule.selected ? 0 : -50));
			
			targetX -= Math.abs(centerDist) * .25;
			targetY -= centerDist;
			if (elapsed < 0 || instant) {
				capsule.x = targetX;
				capsule.y = targetY;
				capsule.shiftButtonGroup.x = capsule.x + targetButtonX;
			} else {
				capsule.x = Util.smoothLerp(capsule.x, targetX, elapsed * 10);
				capsule.y = Util.smoothLerp(capsule.y, targetY, elapsed * 12);
				capsule.shiftButtonGroup.x = Util.smoothLerp(capsule.shiftButtonGroup.x, capsule.x + targetButtonX, elapsed * 10);
			}
		}
	}
	public function repositionCapsules(snap:Bool = false) {
		var capsuleHeight:Float = 0;
		for (i => capsule in capsules.members) {
			capsule.targetY = i * capsuleSpacing;
			capsuleHeight = capsule.height;
			if (snap)
				capsule.y = capsule.targetY;
		}
		// capsuleCam.deadzone.height = ((capsules.length - 1) * capsuleSpacing) + capsuleHeight - 20;
	}
	public function wrapAround(capsule:ModCapsule, mod:Int) {
		var yOffset:Float = -mod * capsuleSpacing;
		target.y = capsule.targetY + capsule.height * .5 + yOffset;
		capsuleCam.snapToTarget();
		shiftCapsules();
		if (capsule.shifting)
			capsule.y += yOffset;
		target.y -= yOffset;
	}
	public function shift(mod:Int = 0) {
		if (mod == 0) return;
		
		var targetIndex:Int = FlxMath.wrap(selection + mod, 0, capsules.length - 1);
		
		var capsule:ModCapsule = capsules.members[selection];
		if (capsule != null) {
			FunkinSound.playOnce(Paths.sound('cancelMenu'), .8);
			
			capsules.remove(capsule, true);
			capsules.insert(targetIndex, capsule);
			(mod > 0 ? capsule.shiftDownButton : capsule.shiftUpButton).playAnimation('button', true);
			repositionCapsules();
			
			if (selection + mod - targetIndex != 0)
				wrapAround(capsule, mod);
		} else {
			Log.warning('selected capsule is null');
		}
		selection = targetIndex;
	}
	public function select(mod:Int = 0) {
		if (mod != 0) FunkinSound.playOnce(Paths.sound('scrollMenu'), .8);
		
		var capsule:ModCapsule = capsules.members[selection];
		if (capsule != null) {
			capsule.selected = false;
		}
		if (heldCapsule != null) {
			heldCapsule.powerButton.playAnimation(heldCapsule.enabled ? 'on' : 'off');
			heldCapsule.glowRing(false);
			heldCapsule = null;
		}
		
		var targetIndex:Int = FlxMath.wrap(selection + mod, 0, capsules.length - 1);
		
		capsule = capsules.members[targetIndex];
		if (capsule != null) {
			capsule.selected = true;
			pane.updateWithCapsule(capsule);
			selectedMod = capsule.mod?.directory;
			if (FlxG.keys.pressed.ENTER) {
				capsule.powerButton.playAnimation('push');
				capsule.glowRing(true);
				heldCapsule = capsule;
			}
			
			if (selection + mod - targetIndex != 0)
				wrapAround(capsule, mod);
		} else {
			Log.warning('selected capsule is null');
		}
		selection = targetIndex;
	}
}

class ModPaneTip extends FunkinSpriteGroup {
	public var icon:FunkinSprite;
	public var text:FlxText;
	
	public function new(x:Float = 0, y:Float = 0, iconPath:String, tip:String = '', tipColor:FlxColor = FlxColor.WHITE) {
		super(x, y);
		
		icon = new FunkinSprite().loadTexture('modmenu/$iconPath');
		icon.scale.set(.7, .7);
		icon.updateHitbox();
		icon.x -= icon.width;
		add(icon);
		text = new FlxText(-535, 0, 490, tip);
		text.setFormat(Paths.ttf('vcr'), 22, tipColor, RIGHT, OUTLINE, 0xa0000000);
		text.antialiasing = Options.data.antialiasing;
		text.y = (icon.height - text.height) * .5;
		add(text);
	}
}
class ModPane extends FunkinSpriteGroup {
	public var modText:Alphabet;
	public var descText:FlxText;
	public var authText:Alphabet;
	public var textGradient:FunkinSprite;
	
	public var pane:FunkinSprite;
	public var banner:FunkinSprite;
	public var portrait:FunkinSprite;
	public var optionBox:FunkinSprite;
	
	public var capsule:ModCapsule;
	public var globalTip:ModPaneTip;
	
	public function new(x:Float = 0, y:Float = 0) {
		super(x, y);
		
		textGradient = new FunkinSprite().loadGraphic(FlxGradient.createGradientBitmapData(425, 1, [FlxColor.WHITE, FlxColor.TRANSPARENT], 1, 0));
		textGradient.scale.set(1, 60);
		textGradient.updateHitbox();
		textGradient.alpha = .75;
		textGradient.blend = MULTIPLY;
		
		pane = new FunkinSprite().loadTexture('modmenu/pane');
		add(pane);
		banner = new FunkinSprite();
		add(banner);
		portrait = new FunkinSprite(30, 30);
		add(textGradient);
		add(portrait);
		optionBox = new FunkinSprite(480, 158).loadTexture('modmenu/optionBox');
		add(optionBox);
		
		globalTip = new ModPaneTip(optionBox.x - 30, pane.height, 'global', 'Global Mod', 0xff66ccff);
		globalTip.y -= globalTip.height + 30;
		globalTip.visible = false;
		add(globalTip);
		
		modText = new Alphabet(160, 64, '', 'techno');
		// modText.setPosition(50, 158);
		modText.black = 0xa0000000;
		modText.scaleTo(.43, .4);
		add(modText);
		authText = new Alphabet(160, 90, '', 'techno');
		// authText.setPosition(50, 190);
		authText.scaleTo(.3, .27);
		authText.alpha = .5;
		add(authText);
		var textScale:Float = .53;
		descText = new FlxText(50, 158, 405 / textScale);
		// descText.y = 216;
		descText.setFormat(Paths.ttf('vcr'), 32, FlxColor.WHITE, LEFT, OUTLINE, 0xc0000000);
		descText.antialiasing = Options.data.antialiasing;
		descText.scale.set(textScale, textScale);
		descText.updateHitbox();
		descText.borderSize = 1.5;
		add(descText);
	}
	public function updateWithCapsule(capsule:ModCapsule) {
		var capsuleMatch:Bool = (this.capsule == capsule);
		this.capsule = capsule;
		if (capsule == null || capsuleMatch) return;
		
		FlxTween.cancelTweensOf(portrait);
		portrait.loadGraphicFromSprite(capsule.portrait);
		portrait.setGraphicSize(105);
		portrait.updateHitbox();
		
		var mod:Mod = capsule.mod;
		var modDir:Null<String> = mod?.directory;
		var targetColor:FlxColor = capsule.capsuleColor;
		if (mod != null) {
			modText.text = mod.name;
			authText.text = 'by ${mod.author}';
			globalTip.visible = mod.global;
			
			var info:ModInfo = capsule.mod.info;
			if (info != null) {
				descText.text = info.description ?? '';
			}
		} else {
			modText.text = 'Unnamed';
			authText.text = 'by Unknown';
			globalTip.visible = false;
			descText.text = '';
		}
		descText.updateHitbox();
		textGradient.x = portrait.x + portrait.width - 75;
		textGradient.y = portrait.getMidpoint().y - textGradient.height * .5;
		
		banner.visible = false;
		if (Paths.modPathExists('banner.png', modDir)) {
			try {
				banner.loadGraphic(BitmapData.fromFile(Paths.modPath('banner.png', modDir)));
				banner.updateHitbox();
				banner.visible = true;
			}
		}
		banner.x = FlxG.width;
		banner.y = Math.floor(portrait.getMidpoint().y - banner.height * .5);
		
		var gradientCol:FlxColor = targetColor; // maybe use cmyk instead of hsb?
		gradientCol.brightness = Math.min(gradientCol.brightness * (gradientCol.saturation * .5 + .5), .75);
		gradientCol.saturation = Math.min(gradientCol.saturation * 2.5, 1);
		textGradient.color = gradientCol;
		
		// portrait.alpha = 0;
		// portrait.x = pane.x + 28;
		FlxTween.cancelTweensOf(pane);
		FlxTween.cancelTweensOf(banner);
		FlxTween.cancelTweensOf(optionBox);
		FlxTween.shake(portrait, .015, .1);
		FlxTween.color(pane, .11, pane.color, targetColor);
		FlxTween.color(optionBox, .11, pane.color, targetColor);
		FlxTween.tween(banner, {x: FlxG.width - banner.width}, .1, {ease: FlxEase.sineOut});
		// FlxTween.tween(portrait, {x: pane.x + 38, alpha: 1}, .3, {ease: FlxEase.circOut});
	}
}

class ModCapsule extends FunkinSpriteGroup {
	public var modText:Alphabet;
	public var capsule:FunkinSprite;
	public var rimGlow:FunkinSprite;
	public var ringGlow:FunkinSprite;
	public var portrait:FunkinSprite;
	public var powerGlow:FunkinSprite;
	public var capsuleColor:FlxColor = FlxColor.WHITE;
	
	public var powerButton:FunkinSprite;
	public var shiftUpButton:FunkinSprite;
	public var shiftDownButton:FunkinSprite;
	public var shiftButtonGroup:FunkinSpriteGroup;
	
	public var targetY:Float = 0;
	@:isVar public var enabled(get, set):Bool;
	public var mod(default, set):Null<Mod> = null;
	public var selected(default, set):Bool = false;
	public var shifting(default, set):Bool = false;
	
	var ringRGB:HSBShift;
	var flickerLoop:FlxTimer;
	
	public function new(x:Float = 0, y:Float = 0, ?mod:Mod) {
		super(x, y);
		
		shiftButtonGroup = new FunkinSpriteGroup();
		capsule = new FunkinSprite().loadTexture('modmenu/capsule');
		portrait = new FunkinSprite(228);
		rimGlow = new FunkinSprite(-20).loadTexture('modmenu/rimGlow');
		rimGlow.blend = ADD;
		ringGlow = new FunkinSprite(-11).loadTexture('modmenu/ringGlow');
		ringGlow.shader = (ringRGB = new HSBShift()).shader;
		ringGlow.setOffset(-1, -1);
		ringGlow.blend = ADD;
		ringGlow.alpha = 0;
		powerGlow = new FunkinSprite(524, 61).loadTexture('modmenu/powerGlow');
		powerGlow.blend = ADD;
		modText = new Alphabet(0, 0, 'mmnfghghh,..', 'techno');
		modText.color = FlxColor.WHITE;
		modText.black = 0xa0000000;
		modText.scaleTo(.4, .35);
		
		powerButton = new FunkinSprite(162).loadAtlas('modmenu/powerButton');
		powerButton.addAnimation('off', 'power button off', 24, true);
		powerButton.addAnimation('on', 'power button on', 24, false);
		powerButton.addAnimation('push', 'power button press', 24);
		powerButton.setAnimationOffset('on', 7, 9);
		powerButton.playAnimation('off', true);
		powerButton.onAnimationComplete.add((anim:String) -> {
			if (anim == 'on') {
				powerButton.playAnimation('on', true, false, FlxG.random.int(0, powerButton.animation.curAnim.numFrames));
				powerButton.animation.curAnim.frameRate = FlxG.random.int(18, 30);
			}
		});
		
		shiftUpButton = new FunkinSprite(66).loadAtlas('modmenu/shiftButtons');
		shiftUpButton.addAnimation('button', 'shift button up', 24);
		shiftUpButton.playAnimation('button', true);
		shiftUpButton.origin.x = 0;
		shiftUpButton.finishAnimation();
		shiftButtonGroup.add(shiftUpButton);
		shiftDownButton = new FunkinSprite(104).loadAtlas('modmenu/shiftButtons');
		shiftDownButton.addAnimation('button', 'shift button down', 24);
		shiftDownButton.playAnimation('button', true);
		shiftDownButton.finishAnimation();
		shiftDownButton.origin.x = shiftDownButton.width;
		shiftButtonGroup.add(shiftDownButton);
		
		add(capsule);
		add(powerGlow);
		for (obj in [portrait, modText, powerButton, shiftButtonGroup, ringGlow, rimGlow]) {
			add(obj);
			centerToCapsule(obj);
		}
		rimGlow.x += 2;
		rimGlow.y += 2;
		this.mod = mod;
		
		updateEnabled(true);
	}
	public override function update(elapsed:Float) {
		super.update(elapsed);
		ringRGB.hue += .5 * elapsed;
		ringGlow.offset.set(FlxG.random.float(-.5, .5), FlxG.random.float(-.5, .5));
	}
	
	function loadModPortrait(?dir:String) {
		portrait.loadTexture('defaultModPortrait');
		
		if (Paths.modPathExists('pack.png', dir))
			try { portrait.loadGraphic(BitmapData.fromFile(Paths.modPath('pack.png', dir))); }
		
		portrait.setGraphicSize(60);
		portrait.updateHitbox();
		centerToCapsule(portrait);
	}
	function updateModText(str:String):String {
		if (modText.text != str)
			modText.text = str;
		modText.x = 462 - modText.width * .5;
		return str;
	}
	function centerToCapsule(sprite:FlxSprite):FlxSprite {
		sprite.y = capsule.y + Math.floor((capsule.height - sprite.height) * .5);
		return sprite;
	}
	
	function set_mod(newMod:Null<Mod>):Null<Mod> {
		if (newMod != null) {
			updateModText(newMod.name);
			loadModPortrait(newMod.directory);
			
			var color:Array<Int> = newMod.info?.color;
			if (color != null) {
				capsuleColor = FlxColor.fromRGB(color[0], color[1], color[2]);
			} else {
				capsuleColor = FlxColor.WHITE;
			}
		} else {
			loadModPortrait();
			updateModText('Unknown');
			capsuleColor = FlxColor.WHITE;
		}
		capsule.color = capsuleColor;
		return mod = newMod;
	}
	function get_enabled():Bool {
		return mod?.enabled ?? true;
	}
	function set_enabled(isIt:Bool):Bool {
		if (mod != null)
			mod.enabled = isIt;
		updateEnabled();
		return isIt;
	}
	function set_selected(isIt:Bool):Bool {
		selected = isIt;
		updateSelected();
		return isIt;
	}
	function flickerButton(loop:Int) {
		var invert:Bool = (loop % 2 == 0);
		var invertOff:Int = (invert ? 255 : 0);
		var invertMult:Float = (invert ? -1 : 1);
		shiftUpButton.setColorTransform(invertMult, invertMult, invertMult, 1, invertOff, invertOff, invertOff);
		shiftDownButton.setColorTransform(invertMult, invertMult, invertMult, 1, invertOff, invertOff, invertOff);
	}
	function set_shifting(isIt:Bool):Bool {
		if (shifting == isIt) return isIt;
		glowRing(isIt);
		if (isIt) {
			if (flickerLoop == null)
				flickerLoop = new FlxTimer();
			flickerLoop.start(.15, (t:FlxTimer) -> flickerButton(t.elapsedLoops), 0);
			flickerButton(0);
		} else {
			if (flickerLoop != null)
				flickerLoop.cancel();
			shiftDownButton.setColorTransform();
			shiftUpButton.setColorTransform();
		}
		return shifting = isIt;
	}
	public function glowRing(glow:Bool) {
		FlxTween.cancelTweensOf(ringGlow);
		FlxTween.tween(ringGlow, {alpha: glow ? 1 : 0}, .1, {ease: FlxEase.circOut});
		if (selected)
			FlxTween.tween(rimGlow, {alpha: glow ? .5 : 1}, .1, {ease: FlxEase.circIn});
	}
	
	public function updateEnabled(rapid:Bool = false) {
		if (enabled) {
			powerButton.playAnimation('on', true);
		} else {
			powerButton.playAnimation('off', true);
		}
		if (!rapid) {
			FlxTween.cancelTweensOf(capsule);
			FlxTween.cancelTweensOf(modText);
			FlxTween.cancelTweensOf(portrait);
			FlxTween.cancelTweensOf(powerGlow);
			if (enabled) {
				FlxTween.color(capsule, .3, capsule.color, capsuleColor);
				FlxTween.color(modText, .2, modText.color, FlxColor.WHITE);
				FlxTween.color(portrait, 1, portrait.color, FlxColor.WHITE);
				FlxTween.tween(powerGlow, {alpha: 1}, .8, {ease: FlxEase.circOut});
			} else {
				FlxTween.color(capsule, .2, capsule.color, 0xff808099);
				FlxTween.color(modText, .2, modText.color, 0xffb0b0b0);
				FlxTween.color(portrait, 1.1, portrait.color, 0xff996699);
				FlxTween.tween(powerGlow, {alpha: 0}, .5, {ease: FlxEase.sineIn, startDelay: .3});
			}
		} else {
			capsule.color = (enabled ? capsuleColor : 0xff808099);
			modText.color = (enabled ? FlxColor.WHITE : 0xffb0b0b0);
			portrait.color = (enabled ? FlxColor.WHITE : 0xff996699);
			powerGlow.alpha = (enabled ? 1 : 0);
		}
	}
	public function updateSelected(rapid:Bool = false) {
		FlxTween.cancelTweensOf(rimGlow);
		if (!rapid) {
			var fps:Float = FlxG.random.float(30, 50);
			FlxTween.tween(rimGlow, {alpha: selected ? 1 : 0}, .22, {ease: FlxEase.sineOut});
		} else {
			rimGlow.alpha = (selected ? 1 : 0);
		}
	}
}