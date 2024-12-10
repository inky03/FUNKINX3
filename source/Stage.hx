package;

using StringTools;

//THIS IS ALL KINDOF A MESS BUT IT WORKS??? I THINK
class Stage extends FlxSpriteGroup {
	var song:Song;
	public var name:String;
	public var json:Dynamic;
	public var hasContent:Bool = false;
	public var stageValid:Bool = false;
	public var format:StageFormat = NONE;
	public var props:Map<String, StageProp> = new Map();
	public var characters:Map<String, Character> = new Map();

	public var zoom:Float = 1;

	var state = FlxG.state;

	public function new(?stageId:String, ?songData:Song) {
		// right now only works with vslice stage jsons
		super();

		song = songData;
        if (stageId != null) {
    		Log.minor('loading stage "$stageId"');

    		var jsonPath:String = 'data/stages/$stageId.json';
    		if (Paths.exists(jsonPath)) {
    			var time:Float = Sys.time();
    			try {
    				var content:String = Paths.text(jsonPath);
    				var jsonData:Dynamic = TJSON.parse(content);
    				loadModernStageData(jsonData);
    				json = jsonData;
    				format = MODERN;
    				stageValid = true;
    				hasContent = true;
    				Log.info('stage loaded successfully! (${FlxMath.roundDecimal(Sys.time() - time, 3)}s)');
    			} catch (e:haxe.Exception) {
    				format = NONE;
    				Log.error('error while loading stage "$stageId"... -> ${e.details()}');
    			}
    		} else {
    			Log.warning('stage "$stageId" not found...');
				Log.minor('verify path:');
				Log.minor('- $jsonPath');
    		}
        }
        
        // loads hscript file
        var state:MusicBeatState = cast(FlxG.state, MusicBeatState);
        var scriptPath:String = 'scripts/stages/${stageId}.hx';
        if (Paths.exists(scriptPath)) {
            if (state != null)
            	state.hscripts.loadFromPaths(scriptPath);
            hasContent = true;
        }

        if (state != null) {
        	state.hscripts.set('stage', this);
        	state.hscripts.run('setupStage', [stageId, this]);
        }

        if (!hasContent) {
			Log.warning('no stage content (json or script): loading fallback stage');
			loadFallback();
		}

		startCharPositions();
		sortZIndex();
	}
	
	public function sortZIndex() {
		sort(Util.sortZIndex, FlxSort.ASCENDING);
	}
	public function insertZIndex(obj:FlxSprite) {
		if (members.contains(obj)) remove(obj);
		var low:Float = Math.POSITIVE_INFINITY;
		for (pos => mem in members) {
			low = Math.min(mem.zIndex, low);
			if (obj.zIndex < mem.zIndex) {
				insert(pos, obj);
				return obj;
			}
		}
		if (obj.zIndex < low) {
			insert(0, obj);
		} else {
			add(obj);
		}
		return obj;
	}

	public function beatHit(beat:Int) {
		for (prop in props) prop.dance(beat);
		for (chara in characters) chara.dance(beat);
	}
	public function destroyProps() {
		for (prop in props) prop.destroy();
	}
	
