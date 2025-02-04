package funkin.objects;

using StringTools;

class Character extends FunkinSprite implements ICharacter {
	public var bopFrequency:Int = 2;
	public var bop(default, set):Bool = true;
	public var animReset(default, set):Float = 0;
	public var singForSteps(default, set):Float = 4;
	public var specialAnim(default, set):Bool = false;
	public var conductorInUse(default, set):Conductor = FunkinState.getCurrentConductor();
	public var scaleMultiplier:Float = 1;
	public var sway:Bool = false;
	
	var defaultFlipX:Bool;
	var binSide:CharacterSide;
	var dataSide:CharacterSide;
	var characterGroup:CharacterGroup;
	public var side(default, set):CharacterSide;
	
	var characterDataType:CharacterDataType;
	public var fallbackCharacter:Null<String>;
	public var character(default, set):Null<String>;
	public var psychOffset(default, never):FlxPoint = FlxPoint.get();
	public var originOffset(default, never):FlxPoint = FlxPoint.get();
	public var cameraOffset(default, never):FlxPoint = FlxPoint.get();
	public var stageCameraOffset(default, never):FlxPoint = FlxPoint.get();
	var idleFrameSize(default, never):FlxPoint = FlxPoint.get();
	
	public var healthIcon:String = 'bf';
	public var healthIconData:Null<ModernCharacterHealthIconData> = null;
	
	public var deathData:Null<ModernCharacterDeathData> = null;
	
	public var idleSuffix(default, set):String = '';
	public var animSuffix(default, set):String = '';
	
	public var vocalsLoaded(default, null):Bool = false;
	public var volume(default, set):Float = 1;
	public var vocals:FunkinSound;
	
	public function new(x:Float, y:Float, ?character:String, side:CharacterSide = IDGAF, ?fallback:String) {
		super(x, y);
		rotateOffsets = true;
		vocals = new FunkinSound();
		FlxG.sound.list.add(vocals);
		this.fallbackCharacter = fallback;
		if (character == null) // lol
			this.fallback();
		else
			this.character = character;
		this.side = side;
		this.onAnimationComplete.add((anim:String) -> {
			playAnimation('$anim-loop');
			playAnimation('$anim-hold');
		});
	}
	
	public static function getPathSuffix(basePath:String = '', baseSuffix:String = '', chara:String = ''):String {
		var charaSplit:Array<String> = chara.split('-');
		while (charaSplit.length > 0) { // trim dashes until it finds a working match
			var searchSuffix:String = charaSplit.join('-');
			var searchPath:String = Util.pathSuffix(basePath, searchSuffix);
			if (Paths.exists('$searchPath$baseSuffix'))
				return searchSuffix;
			charaSplit.pop();
		}
		return '';
	}
	public static function getVocals(songPath:String, suffix:String = '', chara:String = ''):openfl.media.Sound {
		try {
			var time:Float = Sys.time();
			var path:String = 'data/songs/$songPath';
			if (Paths.exists(path)) {
				var grrr:String = '$path/Voices';
				var variationSuffix:String = Util.pathSuffix('', suffix);
				var characterSuffix:String = getPathSuffix(grrr, '$variationSuffix.ogg', chara);
				if (chara != '' && characterSuffix == '')
					return null;
				
				var vocalsPath:String = Util.pathSuffix(grrr, characterSuffix) + variationSuffix;
				var vocals:openfl.media.Sound = Paths.ogg(vocalsPath);
				if (vocals.length > 0) {
					var finalTime:Float = Math.round((Sys.time() - time) * 1000) / 1000;
					if (chara == '') {
						Log.info('generic vocals loaded!! (${finalTime}s)');
					} else {
						Log.info('vocals loaded for character "$chara"!! (${finalTime}s)');
					}
					return vocals;
				} else {
					return null;
				}
			}
		} catch (e:haxe.Exception) {
			Log.error('error when loading vocals from character "$chara" -> ${e.message}');
		}
		return null;
	}
	
