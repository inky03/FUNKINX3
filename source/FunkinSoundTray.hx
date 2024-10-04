package;

import flixel.system.ui.FlxSoundTray;
import flixel.tweens.FlxTween;
import flixel.system.FlxAssets;
import flixel.tweens.FlxEase;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.utils.Assets;

// Hello funkin crew
class FunkinSoundTray extends FlxSoundTray {
	var graphicScale:Float = 0.30;
	var lerpYPos:Float = 0;
	var alphaTarget:Float = 0;

	var volumeMaxSound:String;

	public function new() {
		super();
		removeChildren();
		_bars = [];
		
		var bg:Bitmap = new Bitmap(Paths.bmd('soundtray/volumebox'));
		bg.scaleX = graphicScale;
		bg.scaleY = graphicScale;
		addChild(bg);
		
		for (i in 1 ... 11) {
			var bar:Bitmap = new Bitmap(Paths.bmd('soundtray/bars_$i'));
			bar.scaleX = graphicScale;
			bar.scaleY = graphicScale;
			bar.x = 9;
			bar.y = 5;
			addChild(bar);
			_bars.push(bar);
		}
		
		screenCenter();
		y = -height;

		volumeUpSound = 'soundtray/volUP';
		volumeDownSound = 'soundtray/volDOWN';
		volumeMaxSound = 'soundtray/volMAX';
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

	/**
	 * Makes the little volume tray slide out.
	 *
	 * @param	up Whether the volume is increasing.
	 */
	override public function show(up:Bool = false):Void {
		_timer = 1;
		lerpYPos = 10;
		visible = true;
		active = true;
		var globalVolume:Int = Math.round(FlxG.sound.volume * 10);

		if (FlxG.sound.muted || FlxG.sound.volume == 0) {
			globalVolume = 0;
		}

		if (!silent) {
			var sound:String = up ? volumeUpSound : volumeDownSound;
			if (globalVolume == 10) sound = volumeMaxSound;

			if (sound != null) FlxG.sound.play(Paths.sound(sound));
		}

		for (i in 0 ... _bars.length) {
			var showBar:Bool = (i + 1 == Std.int(globalVolume));
			if (i == _bars.length - 1) {
				_bars[i].alpha = showBar ? 1 : .4;
			} else {
				_bars[i].visible = showBar;
			}
		}
	}
}