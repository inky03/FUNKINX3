package funkin.backend.play;

import funkin.objects.play.Lane;

using Lambda;

typedef NoteStyleAsset = flixel.util.typeLimit.OneOfTwo<String, NoteStyle>;

class NoteStyle {
	public static var defaultColors:Array<FlxColor> = [FlxColor.RED, FlxColor.LIME, FlxColor.BLUE];
	public static var defaultDirection:String = 'left';
	
	public static var cache:Map<String, NoteStyle> = [];
	
	public var path:String;
	public var name:String;
	public var author:String;
	public var info:NoteStyleInfo;
	public var data:NoteStyleData;
	public var assets:Map<String, NoteStyleAssetData> = [];
	public var modColors:Map<NoteStyleColorMod, Array<Array<FlxColor>>> = [];
	public var colors:Array<Array<FlxColor>> = [];
	
	public var _success(default, null):Bool = false;
	
	public static function wipe():Void {
		cache.clear();
	}
	public static function exists(path:String):Bool {
		return (Paths.exists('data/styles/notes/$path.json') || cache.exists(path));
	}
	public static function fetch(?asset:NoteStyleAsset):NoteStyle {
		if (asset == null)
			return null;
		if (Std.isOfType(asset, NoteStyle))
			return asset;
		
		var path:String = cast asset;
		if (cache.exists(path))
			return cache[path];
		
		var style:NoteStyle = new NoteStyle(path);
		if (style._success) {
			cache[path] = style;
			return style;
		}
		
		return null;
	}
	public static function getPath(?style:NoteStyleAsset):String {
		if (Std.isOfType(style, NoteStyle)) {
			return cast(style, NoteStyle).path;
		} else if (Std.isOfType(style, String)) {
			return cast(style, String);
		} else {
			return '';
		}
	}
	
	public function new(path:String) {
		this.path = path;
		loadStyle(path);
	}
	function loadStyle(path:String):Bool {
		Log.minor('loading notestyle $path');
		
		var styleContent:Null<String> = Paths.text('data/styles/notes/$path.json');
		if (styleContent == null) {
			Log.warning('notestyle $path not found...');
			Log.minor('verify path:');
			Log.minor('- data/styles/notes/$path.json');
			return false;
		}
		
		try {
			var styleInfo:NoteStyleInfo = TJSON.parse(styleContent);
			info = styleInfo;
			data = info.data;
			
			name = info.name ?? 'Unknown';
			author = info.author ?? 'Unknown';
			
			updateInfo();
			_success = true;
			Log.info('notestyle $path loaded successfully!');
			return true;
		} catch (e:haxe.Exception) {
			Log.error('error loading notestyle @ "$path" -> ${e.details()}');
		}
		
		_success = false;
		return false;
	}
	function updateInfo():Void {
		this.colors.resize(0);
		
		for (direction in data.general.directions) {
			// parse colors
			if (direction.defaultColors != null) {
				var colors:Array<FlxColor> = [];
				for (color in direction.defaultColors) {
					colors.push(FlxColor.fromString(color));
				}
				this.colors.push(colors);
			} else {
				this.colors.push(null);
			}
		}
		this.modColors[NORMAL] = generateModColors(colors, NORMAL);
		this.modColors[LOWCONTRAST] = generateModColors(colors, LOWCONTRAST);
		this.modColors[HIGHCONTRAST] = generateModColors(colors, HIGHCONTRAST);
	}
	
	static function generateModColors(colors:Array<Array<FlxColor>>, mod:NoteStyleColorMod):Array<Array<FlxColor>> {
		var newColors:Array<Array<FlxColor>> = [];
		for (colorSet in colors) {
			newColors.push(switch (mod) {
				case NORMAL:
					colorSet.copy();
				case LOWCONTRAST:
					var grayRim:FlxColor = colorSet[1];
					grayRim.saturation *= .5;
					[Receptor.makeGrayColor(colorSet[0]), grayRim, 0xff201e31];
				case HIGHCONTRAST:
					var highRim:FlxColor = colorSet[1];
					highRim.saturation *= 1.5;
					highRim.brightness *= 1.5;
					var highColors:Array<FlxColor> = NoteSplash.makeSplashColors(colorSet[0]);
					[highColors[0], highRim, highColors[1]];
			});
		}
		
		return newColors;
	}
	
	public function getAssetAnimation(asset:NoteStyleAssetData, find:String):NoteStyleAnimData {
		if (asset == null) return null;
		
		return asset.animations.find((anim:NoteStyleAnimData) -> anim.name == find);
	}
	public function getDirection(dir:Int):NoteStyleDirData {
		var dirs:Array<NoteStyleDirData> = data.general.directions;
		return dirs[FlxMath.wrap(dir, 0, dirs.length - 1)];
	}
	
