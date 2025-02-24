package funkin.objects;

import funkin.backend.play.Chart;
import funkin.objects.CharacterGroup;
import funkin.objects.Character;

using StringTools;

//THIS IS ALL KINDOF A MESS BUT IT WORKS??? I THINK
class Stage extends FlxSpriteGroup {
	var chart:Chart;
	public var name:String;
	public var json:Dynamic;
	public var library:String = '';
	public var hasContent:Bool = false;
	public var stageValid:Bool = false;
	public var format:StageFormat = NONE;
	public var props:Map<String, FunkinSprite> = new Map();
	public var characters:Map<String, CharacterGroup> = new Map();

	public var zoom:Float = 1;

	var state = FlxG.state;
	
	public function new(?chart:Chart) {
		super();
		this.chart = chart;
	}
	
	public function setup(?stageId:String, ?chartData:Chart) {
		// right now only works with vslice stage jsons
		chartData ??= chart;
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
        var state:FunkinState = cast(FlxG.state, FunkinState);
        var scriptPath:String = 'scripts/stages/$stageId.hx';
        if (Paths.exists(scriptPath)) {
            if (state != null)
            	state.hscripts.loadFromPaths(scriptPath);
            hasContent = true;
        }
        
        if (state != null)
        	state.hscripts.run('setupStage', [stageId, this]);
        
        if (!hasContent) {
			Log.warning('no stage content (json or script): loading fallback stage');
			loadFallback();
		}
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
		for (prop in props) {
			if (prop != null && prop.alive && prop.exists && Std.isOfType(prop, IBopper)) {
				var bopper:IBopper = cast prop;
				bopper.dance(beat);
			}
		}
		for (chara in characters) {
			if (chara != null && chara.alive && chara.exists)
				chara.dance(beat);
		}
	}
	public function destroyProps() {
		for (prop in props) prop.destroy();
	}
	
	public function getProp(name:String):FunkinSprite {
		return props[name];
	}
	public function getCharacter(name:String):CharacterGroup {
		return characters[name];
	}
	public function loadModernStageData(data:ModernStageData) {
		library = data.directory ?? data.library ?? '';

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
				if (prop.danceEvery != null)
					propSprite.bopFrequency = prop.danceEvery;
				if (prop.startingAnimation != null) {
					propSprite.playAnimation(prop.startingAnimation);
					propSprite.startingAnimation = prop.startingAnimation;
				}
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
		
		var charas:Dynamic = data.characters;
		for (name in Reflect.fields(charas)) {
			var chara:ModernStageChar = Reflect.field(charas, name);
			var char:Null<String> = null;
			
			var side:CharacterSide = (switch (name) {
				case 'bf': RIGHT;
				case 'gf': IDGAF;
				default: LEFT;
			});
			if (chart != null) {
				char = Reflect.field(chart, switch (name) {
					case 'bf': 'player1';
					case 'dad': 'player2';
					case 'gf': 'player3';
					default: name;
				});
			}
			
			var charaGroup:CharacterGroup = new CharacterGroup(chara.position[0], chara.position[1], char, side, name);
			add(charaGroup);
			charaGroup.zIndex = chara.zIndex;
			charaGroup.stageCameraOffset.set(chara.cameraOffsets[0], chara.cameraOffsets[1]);
            if (chara.scale != null) charaGroup.scale.set(chara.scale, chara.scale);
            
			this.characters[name] = charaGroup;
		}
	}
	public function loadFallback() {
		var basicBG:StageProp = new StageProp();
		props['basicBG'] = basicBG;
		basicBG.loadTexture('bg');
		basicBG.setPosition(-basicBG.width * .5, (FlxG.height - basicBG.height) * .5 + 75);
		basicBG.scrollFactor.set(.95, .95);
		basicBG.scale.set(2.25, 2.25);
		basicBG.zIndex = 0;
		add(basicBG);
		loadCharactersGeneric();
	}
	function loadCharactersGeneric() {
		var player1:CharacterGroup = new CharacterGroup(400, 750, chart?.player1 ?? 'bf', RIGHT, 'bf');
		var player2:CharacterGroup = new CharacterGroup(-400, 750, chart?.player2 ?? 'dad', LEFT, 'dad');
		var player3:CharacterGroup = new CharacterGroup(0, 680, chart?.player3 ?? 'gf', IDGAF, 'gf');
		player1.zIndex = 300;
		player2.zIndex = 200;
		player3.zIndex = 100;
		characters['bf'] = player1;
		characters['dad'] = player2;
		characters['gf'] = player3;
		for (chara in [player1, player2, player3]) {
			add(chara);
		}
	}
}

class StageProp extends FunkinSprite implements IBopper { // maybe unify character with props?
	public var bop(default, set):Bool = true;
	public var idleSuffix(default, set):String = '';
	
	public var sway:Bool = false;
	public var bopFrequency:Int = 0;
	public var animated:Bool = false;
	public var startingAnimation:Null<String> = null;

	public function new(x:Float = 0, y:Float = 0) {
		super(x, y);
	}
	public function dance(beat:Int = 0, forced:Bool = false) {
		if (bopFrequency <= 0 || !animated || !bop) return false;
		
		if (sway) {
			playAnimation(beat % 2 == 0 ? 'danceLeft$idleSuffix' : 'danceRight$idleSuffix');
		} else {
			if (beat % bopFrequency == 0)
				playAnimation(startingAnimation ?? 'idle$idleSuffix', forced);
		}
		return true;
	}
	
	function set_bop(value:Bool):Bool { return bop = value; }
	function set_idleSuffix(value:String):String { return idleSuffix = value; }
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
	
	var ?directory:String;
	var ?library:String;
	var ?version:String;
}
typedef ModernStageChar = {
	var zIndex:Int;
	var position:Array<Float>;
	var cameraOffsets:Array<Float>;
	
	var ?scale:Float;
}
typedef ModernStageProp = {
	var zIndex:Int;
	var name:String;
	var assetPath:String;
	var position:Array<Float>;
	var animations:Array<Character.ModernCharacterAnim>;
	
	var ?alpha:Float;
	var ?isPixel:Bool;
	var ?danceEvery:Int;
	var ?animType:String;
	var ?scale:Array<Float>;
	var ?scroll:Array<Float>;
	var ?startingAnimation:String;
}