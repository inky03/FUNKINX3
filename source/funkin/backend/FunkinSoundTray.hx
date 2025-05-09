package funkin.backend;

#if (flixel >= "6.1.0") import flixel.system.FlxAssets; #end
import openfl.display.BitmapData;
import openfl.display.Bitmap;
import openfl.Lib;

// Hello funkin crew
class FunkinSoundTray extends flixel.system.ui.FlxSoundTray {
	public var bg:Bitmap;
	public var bgBar:Bitmap;
	
	var max:Bool;
	var lerpYPos:Float = 0;
	var alphaTarget:Float = 0;
	
	public var scale(default, set):Float;
	public var barsY(default, set):Float;
	
	public function new() {
		super();
		removeChildren();
		
		bg = new Bitmap();
		bgBar = new Bitmap();
		bg.smoothing = bgBar.smoothing = true;
		addChild(bg);
		addChild(bgBar);
		
		_bg = bg;
		_bars.resize(0);
		for (i in 0...10) {
			var bar:Bitmap = new Bitmap();
			bar.smoothing = true;
			addChild(bar);
			_bars.push(bar);
		}
		
		scale = .6;
		barsY = 18;
		
		reloadSoundtrayGraphics();
		y = -height;
		
		volumeUpSound = 'soundtray/volUP';
		volumeDownSound = 'soundtray/volDOWN';
		volumeMaxSound = 'soundtray/volMAX';
		
		max = (Math.round(FlxG.sound.volume * 10) == 10);
	}

	public function reloadSoundtrayGraphics() {
		bg.bitmapData = Paths.bmd('soundtray/volumebox');
		bgBar.bitmapData = Paths.bmd('soundtray/bars_bg');
		
		for (i => bar in _bars) {
			bar.bitmapData = Paths.bmd('soundtray/bars_${i + 1}');
			bar.x = (bg.width - bar.width) * .5;
		}
		bgBar.x = (bg.width - bgBar.width) * .5;
		
		screenCenter();
	}
	
	public function set_scale(newScale:Float) {
		_defaultScale = newScale;
		screenCenter();
		return newScale;
	}
	public function set_barsY(newY:Float) {
		for (bar in _bars)
			bar.y = newY;
		bgBar.y = newY;
		return newY;
	}

	override public function update(ms:Float):Void {
		final s:Float = ms * .001;
		y = Util.smoothLerp(y, lerpYPos, s * 6);
		alpha = Util.smoothLerp(alpha, alphaTarget, s * 10);

		var shouldHide:Bool = (FlxG.sound.muted == false && FlxG.sound.volume > 0);

		if (_timer > 0) {
			if (shouldHide) _timer -= s;
			alphaTarget = 1;
		}
		else if (y >= -height) {
			lerpYPos = -height - 10;
			alphaTarget = 0;
		}

		if (y <= -height) {
			visible = false;
			active = false;

			#if FLX_SAVE
			if (FlxG.save.isBound) {
				FlxG.save.data.volume = FlxG.sound.volume;
				FlxG.save.data.mute = FlxG.sound.muted;
				FlxG.save.flush();
			}
			#end
		}
	}
	
	#if (flixel >= "6.1.0")
	public var volumeMaxSound:FlxSoundAsset;
	
	override public function showAnim(volume:Float, ?sound:FlxSoundAsset, duration:Float = 1, label:String = 'VOLUME'):Void {
		if (sound != null) {
			if (sound is String) {
				FlxG.sound.play(Paths.sound(sound));
			} else {
				FlxG.sound.play(sound);
			}
		}
		
		var nVolume:Int = Math.round(volume * 10);
		
		_timer = duration;
		lerpYPos = 10;
		visible = true;
		active = true;
		
		for (i => bar in _bars)
			bar.visible = (i + 1 == nVolume);
		
		max = (nVolume >= 10);
	}
	
	override function showIncrement():Void {
		final volume = FlxG.sound.muted ? 0 : FlxG.sound.volume;
		showAnim(volume, silent ? null : (max ? volumeMaxSound : volumeUpSound));
	}
	
	override function showDecrement():Void {
		final volume = FlxG.sound.muted ? 0 : FlxG.sound.volume;
		showAnim(volume, silent ? null : volumeDownSound);
	}
	
	override function updateSize():Void {} // just useless here
	#else
	public var volumeMaxSound:String;
	
	override public function show(up:Bool = false):Void {
		_timer = 1;
		lerpYPos = 10;
		visible = true;
		active = true;
		var baseVolume:Int = Math.round(FlxG.sound.volume * 10);
		var globalVolume:Int = baseVolume;
		
		if (FlxG.sound.muted || FlxG.sound.volume == 0)
			globalVolume = 0;
		
		if (!silent) {
			var sound:String = up ? volumeUpSound : volumeDownSound;
			if (max && up)
				sound = volumeMaxSound;

			if (sound != null) FlxG.sound.play(Paths.sound(sound));
		}
		
		for (i => bar in _bars)
			bar.visible = (i + 1 == globalVolume);
		max = (baseVolume == 10);
	}
	#end
}