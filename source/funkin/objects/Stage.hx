package funkin.objects;

import funkin.backend.play.Chart;
import funkin.backend.scripting.*;
import funkin.objects.CharacterGroup;
import funkin.objects.Character;

using StringTools;

//THIS IS ALL KINDOF A MESS BUT IT WORKS??? I THINK
class Stage extends FunkinSpriteGroup {
	public var stage:String;
	public var json:Dynamic;
	public var library:String = '';
	public var hasContent:Bool = false;
	public var stageValid:Bool = false;
	public var format:StageFormat = NONE;
	public var loadCharacters:Bool = true;
	public var props:Map<String, FunkinSprite> = new Map();
	public var characters:Map<String, CharacterGroup> = new Map();
	
	public var hscripts:HScriptGroup = new HScriptGroup();
	public var zoom:Float = 1;

	var state:FunkinState;
	
	public function new(?stageId:String) {
		super();
		
		this.stage = stageId;
		
		setup(stageId);
	}
	public override function destroy():Void {
		hscripts.destroy();
		super.destroy();
	}
	
	public function setup(?stageId:String) {
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
		
		if (!stageValid) {
			Log.warning('no stage content (json or script): loading fallback stage');
			loadFallbackStage();
		}
	}
	public function addCharacters(?baseChart:Chart):Void {
		switch (format) {
			case MODERN:
				loadModernCharData(json, baseChart);
			default:
				loadFallbackCharacters(baseChart);
		}
	}
	public function start(state:FunkinState):Void { // runs stage hscript
		var scriptPath:String = 'scripts/stages/$stage.hx';
		if (Paths.exists(scriptPath)) {
			hscripts.concat(state.hscripts.loadFromPaths(scriptPath));
			hasContent = true;
		}
		
		if (state != null)
			state.hscripts.run('setupStage', [stage, this]);
	}
	
	public function beatHit(beat:Int):Void {
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
	public function getProp(name:String):FunkinSprite {
		return props.get(name);
	}
	public function getCharacter(name:String):CharacterGroup {
		return characters.get(name);
	}
	
	function loadModernStageData(data:ModernStageData):Void {
		library = data.directory ?? data.library ?? '';
		Paths.library = library;

		zoom = data.cameraZoom;
		for (prop in data.props) {
			var propSprite:StageProp = new StageProp();
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
			insertZIndex(propSprite);
			propSprite.sway = (propSprite.animationExists('danceLeft') && propSprite.animationExists('danceRight'));
			if (prop.scroll != null) propSprite.scrollFactor.set(prop.scroll[0], prop.scroll[1]);
			if (prop.scale != null) propSprite.scale.set(prop.scale[0], prop.scale[1]);
			var assetName:String = prop.name ?? prop.assetPath;
			propSprite.updateHitbox();
			
			this.props.set(assetName, propSprite);
		}
	}
	function loadFallbackStage():Void {
		var basicBG:StageProp = new StageProp();
		props['basicBG'] = basicBG;
		basicBG.loadTexture('bg');
		basicBG.setPosition(-basicBG.width * .5, (FlxG.height - basicBG.height) * .5 + 75);
		basicBG.scrollFactor.set(.95, .95);
		basicBG.scale.set(2.25, 2.25);
		basicBG.zIndex = 0;
		add(basicBG);
	}
	function loadModernCharData(data:ModernStageData, ?chart:Chart):Void {
		var charas:Dynamic = data.characters;
		
		for (name in Reflect.fields(charas)) {
			var chara:ModernStageChar = Reflect.field(charas, name);
			
			var side:CharacterSide = (switch (name) {
				case 'bf': RIGHT;
				case 'gf': IDGAF;
				default: LEFT;
			});
			var char:Null<String> = (switch (name) {
				case 'bf': chart?.player1;
				case 'dad': chart?.player2;
				case 'gf': chart?.player3;
				default: name;
			});
			
			var charaGroup:CharacterGroup = new CharacterGroup(chara.position[0], chara.position[1], char, side, name);
			insertZIndex(charaGroup);
			charaGroup.zIndex = chara.zIndex;
			charaGroup.stageCameraOffset.set(chara.cameraOffsets[0], chara.cameraOffsets[1]);
			if (chara.scale != null) charaGroup.scale.set(chara.scale, chara.scale);
						
			this.characters.set(name, charaGroup);
		}
	}
	function loadFallbackCharacters(?chart:Chart):Void {
		var player1:CharacterGroup = new CharacterGroup(400, 750, chart?.player1 ?? 'bf', RIGHT, 'bf');
		var player2:CharacterGroup = new CharacterGroup(-400, 750, chart?.player2 ?? 'dad', LEFT, 'dad');
		var player3:CharacterGroup = new CharacterGroup(0, 680, chart?.player3 ?? 'gf', IDGAF, 'gf');
		player1.zIndex = 300;
		player2.zIndex = 200;
		player3.zIndex = 100;
		characters.set('bf', player1);
		characters.set('dad', player2);
		characters.set('gf', player3);
		
		for (chara in characters)
			insertZIndex(chara);
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