	function set_side(newSide:CharacterSide) {
		if (side == newSide)
			return newSide;
		side = newSide;
		refreshSide();
		return newSide;
	}
	public function flip():Character {
		if (side != IDGAF)
			side = (side == RIGHT ? LEFT : RIGHT);
		return this;
	}
	public function sideMatches(?side:CharacterSide):Bool {
		side ??= this.side;
		if (dataSide == IDGAF)
			return true;
		return (dataSide == side);
	}
	function refreshSide() {
		flipX = (defaultFlipX == sideMatches());
		if (offsets.exists(currentAnimation)) {
			var offset:FlxPoint = offsets[currentAnimation];
			setAnimOffset(offset.x, offset.y);
		}
	}
	function flipAnim(anim:String):String {
		if (sideMatches()) return anim;
		
		if (anim.startsWith('singLEFT')) {
			return anim.replace('singLEFT', 'singRIGHT');
		} else if (anim.startsWith('singRIGHT')) {
			return anim.replace('singRIGHT', 'singLEFT');
		}
		return anim;
	}
	
	function set_volume(newVolume:Float):Float {
		return vocals.volume = newVolume;
	}
	public function findPathSuffix(basePath:String = '', baseSuffix:String = '', ?chara:String):String {
		return getPathSuffix(basePath, baseSuffix, chara ?? character);
	}
	public function loadVocals(songPath:String, suffix:String = '', ?chara:String):Bool {
		chara ??= character;
		
		var sound:openfl.media.Sound = getVocals(songPath, suffix, chara);
		if (sound != null) {
			vocals.loadEmbedded(sound);
			vocalsLoaded = true;
			vocals.volume = 0;
			vocals.play().stop();
			vocals.looped = false;
			vocals.volume = volume;
			return true;
		} else {
			vocalsLoaded = false;
			vocals.volume = 0;
		}
		return false;
	}
	
	public override function update(elapsed:Float) {
		super.update(elapsed);
		if (animReset > 0) {
			animReset -= elapsed;
			if (animReset <= 0 && !specialAnim) {
				animReset = 0;
				dance();
			}
		}
		if (specialAnim) {
			if (isAnimationFinished() && animReset <= 0) {
				specialAnim = false;
				animReset = 0;
				dance();
			}
		}
	}
	
	public function timeAnimSteps(?steps:Float) {
		animReset = (steps ?? singForSteps) * conductorInUse.stepCrochet * .001;
	}
	public function animationIsLooping(anim:String):Bool {
		return (currentAnimation == '$anim-loop' || currentAnimation == '$anim-hold');
	}
	public function playAnimationSoft(anim:String, forced:Bool = false, reversed:Bool = false, frame:Int = 0) {
		if (!specialAnim)
			playAnimation(anim, forced, reversed, frame);
	}
	public override function playAnimation(anim:String, forced:Bool = false, reversed:Bool = false, frame:Int = 0) {
		animReset = 0;
		specialAnim = false;
		super.playAnimation(flipAnim(anim) + animSuffix, forced, reversed, frame);
	}
	public function playAnimationSteps(anim:String, forced:Bool = false, ?steps:Float, reversed:Bool = false, frame:Int = 0) {
		if (!specialAnim) {
			playAnimation(anim, forced, reversed, frame);
			
			var sameAnim:Bool = (currentAnimation == anim);
			if (animationExists(anim) && (forced || !sameAnim || isAnimationFinished()))
				timeAnimSteps(steps ?? singForSteps);
		}
	}
	public function dance(beat:Int = 0, forced:Bool = false):Bool {
		if (!forced && (animReset > 0 || bopFrequency <= 0 || !bop || specialAnim))
			return false;

		if (sway)
			playAnimation((beat % 2 == 0 ? 'danceLeft' : 'danceRight') + idleSuffix);
		else if (beat % 2 == 0)
			playAnimation('idle$idleSuffix');

		return true;
	}
	public override function setAnimOffset(x:Float = 0, y:Float = 0):Void {
		if (!sideMatches()) {
			animOffset.set(-x + frameWidth - idleFrameSize.x, y);
		} else {
			animOffset.set(x, y);
		}
	}
	override function get_currentAnimation() {
		if (isAnimate) return flipAnim(animate.funkAnim.name);
		else return flipAnim(animation.name);
	}
	override function _onAnimationComplete(?anim:String) {
		onAnimationComplete.dispatch(currentAnimation ?? '');
		if (characterGroup != null && this == characterGroup.current)
			characterGroup.onAnimationComplete.dispatch(currentAnimation ?? '');
	}
	override function _onAnimationFrame(frame:Int) {
		onAnimationFrame.dispatch(frame);
		if (characterGroup != null && this == characterGroup.current)
			characterGroup.onAnimationFrame.dispatch(frame);
	}
	function set_bop(value:Bool):Bool { return bop = value; };
	function set_animReset(value:Float):Float { return animReset = value; };
	function set_specialAnim(value:Bool):Bool { return specialAnim = value; };
	function set_idleSuffix(value:String):String { return idleSuffix = value; }
	function set_animSuffix(value:String):String { return animSuffix = value; }
	function set_singForSteps(value:Float):Float { return singForSteps = value; };
	function set_conductorInUse(conductor:Conductor):Conductor { return conductorInUse = conductor; }
	
