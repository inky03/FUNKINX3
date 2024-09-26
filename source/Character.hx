using StringTools;

class Character extends FunkinSprite {
	public var sway:Bool = false;
	public var animReset:Float = 0;
	public var singForSteps:Float = 4;
	public var sparrowsList:Array<String>;
	public var fallbackCharacter:Null<String>;
	public var character(default, set):Null<String>;
	public var animationList:Map<String, CharacterAnim> = [];
	public var startPos(default, never):FlxPoint = FlxPoint.get();
	public var cameraOffset(default, never):FlxPoint = FlxPoint.get();
	
	public function new(x:Float, y:Float, ?character:String, ?fallback:String) {
		super(x, y);
		sparrowsList = [];
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
	public override function destroy() {
		startPos.destroy();
		super.destroy();
	}
	
	public override function update(elapsed:Float) {
		super.update(elapsed);
		if (animReset > 0) {
			animReset -= elapsed;
			if (animReset <= 0) {
				animReset = 0;
				dance();
			}
		}
	}
	
	public function timeAnimSteps(steps:Float = 4) {
		animReset = steps * Conductor.stepCrochet * .001;
	}
	public function animationIsLooping(anim:String) {
		return (animation.name == '$anim-loop' || animation.name == '$anim-hold');
	}
	public override function playAnimation(anim:String, forced:Bool = false) {
		if (!forced && animationIsLooping(anim))
			return;
		preloadAnimAsset(anim);
		super.playAnimation(anim, forced);
	}
	public function dance(beat:Int = 0) {
		if (animReset > 0) return false;
		if (sway)
			playAnimation(beat % 2 == 0 ? 'danceLeft' : 'danceRight');
		else if (beat % 2 == 0)
			playAnimation('idle');
		return true;
	}
	public function preloadAnimAsset(anim:String) { // preloads animation with a different spritesheet path
		var animData:CharacterAnim = animationList[anim];
		if (animData != null && animData.assetPath != null) {
			addAtlas(animData.assetPath, true);
			addAnimation(anim, animData.prefix, animData.fps, animData.loop, animData.frameIndices);
		}
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

	public override function loadAtlas(path:String):FunkinSprite {
		animationList.clear();
		sparrowsList = [path];
		super.loadAtlas(path);
		return cast this;
	}
	public override function addAtlas(path:String, o:Bool = false):FunkinSprite {
		if (sparrowsList.contains(path)) return this;
		sparrowsList.push(path);
		super.addAtlas(path, o);
		return cast this; // kys
	}

	public function loadCharacter(?character:String) { // no character provided attempts to load fallback
		var charLoad:String = character ?? fallbackCharacter;
		var charPath:String = 'characters/$charLoad.json';
		if (!Paths.exists(charPath)) {
			Sys.println('failed to load character "$charLoad"');
			Sys.println('verify path:');
			Sys.println('- $charPath');
			fallback(character);
			return this;
		}
		if (character != null) Sys.println('loading character "$charLoad"');
		var time:Float = Sys.time();
		try {
			frames = null;
			var content:String = Paths.text(charPath);
			var charData:PsychCharacterData = TJSON.parse(content);
			var sparrows:Array<String> = charData.image.split(',');
			var animations:Array<PsychCharacterAnim> = charData.animations;
			for (sparrow in sparrows) { // no choice with psych 1 multisparrow lmao
				addAtlas(sparrow.trim(), true);
			}
			for (animation in animations) {
				addAnimation(animation.anim, animation.name, animation.fps, animation.loop, animation.indices, animation.assetPath);
				offsets.set(animation.anim, FlxPoint.get(animation.offsets[0], animation.offsets[1]));
			}
			smooth = !charData.no_antialiasing;
			singForSteps = charData.sing_duration;
			scale.set(charData.scale, charData.scale);
			changeBasePos(charData.position[0], charData.position[1]);
			cameraOffset.set(charData.camera_position[0], charData.camera_position[1]);
			sway = (animationList.exists('danceLeft') && animationList.exists('danceRight'));

			@:bypassAccessor this.character = character;
			setBaseSize();
			dance();
		} catch (e:haxe.Exception) {
			Sys.println('error while loading character "$charLoad"... -> ${e.details()}');
			fallback(character);
			return this;
		}
		Sys.println('character loaded successfully! (${Math.round((Sys.time() - time) * 1000) / 1000}s)');
		return this;
	}

	public function changeBasePos(x:Float = 0, y:Float = 0) {
		this.x -= startPos.x;
		this.y -= startPos.y;
		startPos.set(x, y);
		this.x += startPos.x;
		this.y += startPos.y;
	}
	function setBaseSize() { // lazy, maybe do this without changing cur anim eventually?
		playAnimation(sway ? 'danceLeft' : 'idle');
		animation.finish();
		updateHitbox();
	}
	public function fallback(?attempted:String) {
		if (fallbackCharacter == null || attempted == null) { // dont attempt if fallback failed to fall back :p
			useDefault();
		} else {
			Sys.println('attempting to fall back to "$fallbackCharacter"...');
			loadCharacter();
		}
	}
	public function useDefault() {
		loadAtlas('characters/bf');
		addAnimation('idle', 'BF idle dance', 24, false);
		var singAnimations:Array<String> = ['LEFT', 'DOWN', 'UP', 'RIGHT'];
		for (ani in singAnimations) {
			addAnimation('sing$ani', 'BF NOTE ${ani}0', 24, false);
			addAnimation('sing${ani}miss', 'BF NOTE ${ani} MISS', 24, false);
		}
		offsets.set('idle', FlxPoint.get(-5, 0));
		offsets.set('singLEFT', FlxPoint.get(5, -6));
		offsets.set('singDOWN', FlxPoint.get(-20, -51));
		offsets.set('singUP', FlxPoint.get(-46, 27));
		offsets.set('singRIGHT', FlxPoint.get(-48, -7));
		offsets.set('singLEFTmiss', FlxPoint.get(7, 19));
		offsets.set('singDOWNmiss', FlxPoint.get(-15, -19));
		offsets.set('singUPmiss', FlxPoint.get(-46, 27));
		offsets.set('singRIGHTmiss', FlxPoint.get(-44, 19));
		cameraOffset.set(0, 0);
		changeBasePos(0, 350);
		sway = false;

		@:bypassAccessor this.character = null;
		setBaseSize();
		dance();
	}
	public function addAnimation(name:String, prefix:String, fps:Float = 24, loop:Bool = false, frameIndices:Null<Array<Int>> = null, assetPath:Null<String> = null) {
		if (assetPath == null) { // wait for the asset to be loaded
			if (frameIndices == null || frameIndices.length == 0) {
				animation.addByPrefix(name, prefix, fps, loop);
			} else {
				animation.addByIndices(name, prefix, frameIndices, '', fps, loop);
			}
		}
		animationList[name] = {prefix: prefix, fps: fps, loop: loop, assetPath: assetPath, frameIndices: frameIndices};
	}
}

typedef CharacterAnim = {
	var prefix:String;
	var fps:Float;
	var loop:Bool;
	@:optional var assetPath:String;
	@:optional var frameIndices:Array<Int>;
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