package funkin.objects;

using StringTools;

class Character extends FunkinSprite {
	public var animReset:Float = 0;
	public var bopFrequency:Int = 2;
	public var singForSteps:Float = 4;
	public var conductorInUse:Conductor = FunkinState.getCurrentConductor();
	
	public var bop:Bool = true;
	public var sway:Bool = false;
	public var specialAnim:Bool = false;
	
	var characterDataType:CharacterDataType;
	public var fallbackCharacter:Null<String>;
	public var character(default, set):Null<String>;
	public var stagePos(default, never):FlxPoint = FlxPoint.get();
	public var psychOffset(default, never):FlxPoint = FlxPoint.get();
	public var originOffset(default, never):FlxPoint = FlxPoint.get();
	public var cameraOffset(default, never):FlxPoint = FlxPoint.get();
	public var stageCameraOffset(default, never):FlxPoint = FlxPoint.get();
	
	public var healthIcon:String = 'bf';
	public var healthIconData:Null<ModernCharacterHealthIconData> = null;
	
	public var deathData:Null<ModernCharacterDeathData> = null;
	
	public var idleSuffix:String = '';
	public var animSuffix:String = '';
	
	public var vocalsLoaded(default, null):Bool = false;
	public var volume(default, set):Float = 1;
	public var vocals:FunkinSound;
	
	public function new(x:Float, y:Float, ?character:String, ?fallback:String) {
		super(x, y);
		rotateOffsets = true;
		vocals = new FunkinSound();
		FlxG.sound.list.add(vocals);
		this.fallbackCharacter = fallback;
		if (character == null) // lol
			this.fallback();
		else
			this.character = character;
		this.onAnimationComplete.add((anim:String) -> {
			playAnimation('$anim-loop');
			playAnimation('$anim-hold');
		});
	}
	
