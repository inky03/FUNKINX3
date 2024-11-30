using StringTools;

class Character extends FunkinSprite {
	public var bop:Bool = true;
	public var sway:Bool = false;
	public var animReset:Float = 0;
	public var bopFrequency:Int = 2;
	public var singForSteps:Float = 4;
	public var specialAnim:Bool = false;
	public var healthIcon:String = 'bf';
	public var sparrowsList:Array<String>;
	public var fallbackCharacter:Null<String>;
	public var characterDataType:CharacterDataType;
	public var character(default, set):Null<String>;
	public var stagePos(default, never):FlxPoint = FlxPoint.get();
	public var psychOffset(default, never):FlxPoint = FlxPoint.get();
	public var originOffset(default, never):FlxPoint = FlxPoint.get();
	public var cameraOffset(default, never):FlxPoint = FlxPoint.get();

	public var idleSuffix:String = '';
	public var animSuffix:String = '';
	
	public var vocalsLoaded(default, null):Bool = false;
	public var volume(default, set):Float = 1;
	public var vocals:FlxSound;
	
	public function new(x:Float, y:Float, ?character:String, ?fallback:String) {
		super(x, y);
		sparrowsList = [];
		rotateOffsets = true;
		vocals = new FlxSound();
		FlxG.sound.list.add(vocals);
		this.fallbackCharacter = fallback;
		if (character == null) // lol
			this.fallback();
		else
			this.character = character;
		this.animation.finishCallback = (anim:String) -> {
			playAnimation('$anim-loop');
			playAnimation('$anim-hold');
		};
	}

	public function set_volume(newVolume:Float) {
		vocals.volume = newVolume;
		return volume = newVolume;
	}
	public function loadVocals(songPath:String, suffix:String = '', ?chara:String) {
		vocalsLoaded = false;
		var paths:Array<String> = ['data/songs/$songPath/', 'songs/$songPath/'];
		if (chara == null) chara = character;
		try {
			for (path in paths) {
				if (Paths.exists(path)) {
					var vocalsPath:String = path + Util.pathSuffix(Util.pathSuffix('Voices', chara), suffix);
					// Log.minor('attempting to load vocals from $vocalsPath...');
					vocals.loadEmbedded(Paths.ogg(vocalsPath));
					if (vocals.length > 0) {
						vocalsLoaded = true;
						vocals.play();
						vocals.stop();
						vocals.volume = volume;
						Log.info('vocals loaded for character "$character"!!');
						return true;
					}
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
		animReset = (steps ?? singForSteps) * Conductor.global.stepCrochet * .001;
	}
	public function animationIsLooping(anim:String) {
		return (currentAnimation == '$anim-loop' || currentAnimation == '$anim-hold');
	}
	public function playAnimationSoft(anim:String, forced:Bool = false, reversed:Bool = false, frame:Int = 0) {
		if (!specialAnim)
			playAnimation(anim, forced, reversed, frame);
	}
	public override function playAnimation(anim:String, forced:Bool = false, reversed:Bool = false, frame:Int = 0) {
		specialAnim = false;
		super.playAnimation(anim + animSuffix, forced, reversed, frame);
	}
	public function playAnimationSteps(anim:String, forced:Bool = false, ?steps:Float, reversed:Bool = false, frame:Int = 0) {
		if (!specialAnim) {
			var sameAnim:Bool = (currentAnimation != anim);
			if (animationList.exists(anim) && (forced || !sameAnim || isAnimationFinished()))
				timeAnimSteps(steps ?? singForSteps);
			playAnimation(anim, forced, reversed, frame);
		}
	}
	public function dance(beat:Int = 0) {
		if (animReset > 0 || bopFrequency <= 0 || !bop || specialAnim) return false;
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

	public override function loadAtlas(path:String, ?library:String):FunkinSprite {
		sparrowsList.resize(0);
		sparrowsList.push(path);
		super.loadAtlas(path, library);
		return cast this;
	}
	public override function addAtlas(path:String, overwrite:Bool = false, ?library:String):FunkinSprite {
		if (sparrowsList.contains(path)) return this;
		sparrowsList.push(path);
		super.addAtlas(path, overwrite);
		return cast this; // kys
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
			// case 'packer': renderType = PACKER; TODO: implement...
			case 'sparrow' | 'multisparrow':
				this.renderType = SPARROW;
				addAtlas(charData.assetPath, true);
			case 'animateatlas':
				this.renderType = ANIMATEATLAS;
				loadAnimate(charData.assetPath);
			default: throw new haxe.Exception('Render type "${charData.renderType}" is not supported!!');
		}

		var animations:Array<ModernCharacterAnim> = charData.animations;
		for (animation in animations) {
			addAnimation(animation.name, animation.prefix, animation.frameRate ?? 24, animation.looped ?? false, animation.frameIndices, animation.assetPath);
			if (animation.offsets != null)
				setAnimationOffset(animation.name, animation.offsets[0], animation.offsets[1]);
		}
		flipX = charData.flipX;
		smooth = !charData.isPixel;
		bopFrequency = charData.danceEvery ?? 1;
		healthIcon = charData?.healthIcon?.id ?? character;
		singForSteps = Math.max(charData.singTime ?? 8, 1);
		var scale:Float = charData.scale ?? 1;
		this.scale.set(scale, scale);
		if (charData.offsets != null) originOffset.set(charData.offsets[0] ?? 0, charData.offsets[1] ?? 0);
		if (charData.cameraOffsets != null) cameraOffset.set(charData.cameraOffsets[0] ?? 0, charData.cameraOffsets[1] ?? 0);
		
		sway = (animationList.exists('danceLeft') && animationList.exists('danceRight'));
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
			addAtlas(sparrow.trim(), true);
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
		
		sway = (animationList.exists('danceLeft') && animationList.exists('danceRight'));
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
		originOffset.set(0, 0);
		cameraOffset.set(0, 0);
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
	@:optional var healthIcon:ModernCharacterIcon;
}
typedef ModernCharacterIcon = {
	var id:String;
	var flipX:Bool;
	@:optional var scale:Float;
	@:optional var isPixel:Bool;
	@:optional var offsets:Array<Int>;
}
typedef ModernCharacterAnim = {
	var name:String;
	var prefix:String;
	@:optional var flipX:Bool; // todo
	@:optional var flipY:Bool;
	@:optional var looped:Bool;
	@:optional var frameRate:Float;
	@:optional var assetPath:String;
	@:optional var offsets:Array<Float>;
	@:optional var frameIndices:Array<Int>;
}