	public function set_character(newChara:Null<String>) {
		if (character == newChara) return character;
		if (newChara == null) {
			fallback();
		} else {
			loadCharacter(newChara);
		}
		return character = newChara;
	}
	
	public function loadCharacter(?character:String) { // no character provided attempts to load fallback
		unloadAnimate();
		var charLoad:String = character ?? fallbackCharacter;
		var charPath:String = 'data/characters/$charLoad.json';
		if (!Paths.exists(charPath)) {
			Log.warning('character "$charLoad" not found...');
			Log.minor('verify path:');
			Log.minor('- $charPath');
			fallback(character);
			return this;
		}
		if (character != null) Log.minor('loading character "$charLoad"');
		var time:Float = Sys.time();
		try {
			frames = null;
			@:bypassAccessor this.character = character;
			var content:String = Paths.text(charPath);
			var json:Dynamic = TJSON.parse(content);
			if (json.healthbar_colors != null) { // most recognizable Psych engine feature :fire:
				loadPsychCharData(json);
			} else {
				loadModernCharData(json);
			}
		} catch (e:haxe.Exception) {
			Log.error('error while loading character "$charLoad"... -> ${e.details()}');
			fallback(character);
			return this;
		}
		Log.info('character "$charLoad" loaded successfully! (${Math.round((Sys.time() - time) * 1000) / 1000}s)');
		return this;
	}
	public function loadModernCharData(charData:ModernCharacterData) {
		frames = null;
		characterDataType = MODERN;
		var renderType:String = charData.renderType ?? 'multisparrow';
		switch (renderType) {
			case 'packer':
				this.renderType = PACKER;
				addAtlas(charData.assetPath, PACKER);
			case 'sparrow' | 'multisparrow':
				this.renderType = SPARROW;
				addAtlas(charData.assetPath, SPARROW);
			case 'animateatlas':
				this.renderType = ANIMATEATLAS;
				loadAnimate(charData.assetPath);
			default: throw new haxe.Exception('Render type "${charData.renderType}" is not supported!!');
		}
		var animations:Array<ModernCharacterAnim> = charData.animations;
		for (animation in animations) {
			addAnimation(animation.name, animation.prefix, animation.frameRate ?? 24, animation.looped ?? false, animation.frameIndices, animation.assetPath, animation.flipX, animation.flipY);
			if (animation.offsets != null)
				setAnimationOffset(animation.name, animation.offsets[0], animation.offsets[1]);
		}
		dataSide = switch (charData.side) {
			case 'right': RIGHT;
			case 'none': IDGAF;
			default: LEFT; // we are woke by default
		}
		smooth = !charData.isPixel;
		deathData = charData.death;
		defaultFlipX = charData.flipX ?? false;
		bopFrequency = charData.danceEvery ?? 1;
		healthIconData = charData.healthIcon;
		healthIcon = healthIconData?.id ?? character;
		singForSteps = Math.max(charData.singTime ?? 8, 1);
		scaleMultiplier = charData.scale ?? 1;
		this.scale.set(scaleMultiplier, scaleMultiplier);
		if (charData.offsets != null) originOffset.set(charData.offsets[0] ?? 0, charData.offsets[1] ?? 0);
		if (charData.cameraOffsets != null) cameraOffset.set(charData.cameraOffsets[0] ?? 0, charData.cameraOffsets[1] ?? 0);
		
		sway = (animationExists('danceLeft') && animationExists('danceRight'));
		if (charData.startingAnimation != null) {
			setBaseSize(charData.startingAnimation);
			playAnimation(charData.startingAnimation);
		} else {
			setBaseSize();
			dance();
		}
		finishAnimation();
	}
	public function loadPsychCharData(charData:PsychCharacterData) {
		frames = null;
		characterDataType = PSYCH;
		var sparrows:Array<String> = charData.image.split(',');
		var animations:Array<PsychCharacterAnim> = charData.animations;
		for (sparrow in sparrows) { // no choice with psych 1 multisparrow lmao
			addAtlas(sparrow.trim());
		}
		for (animation in animations) {
			addAnimation(animation.anim, animation.name, animation.fps, animation.loop, animation.indices, animation.assetPath);
			setAnimationOffset(animation.anim, animation.offsets[0] / charData.scale, animation.offsets[1] / charData.scale);
		}
		dataSide = switch (charData.side) {
			case 'right': RIGHT;
			case 'none': IDGAF;
			default: LEFT;
		}
		scaleMultiplier = charData.scale;
		healthIcon = charData.healthicon;
		smooth = !charData.no_antialiasing;
		singForSteps = charData.sing_duration;
		defaultFlipX = charData.flip_x ?? false;
		scale.set(scaleMultiplier, scaleMultiplier);
		psychOffset.set(charData.position[0], charData.position[1]);
		cameraOffset.set(charData.camera_position[0], charData.camera_position[1]);
		
		sway = (animationExists('danceLeft') && animationExists('danceRight'));
		setBaseSize();
		dance();
		finishAnimation();
	}
	
