package funkin.backend;

import openfl.Assets;
import flxanimate.zip.Zip;
import flxanimate.animate.*;
import flxanimate.data.AnimationData;
import flxanimate.data.SpriteMapData;
import flxanimate.frames.FlxAnimateFrames;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.frames.FlxFramesCollection;

import StringTools;

class FunkinAnimate extends FlxAnimate { // this is kind of useless, but pop off
	public function new(x:Float = 0, y:Float = 0, ?path:String, ?settings:flxanimate.Settings) {
		super(x, y, path, settings);
	}

	public static function softTextureAtlas(path):FlxAnimateFrames {
		var frames:FlxAnimateFrames = new FlxAnimateFrames();

		var texts:Array<String> = [];
		if (FileSystem.exists('$path/spritemap.json')) {
			texts.push('$path/spritemap.json');
		} else {
			var i:Int = 1;
			while (true) {
				if (FileSystem.exists('$path/spritemap$i.json'))
					texts.push('$path/spritemap$i.json');
				else
					break;
				i ++;
			}
		}

		for (path in texts) {
			var spritemapFrames = softSpriteMap(path);

			if (spritemapFrames != null)
				frames.addAtlas(spritemapFrames);
		}

		if (frames.frames.length == 0) {
			FlxG.log.error("the Frames parsing couldn't parse any of the frames, it's completely empty! \n Maybe you misspelled the Path?");
			return null;
		}

		return frames;
	}
	static function softSpriteMap(dir:String):FlxAtlasFrames {
		var json:AnimateAtlas = null;
		var textContent:String = File.getContent(dir);
		json = haxe.Json.parse(textContent.split(String.fromCharCode(0xfeff)).join(''));
		
		if (json == null)
			return null;
		
		var graphic:FlxGraphic = Paths.image(haxe.io.Path.addTrailingSlash(haxe.io.Path.directory(dir)) + json.meta.image);
		var frames = new FlxAtlasFrames(graphic);
		for (sprite in json.ATLAS.SPRITES) {
			var limb = sprite.SPRITE;
			var rect = FlxRect.get(limb.x, limb.y, limb.w, limb.h);
			if (limb.rotated)
				rect.setSize(rect.height, rect.width);

			FlxAnimateFrames.sliceFrame(limb.name, limb.rotated, rect, frames);
		}
		
		return frames;
	}
	public override function loadAtlas(path:String) {
		if (!FileSystem.exists('$path/Animation.json') && haxe.io.Path.extension(path) != 'zip') {
			FlxG.log.error('Animation file not found in specified path: "$path", have you written the correct path?');
			return;
		}
		loadSeparateAtlasExt(path, atlasSetting(path), softTextureAtlas(path));
	}
	override function atlasSetting(path:String) {
		var jsontxt:String = null;
		if (haxe.io.Path.extension(path) == "zip") {
			var thing = Zip.readZip(Assets.getBytes(path));
			for (list in Zip.unzip(thing)) {
				if (list.fileName.indexOf("Animation.json") != -1) {
					jsontxt = list.data.toString();
					thing.remove(list);
					continue;
				}
			}
			@:privateAccess
			FlxAnimateFrames.zip = thing;
		} else {
			jsontxt = Paths.cachedDynamic('$path:animateF', () -> Paths.text('$path/Animation.json'));
		}

		return jsontxt;
	}
	public function loadSeparateAtlasExt(key:String, ?animation:String, ?frames:FlxFramesCollection) {
		if (frames != null)
			this.frames = frames;
		if (animation != null) {
			var json:AnimAtlas = Paths.cachedDynamic('$key:animateC', () -> TJSON.parse(animation));
			if (json == null) { Log.warning('FunkinAnimate: something went awry'); }
			anim._loadAtlas(json);
		}
		if (anim != null)
			origin = anim.curInstance.symbol.transformationPoint;
	}

	public static function cacheAnimate(path:String, ?library:String) {
		try {
			var temp:FunkinAnimate = new FunkinAnimate();
			temp.loadAnimate(path, library);
			temp.destroy();
		} catch (e:haxe.Exception) {}
	}
	public function loadAnimate(path:String, ?library:String) {
		var atlasPath:String = 'images/$path';
		if (Paths.exists(atlasPath, library)) {
			loadAtlas(Paths.getPath(atlasPath, library));
		} else {
			Log.warning('animate atlas path not found... (verify: $atlasPath)');
		}
		return this;
	}

	public override function destroy() {
		try {
			super.destroy();
		} catch (e:Dynamic) {
			anim.symbolDictionary = null;
			anim.stageInstance?.destroy();
			anim.curInstance?.destroy();
			anim.metadata?.destroy();
		}
	}
}