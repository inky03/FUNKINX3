package funkin.backend;

import funkin.backend.rhythm.Conductor;
import funkin.backend.rhythm.TempoChange;

class MusicHandler {
	public static var music(get, never):FlxSound;
	public static var musicMeta:Null<MusicMeta>;
	
	static function get_music() return FlxG.sound.music;
	public static function playMusic(mus:String, forced:Bool = false) {
		var folderPath:String = '$mus';
		var musPath:String = mus;
		if (Paths.exists('music/$folderPath'))
			musPath = '$folderPath/$mus';
		@:privateAccess
		if (forced || FlxG.sound.music == null || !FlxG.sound.music.playing || FlxG.sound.music._sound != Paths.music(musPath)) {
			FlxG.sound.playMusic(Paths.music(musPath));
			musicMeta = loadMeta(mus);
		}
	}
	public static function loadMeta(mus:String) {
		var jsonPath:String = 'music/$mus/$mus-metadata.json';
		if (Paths.exists(jsonPath)) {
			try {
				var content:String = Paths.text(jsonPath);
				var meta:MusicMeta = TJSON.parse(content);
				Log.info('loaded music metadata for "$mus"!');
				return meta;
			} catch(e:haxe.Exception) {
				Log.error('failed to get music metadata for "$mus" -> ${e.details()}');
			}
		} else {
			Log.warning('no music metadata found for "$mus"');
		}
		return null;
	}
	public static function getMetronomeFromMeta(?meta:MusicMeta) {
		var metronome:Metronome = new Metronome();
		if (meta == null) return metronome;
		
		metronome.tempoChanges.resize(0);
		for (i => change in meta.timeChanges) {
			var beatTime:Float = (i > 0 ? metronome.convertMeasure(change.t, MS, BEAT) : 0);
			var timeSign:Null<TimeSignature> = null;
			if (change.n != null && change.d != null)
				timeSign = new TimeSignature(change.n, change.d);
			metronome.tempoChanges.push(new TempoChange(beatTime, change.bpm, timeSign));
		}
		return metronome;
	}
	public static function applyMeta(conductor:Conductor, ?meta:MusicMeta) {
		if (meta == null) meta = musicMeta;
		conductor.metronome = getMetronomeFromMeta(meta);
	}
}

typedef MusicMeta = {
	var artist:String;
	var songName:String;
	var timeChanges:Array<MusicTimeChange>;
	var ?looped:Bool;
	var ?version:String;
	var ?timeFormat:String;
	var ?generatedBy:String;
}
typedef MusicTimeChange = {
	var ?n:Int; // numerator
	var ?d:Int; // denominator
	var t:Float; // time
	var ?bpm:Float;
	var ?bt:Array<Int>; // beat tuplets,,??
}