	public function set_volume(newVolume:Float) {
		vocals.volume = newVolume;
		return volume = newVolume;
	}
	public function findPathSuffix(basePath:String = '', baseSuffix:String = '', ?chara:String):String {
		chara ??= character;
		var charaSplit:Array<String> = chara.split('-');
		while (charaSplit.length > 0) {
			var searchSuffix:String = charaSplit.join('-');
			var searchPath:String = Util.pathSuffix(basePath, searchSuffix);
			if (Paths.exists('$searchPath$baseSuffix'))
				return searchSuffix;
			charaSplit.pop();
		}
		return '';
	}
	public function loadVocals(songPath:String, suffix:String = '', ?chara:String):Bool {
		chara ??= character;
		vocalsLoaded = false;
		try {
			var path:String = 'data/songs/$songPath';
			var time:Float = Sys.time();
			if (Paths.exists(path)) {
				var grrr:String = '$path/Voices';
				var variationSuffix:String = Util.pathSuffix('', suffix);
				var characterSuffix:String = findPathSuffix(grrr, '$variationSuffix.ogg', chara);
				if (chara != '' && characterSuffix == '')
					return false;
				var vocalsPath:String = Util.pathSuffix(grrr, characterSuffix) + variationSuffix;
				var ogg:openfl.media.Sound = Paths.ogg(vocalsPath);
				if (ogg != null) {
					vocals.loadEmbedded(ogg);
					vocalsLoaded = true;
					vocals.volume = 0;
					vocals.play();
					vocals.stop();
					vocals.volume = volume;
					Log.info('vocals loaded for character "$character"!! (${Math.round((Sys.time() - time) * 1000) / 1000}s)');
					return true;
				}
			}
		} catch (e:haxe.Exception) {
			Log.error('error when loading vocals -> ${e.message}');
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
	public function animationIsLooping(anim:String) {
		return (currentAnimation == '$anim-loop' || currentAnimation == '$anim-hold');
	}
	public function playAnimationSoft(anim:String, forced:Bool = false, reversed:Bool = false, frame:Int = 0) {
		if (!specialAnim)
			playAnimation(anim, forced, reversed, frame);
	}
	public override function playAnimation(anim:String, forced:Bool = false, reversed:Bool = false, frame:Int = 0) {
		animReset = 0;
		specialAnim = false;
		super.playAnimation(anim + animSuffix, forced, reversed, frame);
	}
	public function playAnimationSteps(anim:String, forced:Bool = false, ?steps:Float, reversed:Bool = false, frame:Int = 0) {
		if (!specialAnim) {
			var sameAnim:Bool = (currentAnimation != anim);
			playAnimation(anim, forced, reversed, frame);
			if (animationExists(anim) && (forced || !sameAnim || isAnimationFinished()))
				timeAnimSteps(steps ?? singForSteps);
		}
	}
	public function dance(beat:Int = 0, forced:Bool = false) {
		if (!forced && (animReset > 0 || bopFrequency <= 0 || !bop || specialAnim))
			return false;

		if (sway)
			playAnimation((beat % 2 == 0 ? 'danceLeft' : 'danceRight') + idleSuffix);
		else if (beat % 2 == 0)
			playAnimation('idle$idleSuffix');

		return true;
	}
	
	public function set_character(newChara:Null<String>) {
		if (character == newChara) return character;
		if (newChara == null) {
			fallback();
		} else {
			loadCharacter(newChara);
		}
		return character = newChara;
	}
	
	public function flip()
		return flipX = !flipX;
	
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
		flipX = charData.flipX;
		smooth = !charData.isPixel;
		deathData = charData.death;
		bopFrequency = charData.danceEvery ?? 1;
		healthIconData = charData.healthIcon;
		healthIcon = healthIconData?.id ?? character;
		singForSteps = Math.max(charData.singTime ?? 8, 1);
		var scale:Float = charData.scale ?? 1;
		this.scale.set(scale, scale);
		if (charData.offsets != null) originOffset.set(charData.offsets[0] ?? 0, charData.offsets[1] ?? 0);
		if (charData.cameraOffsets != null) cameraOffset.set(charData.cameraOffsets[0] ?? 0, charData.cameraOffsets[1] ?? 0);
		
		sway = (animationExists('danceLeft') && animationExists('danceRight'));
		setBaseSize();
		if (charData.startingAnimation != null) {
			dance();
		} else {
			playAnimation(charData.startingAnimation);
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
		flipX = charData.flip_x;
		healthIcon = charData.healthicon;
		smooth = !charData.no_antialiasing;
		singForSteps = charData.sing_duration;
		scale.set(charData.scale, charData.scale);
		psychOffset.set(charData.position[0], charData.position[1]);
		cameraOffset.set(charData.camera_position[0], charData.camera_position[1]);
		
		sway = (animationExists('danceLeft') && animationExists('danceRight'));
		setBaseSize();
		dance();
		finishAnimation();
	}
	
	function setBaseSize() { // lazy, maybe do this without changing cur anim eventually?
		playAnimation(sway ? 'danceLeft' : 'idle');
		finishAnimation();
		updateHitbox();
	}
	public function fallback(?attempted:String) {
		if (fallbackCharacter == null || attempted == null) { // dont attempt if fallback failed to fall back :p
			Log.info('fallback failed lol: loading super fallback character');
			useDefault();
		} else {
			Log.minor('attempting to fall back to "$fallbackCharacter"...');
			loadCharacter();
		}
	}
	public function useDefault() {
		unloadAnimate();
		healthIcon = 'bf';
		renderType = SPARROW;
		characterDataType = MODERN;
		loadAtlas('characters/bf');
		addAnimation('idle', 'BF idle dance', 24, false);
		var singAnimations:Array<String> = ['LEFT', 'DOWN', 'UP', 'RIGHT'];
		for (ani in singAnimations) {
			addAnimation('sing$ani', 'BF NOTE ${ani}0', 24, false);
			addAnimation('sing${ani}miss', 'BF NOTE ${ani} MISS', 24, false);
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

enum CharacterDataType {
	PSYCH;
	MODERN;
}

typedef PsychCharacterData = {
	var animations:Array<PsychCharacterAnim>;
	var image:String;
	var scale:Float;
	var sing_duration:Float;
	var healthicon:String;

	var position:Array<Float>;
	var camera_position:Array<Float>;

	var flip_x:Bool;
	var no_antialiasing:Bool;
	var healthbar_colors:Array<Int>;
	@:optional var vocals_file:String;
	@:optional var _editor_isPlayer:Bool;
}
typedef PsychCharacterAnim = {
	var anim:String;
	var name:String;
	var fps:Int;
	var loop:Bool;
	var indices:Array<Int>;
	var offsets:Array<Int>;
	@:optional var assetPath:String; // for quick tests
}

typedef ModernCharacterData = {
	var flipX:Bool;
	var name:String;
	var isPixel:Bool;
	var version:String;
	var assetPath:String;
	var animations:Array<ModernCharacterAnim>;
	@:optional var scale:Float;
	@:optional var danceEvery:Int;
	@:optional var singTime:Float;
	@:optional var renderType:String;
	@:optional var offsets:Array<Float>;
	@:optional var cameraOffsets:Array<Float>;
	@:optional var startingAnimation:String;
	@:optional var death:ModernCharacterDeathData;
	@:optional var healthIcon:ModernCharacterHealthIconData;
}
typedef ModernCharacterDeathData = {
	@:optional var preTransitionDelay:Float;
	@:optional var cameraOffsets:Array<Float>;
	@:optional var cameraZoom:Float;
}
typedef ModernCharacterHealthIconData = {
	var id:String;
	var flipX:Bool;
	@:optional var scale:Float;
	@:optional var isPixel:Bool;
	@:optional var offsets:Array<Int>;
}
typedef ModernCharacterAnim = {
	var name:String;
	var prefix:String;
	@:optional var flipX:Bool;
	@:optional var flipY:Bool;
	@:optional var looped:Bool;
	@:optional var frameRate:Float;
	@:optional var assetPath:String;
	@:optional var offsets:Array<Float>;
	@:optional var frameIndices:Array<Int>;
}