	function setBaseSize(?anim:String) { // lazy, maybe do this without changing cur anim eventually?
		playAnimation(anim != null ? anim : (sway ? 'danceLeft' : 'idle'));
		idleFrameSize.set(frameWidth, frameHeight);
		finishAnimation();
		updateHitbox();
	}
	public function fallback(?attempted:String) {
		if (fallbackCharacter == null || attempted == null) { // dont attempt if fallback failed to fall back :p
			Log.warning('fallback failed lol: loading super fallback character');
			useDefault();
		} else {
			Log.minor('attempting to fall back to "$fallbackCharacter"...');
			loadCharacter();
		}
	}
	public function useDefault() {
		unloadAnimate();
		dataSide = LEFT;
		healthIcon = 'bf';
		renderType = SPARROW;
		characterDataType = MODERN;
		loadAtlas('characters/bf');
		addAnimation('idle', 'idle', 24, false);
		var singAnimations:Array<String> = ['left', 'down', 'up', 'right'];
		for (ani in singAnimations) {
			addAnimation('sing$ani', ani, 24, false);
			addAnimation('sing${ani}miss', 'miss $ani', 24, false);
		}
		setAnimationOffset('idle', -5, 0);
		setAnimationOffset('singLEFT', 5, -6);
		setAnimationOffset('singDOWN', -20, -51);
		setAnimationOffset('singUP', -46, 27);
		setAnimationOffset('singRIGHT', -48, -7);
		setAnimationOffset('singLEFTmiss', 7, 19);
		setAnimationOffset('singDOWNmiss', -15, -19);
		setAnimationOffset('singUPmiss', -46, 27);
		setAnimationOffset('singRIGHTmiss', -44, 19);
		psychOffset.set(0, 350);
		stageCameraOffset.set();
		cameraOffset.set();
		originOffset.set();
		renderType = SPARROW;
		bopFrequency = 2;
		sway = false;
		bop = true;

		@:bypassAccessor this.character = null;
		setBaseSize();
		dance();
		finishAnimation();
	}
}
interface ICharacter extends IFunkinSpriteAnim {
	public var bop(default, set):Bool;
	public var volume(default, set):Float;
	public var animReset(default, set):Float;
	public var specialAnim(default, set):Bool;
	public var idleSuffix(default, set):String;
	public var animSuffix(default, set):String;
	public var side(default, set):CharacterSide;
	public var character(default, set):Null<String>;
	public var conductorInUse(default, set):Conductor;
	
