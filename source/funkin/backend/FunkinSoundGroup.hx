package funkin.backend;

import flixel.util.FlxSignal.FlxTypedSignal;

class FunkinSoundGroup extends flixel.group.FlxGroup.FlxTypedGroup<FunkinSound> {
	public var time(get, set):Float;
	public var muted(get, set):Bool;
	public var pitch(get, set):Float;
	public var volume(get, set):Float;
	public var playing(get, never):Bool;
	public var soundLength(get, never):Float;
	public var syncBase(get, default):FunkinSound;
	public var onSoundFinished:FlxTypedSignal<FunkinSound -> Void> = new FlxTypedSignal();
	
	public override function add(sound:FunkinSound):FunkinSound {
		var snd:FunkinSound = super.add(sound);
		if (snd != null) {
			snd.time = time;
			snd.pitch = pitch;
			snd.volume = volume;
			snd.onComplete = () -> { onSoundFinished.dispatch(snd); }
		}
		return sound;
	}
	
	public function getDisparity(?time:Float):Float {
		var error:Float = 0;
		time ??= syncBase?.time;
		forEachAlive((snd:FunkinSound) -> {
			if (!snd.playing) return;
			
			if (time == null) {
				time = snd.time;
			} else {
				var diff:Float = snd.time - time;
				if (Math.abs(diff) > Math.abs(error))
					error = diff;
			}
		});
		return error;
	}
	public function syncToBase():FunkinSoundGroup {
		var base:FunkinSound = syncBase;
		if (base == null) return this;
		
		forEachAlive((snd:FunkinSound) -> {
			if (snd != base && base.time <= snd.length)
				snd.time = base.time;
		});
		return this;
	}
	
	public function play(forceRestart:Bool = false, startTime:Float = 0, ?endTime:Float):FunkinSoundGroup {
		forEachAlive((snd:FunkinSound) -> {
			if (startTime <= snd.length)
				snd.play(forceRestart, startTime, endTime);
		});
		return this;
	}
	public function pause():FunkinSoundGroup {
		forEachAlive((snd:FunkinSound) -> snd.pause());
		return this;
	}
	public function resume():FunkinSoundGroup {
		forEachAlive((snd:FunkinSound) -> snd.resume());
		return this;
	}
	public function stop():FunkinSoundGroup {
		forEachAlive((snd:FunkinSound) -> snd.stop());
		return this;
	}
	public function fadeIn(duration:Float, from:Float = 0, to:Float = 1, ?onComplete:FlxTween -> Void):FunkinSoundGroup {
		forEachAlive((snd:FunkinSound) -> snd.fadeIn(duration, from, to, onComplete));
		return this;
	}
	public function fadeOut(duration:Float, to:Float = 0, ?onComplete:FlxTween -> Void):FunkinSoundGroup {
		forEachAlive((snd:FunkinSound) -> snd.fadeOut(duration, to, onComplete));
		return this;
	}
	
	function get_syncBase() {
		return syncBase ?? getFirstAlive();
	}
	function get_time():Float {
		return syncBase?.time ?? 0;
	}
	function get_muted():Bool {
		return syncBase?.muted ?? false;
	}
	function get_pitch():Float {
		return syncBase?.pitch ?? 0;
	}
	function get_volume():Float {
		return syncBase?.volume ?? 1;
	}
	function get_playing():Bool {
		return syncBase?.playing ?? false;
	}
	function get_soundLength():Float {
		var maxLength:Float = 0;
		forEachAlive((snd:FunkinSound) -> maxLength = Math.max(maxLength, snd.length));
		return maxLength;
	}
	
	function set_time(time:Float):Float {
		forEachAlive((snd:FunkinSound) -> snd.time = time);
		return time;
	}
	function set_muted(isIt:Bool):Bool {
		forEachAlive((snd:FunkinSound) -> snd.muted = isIt);
		return isIt;
	}
	function set_pitch(pitch:Float):Float {
		forEachAlive((snd:FunkinSound) -> snd.pitch = pitch);
		return pitch;
	}
	function set_volume(volume:Float):Float {
		forEachAlive((snd:FunkinSound) -> snd.volume = volume);
		return volume;
	}
}