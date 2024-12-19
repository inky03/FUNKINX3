package;

import openfl.media.SoundMixer;
import flixel.util.FlxSignal.FlxTypedSignal;
import flixel.system.FlxAssets.FlxSoundAsset;

// move MusicHandler here?
class FunkinSound extends FlxSound { // most code adapted from base game's FunkinSound. TODO: waveform data
	static var MAX_VOLUME:Float = 1;
	
	public var muted(default, set):Bool = false;
	
	public static var onVolumeChanged(get, never):FlxTypedSignal<Float->Void>;
	static var _onVolumeChanged:Null<FlxTypedSignal<Float->Void>> = null;
	static var pool(default, null):FlxTypedGroup<FunkinSound> = new FlxTypedGroup<FunkinSound>();
	
	var _scheduled:Bool = false;
	var _label:String = 'unknown';
	
	public static function load(embeddedSound:FlxSoundAsset, volume:Float = 1, looped:Bool = false, autoDestroy:Bool = false, autoPlay:Bool = false, persist:Bool = false, ?onComplete:Void->Void, ?onLoad:Void->Void):Null<FunkinSound> {
		@:privateAccess
		if (SoundMixer.__soundChannels.length >= SoundMixer.MAX_ACTIVE_CHANNELS) {
			FlxG.log.error('FunkinSound could not play sound, channels exhausted! Found ${SoundMixer.__soundChannels.length} active sound channels.');
			return null;
		}
		
		var sound:FunkinSound = pool.recycle(construct);
		sound.loadEmbedded(embeddedSound, looped, autoDestroy, onComplete);
		if (embeddedSound is String) {
			sound._label = embeddedSound;
		} else {
			sound._label = 'unknown';
		}
		
		#if (flixel >= "5.7.0")
		sound.group?.remove(sound);
		FlxG.sound.defaultSoundGroup.add(sound);
		#else
		sound.group = FlxG.sound.defaultSoundGroup;
		#end
		sound.volume = volume;
		sound.persist = persist;
		if (autoPlay) sound.play();
		FlxG.sound.list.add(sound);
		
		if (onLoad != null && sound._sound != null) onLoad();
		
		return sound;
	}
	public static function playOnce(embeddedSound:FlxSoundAsset, volume:Float = 1, ?onComplete:Void->Void, ?onLoad:Void->Void):Null<FunkinSound> {
		var result:Null<FunkinSound> = FunkinSound.load(embeddedSound, volume, false, true, true, false, onComplete, onLoad);
		return result;
	}
	public static function stopAll(includeMusic:Bool = false, includePersist:Bool = false):Void {
		for (sound in pool) {
			if (sound == null) continue;
			if (!includePersist && sound.persist) continue;
			if (!includeMusic && sound == FlxG.sound.music) continue;
			sound.destroy();
		}
	}
	
	static function construct():FunkinSound {
		var sound:FunkinSound = new FunkinSound();
		
		pool.add(sound);
		FlxG.sound.list.add(sound);
		
		return sound;
	}
	static function get_onVolumeChanged():FlxTypedSignal<Float->Void> {
		if (_onVolumeChanged == null) {
			_onVolumeChanged = new FlxTypedSignal<Float->Void>();
			#if (flixel >= "5.9.0")
			FlxG.sound.onVolumeChange.add((vol:Float) -> _onVolumeChanged.dispatch(vol));
			#else
			FlxG.sound.volumeHandler = (vol:Float) -> _onVolumeChanged.dispatch(vol);
			#end
		}
		return _onVolumeChanged;
	}
	
	public function new() {
		super();
	}
	public override function update(elapsed:Float) {
		if (!playing && !_scheduled) return;
		
		if (_time < 0) {
			_time += elapsed * 1000;
			if (_time >= 0)
				super.play();
		} else {
			super.update(elapsed);
		}
	}
	public override function play(forceRestart:Bool = false, startTime:Float = 0, ?endTime:Float) {
		if (!exists) return this;
		
		if (forceRestart) {
			cleanup(false, true);
		} else if (playing) {
			return this;
		}
		
		this.endTime = endTime;
		if (startTime < 0) {
			active = true;
			_scheduled = true;
			_time = startTime;
			return this;
		} else {
			_scheduled = false;
			if (_paused) {
				resume();
			} else {
				startSound(startTime);
			}
			return this;
		}
	}
	public function togglePlayback():FunkinSound {
		if (playing) {
			pause();
		} else {
			resume();
		}
		return this;
	}
	public override function pause():FunkinSound {
		if (_scheduled) {
			_scheduled = false;
			_paused = true;
			active = false;
		} else {
			super.pause();
		}
		return this;
	}
	public override function resume():FunkinSound {
		if (_time < 0) {
			_scheduled = true;
			_paused = false;
			active = true;
		} else {
			super.resume();
		}
		return this;
	}
	public function clone():FunkinSound {
		var sound:FunkinSound = new FunkinSound();
		
		@:privateAccess sound._sound = openfl.media.Sound.fromAudioBuffer(this._sound.__buffer);
		sound.init(this.looped, this.autoDestroy, this.onComplete);

		return sound;
	}
	@:allow(flixel.sound.FlxSoundGroup)
	override function updateTransform():Void {
		if (_transform != null) {
			_transform.volume = #if FLX_SOUND_SYSTEM ((FlxG.sound.muted || this.muted) ? 0 : 1) * FlxG.sound.volume * #end
			(group != null ? group.volume : 1) * _volume * _volumeAdjust;
		}

		if (_channel != null)
		  _channel.soundTransform = _transform;
	}
	public override function toString():String {
		return 'FunkinSound(${this._label})';
	}
	
	override function set_volume(value:Float):Float {
		_volume = FlxMath.bound(value, 0, MAX_VOLUME);
		updateTransform();
		return _volume;
	}
	function set_muted(value:Bool):Bool {
		if (value == muted)
			return value;
		
		muted = value;
		updateTransform();
		return value;
	}
}