	public static function getDirectionName(style:NoteStyleAsset, dir:Int):String {
		var style:NoteStyle = fetch(style);
		
		return style?.getDirection(dir).name ?? defaultDirection;
	}
	public static function getDirectionSing(style:NoteStyleAsset, dir:Int):String {
		var style:NoteStyle = fetch(style);
		
		var dir:NoteStyleDirData = style?.getDirection(dir);
		var anim:Null<String> = dir?.sing;
		if (anim == null)
			anim = 'sing${dir?.name?.toUpperCase() ?? defaultDirection.toUpperCase()}';
		return anim;
	}
	public static function getDirectionColors(style:NoteStyleAsset, dir:Int):Array<FlxColor> {
		var style:NoteStyle = fetch(style);
		if (style == null || style.colors.length == 0) return defaultColors;
		
		return style.colors[FlxMath.wrap(dir, 0, style.colors.length - 1)] ?? defaultColors;
	}
	public static function getDirectionColorMod(style:NoteStyleAsset, dir:Int, mod:NoteStyleColorMod = NORMAL):Array<FlxColor> {
		var style:NoteStyle = fetch(style);
		if (style == null || style.colors.length == 0) return defaultColors;
		
		var colorMod:Array<Array<FlxColor>> = style.modColors[mod];
		
		if (colorMod == null) return defaultColors;
		return colorMod[FlxMath.wrap(dir, 0, colorMod.length - 1)];
	}
	
	public function toString():String {
		return 'NoteStyle($name by $author)';
	}
}

class NoteStyleUtil {
	public static function getDirectionName(style:NoteStyle, dir:Int):String { return NoteStyle.getDirectionName(style, dir); }
	public static function getDirectionSing(style:NoteStyle, dir:Int):String { return NoteStyle.getDirectionSing(style, dir); }
	public static function getDirectionColors(style:NoteStyle, dir:Int):Array<FlxColor> { return NoteStyle.getDirectionColors(style, dir); }
	public static function getDirectionColorMod(style:NoteStyle, dir:Int, mod:NoteStyleColorMod = NORMAL):Array<FlxColor> { return NoteStyle.getDirectionColorMod(style, dir, mod); }
	
	public static function loadNoteStyleAnimations(sprite:FunkinSprite, asset:NoteStyleAssetData, direction:String = 'down'):Void {
		if (asset == null) return;
		
		sprite.resetData();
		sprite.loadAtlas(asset.assetPath);
		sprite.animation?.destroyAnimations();
		sprite.smooth = asset.antialiasing ?? true;
		
		if (sprite.frames == null) return;
		for (data in asset.animations) {
			var animName:String = direction;
			if (data.suffix != null) animName += ' ${data.suffix}';
			if (data.prefix != null) animName = '${data.prefix} $animName';
			
			if (sprite.hasAnimationPrefix(animName)) {
				sprite.addAnimation(data.name, animName, data.frameRate, data.looped, data.frameIndices, data.assetPath);
				sprite.preloadAnimAsset(data.name);
			} else {
				animName = data.prefix;
				if (data.suffix != null) animName += ' ${data.suffix}';
				
				sprite.addAnimation(data.name, animName, data.frameRate, data.looped, data.frameIndices, data.assetPath);
				sprite.preloadAnimAsset(data.name);
			}
			
			if (data.offsets != null && sprite.animationExists(data.name)) {
				sprite.setAnimationOffset(data.name, data.offsets[0], data.offsets[1]);
			} else {
				sprite.setAnimationOffset(data.name);
			}
		}
	}
}

typedef NoteStyleInfo = {
	var name:String;
	var ?author:String;
	var ?version:String;
	var data:NoteStyleData;
}

typedef NoteStyleData = {
	var general:NoteStyleGeneral;
	var notes:NoteStyleAssetData;
	var holds:NoteStyleAssetData;
	var receptors:NoteStyleAssetData;
	var ?noteCovers:NoteStyleAssetData;
	var ?noteSplashes:NoteStyleAssetData;
}

typedef NoteStyleGeneral = {
	var ?disableRGB:Bool;
	var ?laneSpacing:Float;
	var directions:Array<NoteStyleDirData>;
}

typedef NoteStyleDirData = {
	var name:String;
	var ?sing:String;
	var ?colorSave:String;
	var ?keybindSave:String;
	var ?defaultColors:Array<String>;
}

typedef NoteStyleAssetData = {
	var assetPath:String;
	var animations:Array<NoteStyleAnimData>;
	var ?antialiasing:Bool;
	var ?variants:Int; // notesplash only (for now)
	var ?scale:Float;
	var ?alpha:Float;
}

typedef NoteStyleAnimData = {
	var name:String;
	var ?prefix:String;
	var ?suffix:String;
	var ?disableRGB:Bool;
	var ?colorMod:NoteStyleColorMod;
	var ?frameRateRange:Array<Int>;
	var ?frameIndices:Array<Int>;
	var ?offsets:Array<Float>;
	var ?assetPath:String;
	var ?frameRate:Int;
	var ?looped:Bool;
}

enum abstract NoteStyleColorMod(String) to String {
	var NORMAL = 'normal';
	var LOWCONTRAST = 'lowContrast';
	var HIGHCONTRAST = 'highContrast';
}