	public function getProp(name:String):StageProp {
		return props[name];
	}
	public function getCharacter(name:String):Character {
		return characters[name];
	}
	public function loadModernStageData(data:ModernStageData) {
		var library:Null<String> = data.library;
		var charas:Dynamic = data.characters;

		zoom = data.cameraZoom;
		for (prop in data.props) {
			var propSprite:StageProp = new StageProp();
			add(propSprite);
			propSprite.zIndex = prop.zIndex;
			propSprite.x = prop.position[0];
			propSprite.y = prop.position[1];
			propSprite.alpha = prop.alpha ?? 1;
			propSprite.smooth = !(prop.isPixel ?? false);
			propSprite.animated = (prop?.animations?.length ?? 0) > 0;
			propSprite.bopFrequency = prop.danceEvery ?? 0;
			if (propSprite.animated) { // this is stupid
				switch (prop.animType) {
					case 'packer':
						propSprite.loadAtlas(prop.assetPath, library, PACKER);
					default:
						propSprite.loadAtlas(prop.assetPath, library, SPARROW);
				}
				for (animation in prop.animations) {
					propSprite.addAnimation(animation.name, animation.prefix, animation.frameRate ?? 24, animation.looped ?? false, animation.frameIndices, animation.flipX, animation.flipY);
					if (animation.offsets != null) propSprite.setAnimationOffset(animation.name, animation.offsets[0], animation.offsets[1]);
				}
				if (prop.startingAnimation != null)
					propSprite.playAnimation(prop.startingAnimation);
			} else {
				if (prop.assetPath.startsWith('#'))
					propSprite.makeGraphic(1, 1, FlxColor.fromString(prop.assetPath));
				else
					propSprite.loadTexture(prop.assetPath, library);
			}
			propSprite.sway = (propSprite.animationExists('danceLeft') && propSprite.animationExists('danceRight'));
			if (prop.scroll != null) propSprite.scrollFactor.set(prop.scroll[0], prop.scroll[1]);
			if (prop.scale != null) propSprite.scale.set(prop.scale[0], prop.scale[1]);
			var assetName:String = prop.name ?? prop.assetPath;
			propSprite.updateHitbox();
			
			this.props[assetName] = propSprite;
		}
		for (name in Reflect.fields(charas)) {
			var chara:ModernStageChar = Reflect.field(charas, name);
			var char:Null<String> = null;
			if (song != null) {
				char = Reflect.field(song, switch (name) {
					case 'bf': 'player1';
					case 'dad': 'player2';
					case 'gf': 'player3';
					default: null;
				});
			}
			var charaSprite:Character = new Character(0, 0, char, name);
			add(charaSprite);
			charaSprite.zIndex = chara.zIndex;
			charaSprite.stageCameraOffset.set(chara.cameraOffsets[0], chara.cameraOffsets[1]);
			charaSprite.stagePos.set(chara.position[0] - charaSprite.width * .5, chara.position[1] - charaSprite.height);
            if (chara.scale != null) charaSprite.scale.set(chara.scale, chara.scale);

			this.characters[name] = charaSprite;
		}
		this.characters['bf']?.flip();
	}
	public function loadFallback() {
		var basicBG:StageProp = props['basicBG'] = new StageProp();
		basicBG.loadTexture('bg');
		basicBG.setPosition(-basicBG.width * .5, (FlxG.height - basicBG.height) * .5 + 75);
		basicBG.scrollFactor.set(.95, .95);
		basicBG.scale.set(2.25, 2.25);
		basicBG.zIndex = 0;
		add(basicBG);
		loadCharactersGeneric();
	}
	function loadCharactersGeneric() {
		var player1:Character = new Character(0, 0, song?.player1 ?? 'bf', 'bf');
		var player2:Character = new Character(0, 0, song?.player2 ?? 'dad', 'dad');
		var player3:Character = new Character(0, 0, song?.player3 ?? 'gf', 'gf');
		player1.stagePos.set(250, 750 - player1.height);
		player2.stagePos.set(-250 - player2.width, 750 - player2.height);
		player3.stagePos.set(-player3.width * .5, 680 - player3.height);
		player1.zIndex = 300;
		player2.zIndex = 200;
		player3.zIndex = 100;
		player1.flip();
		characters['bf'] = player1;
		characters['dad'] = player2;
		characters['gf'] = player3;
		for (chara in [player1, player2, player3]) {
			add(chara);
		}
	}
	function startCharPositions() {
		for (chara in characters) {
			chara.setPosition(chara.stagePos.x + chara.originOffset.x, chara.stagePos.y + chara.originOffset.y);
		}
	}
}

class StageProp extends FunkinSprite { // maybe unify character with props?
	public var bop:Bool = true;
	public var sway:Bool = false;
	public var bopFrequency:Int = 0;
	public var animated:Bool = false;
	public var idleSuffix:String = '';
	public var startingAnimation:Null<String> = null;

	public function new(x:Float = 0, y:Float = 0) {
		super(x, y);
	}
	public function dance(beat:Int = 0) {
		if (bopFrequency <= 0 || !animated || !bop) return false;
		if (sway) {
			playAnimation(beat % 2 == 0 ? 'danceLeft$idleSuffix' : 'danceRight$idleSuffix');
		} else {
			if (beat % bopFrequency == 0)
				playAnimation(startingAnimation ?? 'idle$idleSuffix');
		}
		return true;
	}
}

enum StageFormat {
	MODERN;
	PSYCH;
	NONE;
}

typedef ModernStageData = {
	var name:String;
	var cameraZoom:Float;
	var characters:Dynamic;
	var props:Array<ModernStageProp>;
	@:optional var library:String;
	@:optional var version:String;
}
typedef ModernStageChar = {
	var zIndex:Int;
	var position:Array<Float>;
	var cameraOffsets:Array<Float>;
	@:optional var scale:Float;
}
typedef ModernStageProp = {
	var zIndex:Int;
	var name:String;
	var assetPath:String;
	var position:Array<Float>;
	var animations:Array<Character.ModernCharacterAnim>;
	@:optional var alpha:Float;
	@:optional var isPixel:Bool;
	@:optional var danceEvery:Int;
	@:optional var animType:String;
	@:optional var scale:Array<Float>;
	@:optional var scroll:Array<Float>;
	@:optional var startingAnimation:String;
}