	public function timeAnimSteps(?steps:Float):Void;
	public function animationIsLooping(anim:String):Bool;
	public function playAnimationSoft(anim:String, forced:Bool = false, reversed:Bool = false, frame:Int = 0):Void;
	public function playAnimationSteps(anim:String, forced:Bool = false, ?steps:Float, reversed:Bool = false, frame:Int = 0):Void;
	public function dance(beat:Int = 0, forced:Bool = false):Bool;
}

enum abstract CharacterDataType(String) to String {
	var PSYCH = 'psych';
	var MODERN = 'modern';
}
enum abstract CharacterSide(String) to String {
	var LEFT = 'left';
	var IDGAF = 'none';
	var RIGHT = 'right';
}

typedef PsychCharacterData = {
	var animations:Array<PsychCharacterAnim>;
	var image:String;
	var scale:Float;
	var sing_duration:Float;
	var healthicon:String;

	var position:Array<Float>;
	var camera_position:Array<Float>;
	
	var no_antialiasing:Bool;
	var healthbar_colors:Array<Int>;
	
	var ?flip_x:Bool;
	var ?side:String;
	var ?vocals_file:String;
	var ?_editor_isPlayer:Bool;
}
typedef PsychCharacterAnim = {
	var anim:String;
	var name:String;
	var fps:Int;
	var loop:Bool;
	var indices:Array<Int>;
	var offsets:Array<Int>;
	
	var ?assetPath:String;
}

typedef ModernCharacterData = {
	var name:String;
	var isPixel:Bool;
	var version:String;
	var assetPath:String;
	var animations:Array<ModernCharacterAnim>;
	
	var ?flipX:Bool;
	var ?side:String;
	var ?scale:Float;
	var ?danceEvery:Int;
	var ?singTime:Float;
	var ?renderType:String;
	var ?offsets:Array<Float>;
	var ?cameraOffsets:Array<Float>;
	var ?startingAnimation:String;
	var ?death:ModernCharacterDeathData;
	var ?healthIcon:ModernCharacterHealthIconData;
}
typedef ModernCharacterDeathData = {
	var ?preTransitionDelay:Float;
	var ?cameraOffsets:Array<Float>;
	var ?cameraZoom:Float;
}
typedef ModernCharacterHealthIconData = {
	var id:String;
	var flipX:Bool;
	
	var ?scale:Float;
	var ?isPixel:Bool;
	var ?offsets:Array<Int>;
}
typedef ModernCharacterAnim = {
	var name:String;
	var prefix:String;
	
	var ?flipX:Bool;
	var ?flipY:Bool;
	var ?looped:Bool;
	var ?frameRate:Float;
	var ?assetPath:String;
	var ?offsets:Array<Float>;
	var ?frameIndices:Array<Int>;
}