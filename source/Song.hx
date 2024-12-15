package;

import Note;
import Conductor.Metronome;
import Conductor.TempoChange;
import Conductor.TimeSignature;

import haxe.Exception;
import moonchart.formats.StepMania;
import moonchart.formats.BasicFormat;
import moonchart.formats.fnf.FNFVSlice;
import moonchart.formats.StepManiaShark;
import moonchart.formats.fnf.FNFCodename;
import moonchart.parsers.StepManiaParser;

using StringTools;

/*
important note (moonchart):
stepsPerBeat is INCORRECT its wrong its wrong ITS WRONG WRONG WRONWRG WRONG !!!!!!!! FUCK!!!!!!!!!!!!
denominator indicates the value of a note: x/4 means every beat has the time of a quarter note, x/8 an eighth note, and so on
steps are not a thing in music theory in the definition friday night funkin' / fl studio uses.
*/

/*
LOADING A SONG:
for legacy / psych engine format ... Song.loadLegacySong('songName', 'difficulty')
for modern (fnf 0.3.0+) format ... Song.loadModernSong('songName', 'difficulty', ?'suffix')
for simfile (stepmania) ... Song.loadStepMania('songName', 'difficulty')
*/

class Song {
	public var path:String = '';
	public var name:String = 'Unnamed';
	public var artist:String = 'Unknown';
	public var difficulty:String = '';
	public var format:SongFormat = UNKNOWN;

	public var chart:Any; //BasicFormat?
	public var json:Dynamic;
	
	public var keyCount:Int = 4;
	public var scrollSpeed:Float = 1;
	public var initialBpm:Float = 100;
	public var notes:Array<SongNote> = [];
	public var events:Array<SongEvent> = [];
	public var tempoChanges:Array<TempoChange> = [new TempoChange(-4, 100, new TimeSignature())];

	public var instLoaded:Bool;
	public var inst:FlxSound;
	public var songLength:Float = 0;
	public var audioSuffix:String = '';

	public var player1:String = 'bf';
	public var player2:String = 'dad';
	public var player3:String = 'gf';
	public var stage:String;
	
	public function new(path:String, keyCount:Int = 4) {
		this.path = path;
		this.keyCount = keyCount;
		
		instLoaded = false;
		inst = new FlxSound();
		FlxG.sound.list.add(inst);
	}
	
	public static function loadSong(path:String, ?difficulty:String, ?suffix:String, format:SongFormat = AUTO) {
		return switch (format) {
			case AUTO:
				loadAutoDetect(path, difficulty, suffix);
			case LEGACY:
				loadLegacySong(path, difficulty, suffix);
			case MODERN:
				loadModernSong(path, difficulty, suffix);
			case STEPMANIA:
				loadStepMania(path, difficulty, suffix);
			case CNE:
				loadCNESong(path, difficulty, suffix);
			default:
				Log.warning('unknown song format (attempted to load "$path")');
				new Song(path, 4);
		}
	}
	public static function chartExists(path:String, ?difficulty:String, ?suffix:String, format:SongFormat = AUTO) {
		var foundFormat:SongFormat = findSongFormat(path, difficulty, suffix);
		if (format == AUTO) {
			return foundFormat != SongFormat.UNKNOWN;
		} else {
			return foundFormat == format;
		}
	}

	function loadGeneric(format:Dynamic, difficulty:String, ?playerNoteFilter:BasicNote -> Bool) {
		this.difficulty = difficulty;
		this.chart = format;

		var meta:BasicMetaData = format.getChartMeta();
		for (diff => speed in meta.scrollSpeeds) {
			if (difficulty.toLowerCase() == diff.toLowerCase()) {
				this.scrollSpeed = speed;
				break;
			}
		}
		this.artist = meta.extraData['SONG_ARTIST'] ?? '';
		this.name = meta.title;

		var bpmChanges:Array<BasicBPMChange> = meta.bpmChanges;
		var tempMetronome:Metronome = new Metronome();
		this.tempoChanges = [];
		this.initialBpm = bpmChanges[0].bpm;
		tempMetronome.tempoChanges = this.tempoChanges;
		for (i => change in bpmChanges) {
			var beat:Float = 0;
			var timeSig:Null<TimeSignature> = null;

			if (this.tempoChanges.length > 0)
				beat = tempMetronome.convertMeasure(change.time, MS, BEAT);
			if (change.beatsPerMeasure > 0 && change.stepsPerBeat > 0)
				timeSig = new TimeSignature(Std.int(change.beatsPerMeasure), Std.int(change.stepsPerBeat));
			else if (i == 0) // apply default time signature to first bpm change hehe
				timeSig = new TimeSignature();

			this.tempoChanges.push(new TempoChange(beat, change.bpm, timeSig));
		}

		var events:Array<BasicEvent> = format.getEvents();
		for (event in events) {
			var newParams:Map<String, Dynamic> = [];
			if (Reflect.isObject(event.data)) {
				for (param in Reflect.fields(event.data))
					newParams[param] = Reflect.field(event.data, param);
			} else
				newParams['value'] = event.data;
			this.events.push({name: event.name, msTime: event.time, params: newParams});
		}

		var tempMetronome:Metronome = new Metronome();
		tempMetronome.tempoChanges = this.tempoChanges;
		var notes:Array<BasicNote> = format.getNotes(difficulty);
		for (note in notes) {
			var isPlayer:Bool;
			if (playerNoteFilter != null) {
				isPlayer = playerNoteFilter(note);
			} else {
				isPlayer = note.lane >= 4;
			}
			tempMetronome.setMS(note.time + 1);
			var stepCrochet:Float = tempMetronome.getCrochet(tempMetronome.bpm, tempMetronome.timeSignature.denominator) * .25;
			this.notes.push({player: isPlayer, msTime: note.time, laneIndex: Std.int(note.lane % 4), msLength: note.length - stepCrochet, kind: note.type});
		}
		
		this.sort();
		this.findSongLength();
		return this;
	}
	public function findSongLength() {
		if (instLoaded) {
			this.songLength = inst.length;
		} else {
			var lastNote:SongNote = notes[notes.length - 1];
			this.songLength = (lastNote == null ? 0 : lastNote.msTime + lastNote.msLength) + 500;
		}
		return this.songLength;
	}
	
	// TODO: these could just not be static
	// suffix is for playable characters
	static function loadLegacySong(path:String, difficulty:String = 'normal', suffix:String = '', keyCount:Int = 4) { // move to moonchart format???
		difficulty = difficulty.toLowerCase();
		Log.minor('loading legacy FNF song "$path" with difficulty "$difficulty"${suffix == '' ? '' : ' ($suffix)'}');
		
		var song = new Song(path, keyCount);
		song.json = Song.loadLegacyJson(path, difficulty);
		song.difficulty = difficulty;
		
		if (song.json == null) return song;
		var fromSong:Bool = (!Std.isOfType(song.json.song, String));
		if (fromSong) song.json = song.json.song; // probably move song.json to song.chart?
		
		var time = Sys.time();
		try {
			var eventsPath:String = 'data/songs/$path/events.json';
			var eventContent:Null<String> = Paths.text(eventsPath);
			if (eventContent != null) {
				Log.minor('loading events from "$eventsPath"');
				var eventJson:Dynamic = TJSON.parse(eventContent);
				if (eventJson.song != null && !Std.isOfType(eventJson.song, String)) eventJson = eventJson.song;
				if (song.json.events == null) song.json.events = [];
				var eventBlobs:Array<Array<Dynamic>> = eventJson.events;
				var songEventBlobs:Array<Array<Dynamic>> = song.json.events;
				for (eventBlob in eventBlobs) songEventBlobs.push(eventBlob);
			}
			
			var songSpeed:Float;
			var speed:Dynamic = song.json.speed;
			if (Reflect.hasField(speed, difficulty)) { // fuck ass modern/legacy hybrid format...
				songSpeed = Util.parseFloat(Reflect.field(speed, difficulty), 1);
			} else {
				songSpeed = Util.parseFloat(speed, 1);
			}
			song.name = song.json.song;
			song.initialBpm = song.json.bpm;
			song.tempoChanges = [new TempoChange(-4, song.initialBpm, new TimeSignature())];
			song.scrollSpeed = songSpeed;
			
			var ms:Float = 0;
			var beat:Float = 0;
			var sectionNumerator:Float = 0;
			var osectionNumerator:Float = 0;
			
			var bpm:Float = song.initialBpm;
			var crochet:Float = 60000 / song.initialBpm;
			var stepCrochet:Float = crochet * .25;
			var focus:Int = -1;
			
			var sections:Array<LegacySongSection>;
			var jsonNotes:Dynamic = song.json.notes;
			if (Reflect.hasField(jsonNotes, difficulty)) {
				sections = Reflect.field(jsonNotes, difficulty);
			} else {
				sections = song.json.notes;
			}
			if (song.json.events != null) {
				var eventBlobs:Array<Array<Dynamic>> = song.json.events;
				for (eventBlob in eventBlobs) {
					var eventTime:Float = eventBlob[0];
					var events:Array<Array<String>> = eventBlob[1];
					for (event in events) {
						var songEvent:SongEvent = {name: event[0], msTime: eventTime, params: ['value1' => event[1], 'value2' => event[2]]};
						song.events.push(songEvent);
					}
				}
			}
			var tempMetronome:Metronome = new Metronome();
			tempMetronome.tempoChanges = song.tempoChanges;
			for (section in sections) {
				var sectionFocus:Int = (section.gfSection ? 2 : (section.mustHitSection ? 0 : 1));
				if (focus != sectionFocus) {
					focus = sectionFocus;
					song.events.push({name: 'FocusCamera', msTime: ms, params: ['char' => focus]});
				}
				
				var sectionDenominator:Int = 4;
				var sectionNumerator:Null<Float> = section.sectionBeats;
				if (sectionNumerator == null) sectionNumerator = section.lengthInSteps * .25;
				if (sectionNumerator == null) sectionNumerator = 4;
				while (sectionNumerator % 1 > 0 && sectionDenominator < 32) {
					sectionNumerator *= 2;
					sectionDenominator *= 2;
				}
				var changeSign:Bool = (sectionNumerator != osectionNumerator);
				if (section.changeBPM || changeSign) {
					osectionNumerator = sectionNumerator;
					if (section.changeBPM) bpm = section.bpm;
					crochet = 60000 / bpm / sectionDenominator * 4;
					stepCrochet = crochet * .25;
					
					song.tempoChanges.push(new TempoChange(beat, section.changeBPM ? section.bpm : null, changeSign ? new TimeSignature(Std.int(sectionNumerator), sectionDenominator) : null));
				}
				beat += sectionNumerator;
				ms += sectionNumerator * crochet;
				
				for (dataNote in section.sectionNotes) {
					var noteTime:Float = dataNote[0];
					var noteData:Int = Std.int(dataNote[1]);
					if (noteData < 0) { // old psych event
						song.events.push({name: dataNote[2], msTime: noteTime, params: ['value1' => dataNote[3], 'value2' => dataNote[4]]});
						continue;
					}

					var noteLength:Float = dataNote[2];
					var noteKind:Dynamic = dataNote[3];
					if (!Std.isOfType(noteKind, String)) noteKind = '';
					var playerNote:Bool;
					if (fromSong) {
						playerNote = ((noteData < keyCount) == section.mustHitSection);
					} else { // assume psych 1.0
						playerNote = (noteData < keyCount);
					}
					
					song.notes.push({player: playerNote, msTime: noteTime, laneIndex: noteData % keyCount, msLength: noteLength, kind: noteKind});
				}
			}
			song.sort();
			song.findSongLength();

			song.player1 = song.json.player1;
			song.player2 = song.json.player2;
			song.player3 = song.json.player3 ?? song.json.gfVersion ?? 'gf';
			song.stage = song.json.stage;
			song.format = LEGACY;

			Log.info('chart loaded successfully! (${Math.round((Sys.time() - time) * 1000) / 1000}s)');
		} catch(e:Exception) {
			Log.error('chart error... -> <<< ${e.details()} >>>');
		}
		
		song.audioSuffix = suffix;
		return song;
	}
	static function loadStepMania(path:String, difficulty:String = 'Beginner', suffix:String = '') {
		difficulty = difficulty.toLowerCase();
		Log.minor('loading StepMania simfile "$path" with difficulty "$difficulty"${suffix == '' ? '' : ' ($suffix)'}');

		var songPath:String = 'data/songs/$path/$path';
		var sscPath:String = '${Util.pathSuffix(songPath, suffix)}.ssc';
		var smPath:String = '$songPath.sm';
		var useShark:Bool = Paths.exists(sscPath);
		var song:Song = new Song(path, 4); // todo: sm multikey (implement multikey in the first place)

		if (!Paths.exists(smPath) && !useShark) {
			Log.warning('sm or ssc file not found... (chart not generated)');
			Log.minor('verify path:');
			Log.minor('- chart: $smPath OR $sscPath');
			return song;
		}

		var time = Sys.time();
		var shark:StepManiaShark;
		@:privateAccess try {
			if (useShark) { // goofy but who cares (hint: also me)
				var sscContent:String = Paths.text(sscPath);
				shark = new StepManiaShark().fromStepManiaShark(sscContent);
			} else {
				var smContent:String = Paths.text(smPath);
				var sm:StepMania = new StepMania().fromStepMania(smContent);
				shark = new StepManiaShark().fromFormat(sm);
			}
			var notes:Array<BasicNote> = shark.getNotes(difficulty);
			var dance:StepManiaDance = shark.resolveDance(notes);
			song.loadGeneric(shark, difficulty, (note:BasicNote) -> (dance == SINGLE ? note.lane < 4 : note.lane >= 4));
			song.format = (useShark ? SHARK : STEPMANIA);

			Log.info('chart loaded successfully! (${Math.round((Sys.time() - time) * 1000) / 1000}s)');
		} catch (e:Exception) {
			Log.error('chart error... -> <<< ${e.details()} >>>');
		}
		
		song.audioSuffix = suffix;
		return song;
	}
	static function loadModernSong(path:String, difficulty:String = 'normal', suffix:String = '') {
		difficulty = difficulty.toLowerCase();
		Log.minor('loading modern FNF song "$path" with difficulty "$difficulty"${suffix == '' ? '' : ' ($suffix)'}');

		var songPath:String = 'data/songs/$path/$path';
		var chartPath:String = '${Util.pathSuffix('$songPath-chart', suffix)}.json';
		var metaPath:String = '${Util.pathSuffix('$songPath-metadata', suffix)}.json';
		var song:Song = new Song(path, 4);

		if (!Paths.exists(chartPath) || !Paths.exists(metaPath)) {
			Log.warning('chart or metadata JSON not found... (chart not generated)');
			Log.minor('verify paths:');
			Log.minor('- chart: $chartPath');
			Log.minor('- metadata: $metaPath');
			return song;
		}

		var time = Sys.time();
		var vslice:FNFVSlice;
		try {
			var chartContent:String = Paths.text(chartPath);
			var metaContent:String = Paths.text(metaPath);
			vslice = new FNFVSlice().fromJson(chartContent, metaContent);
			song.loadGeneric(vslice, difficulty, (note:BasicNote) -> note.lane >= 4);

			var meta:BasicMetaData = vslice.getChartMeta();
			song.player1 = meta.extraData['FNF_P1'] ?? 'bf';
			song.player2 = meta.extraData['FNF_P2'] ?? 'dad';
			song.player3 = meta.extraData['FNF_P3'] ?? 'gf';
			song.stage = meta.extraData['FNF_STAGE'] ?? 'placeholder';
			song.format = MODERN;

			Log.info('chart loaded successfully! (${Math.round((Sys.time() - time) * 1000) / 1000}s)');
		} catch (e:Exception) {
			Log.error('chart error... -> <<< ${e.details()} >>>');
		}

		song.audioSuffix = suffix;
		return song;
	}
	static function loadCNESong(path:String, difficulty:String = 'Normal', suffix:String = '') {
		Log.minor('loading CNE song "$path" with difficulty "$difficulty"${suffix == '' ? '' : ' ($suffix)'}');

		var songPath:String = 'data/songs/$path';
		var chartPath:String = '$songPath/charts/${Util.pathSuffix(difficulty, suffix)}.json';
		var metaPath:String = '$songPath/${Util.pathSuffix('meta', suffix)}.json';
		var chartPathA:String = chartPath;
		var song:Song = new Song(path, 4);

		if (!Paths.exists(chartPath)) chartPath = '$songPath/$difficulty.json';
		if (!Paths.exists(chartPath) || !Paths.exists(metaPath)) {
			Log.warning('chart or metadata JSON not found... (chart not generated)');
			Log.minor('verify paths:');
			Log.minor('- chart: $chartPathA  or  $chartPath');
			Log.minor('- metadata: $metaPath');
			return song;
		}

		var time = Sys.time();
		var cne:FNFCodename;
		try {
			var metaContent:String = Paths.text(metaPath);
			var chartContent:String = Paths.text(chartPath);
			cne = new FNFCodename().fromJson(chartContent, metaContent);
			song.loadGeneric(cne, difficulty, (note:BasicNote) -> note.lane >= 4);

			var meta:BasicMetaData = cne.getChartMeta();
			song.player1 = meta.extraData['FNF_P1'] ?? 'bf';
			song.player2 = meta.extraData['FNF_P2'] ?? 'dad';
			song.player3 = meta.extraData['FNF_P3'] ?? 'gf';
			song.stage = meta.extraData['FNF_STAGE'] ?? 'placeholder';
			song.format = CNE;

			Log.info('chart loaded successfully! (${Math.round((Sys.time() - time) * 1000) / 1000}s)');
		} catch (e:Exception) {
			Log.error('chart error... -> <<< ${e.details()} >>>');
		}

		song.audioSuffix = suffix;
		return song;
	}
	static function findSongFormat(path:String, ?difficulty:String = 'Normal', ?suffix:String):SongFormat {
		var diffLower:String = difficulty.toLowerCase();
		var songPath:String = 'data/songs/$path/$path';

		var modernChartPath:String = Util.pathSuffix('$songPath-chart', suffix) + '.json';
		var modernMetaPath:String = Util.pathSuffix('$songPath-metadata', suffix) + '.json';

		var smChartPath:String = Util.pathSuffix(songPath, suffix) + '.sm';
		var sharkChartPath:String = Util.pathSuffix(songPath, suffix) + '.ssc';

		var legacyChartPath:String = Util.pathSuffix(Util.pathSuffix(songPath, diffLower), suffix) + '.json';
		var legacyNormalChartPath:String = Util.pathSuffix(songPath, suffix) + '.json';

		var cneMetaPath:String = Util.pathSuffix('data/songs/$path/meta', suffix) + '.json';

		if (Paths.exists(modernChartPath) || Paths.exists(modernMetaPath))
			return MODERN;
		else if (Paths.exists(smChartPath))
			return STEPMANIA;
		else if (Paths.exists(sharkChartPath))
			return SHARK;
		else if (Paths.exists(legacyChartPath) || Paths.exists(legacyNormalChartPath))
			return LEGACY;
		else if (Paths.exists(cneMetaPath))
			return CNE;
		else
			return UNKNOWN;
	}
	static function loadAutoDetect(path:String, ?difficulty:String, ?suffix:String) {
		if (difficulty != null) difficulty = difficulty.toLowerCase();
		Log.minor('detecting format from song "$path"');
		
		return switch (findSongFormat(path, difficulty, suffix)) {
			case MODERN:
				loadModernSong(path, difficulty, suffix);
			case STEPMANIA | SHARK:
				loadStepMania(path, difficulty, suffix);
			case LEGACY:
				loadLegacySong(path, difficulty, suffix);
			case CNE:
				loadCNESong(path, difficulty, suffix);
			default:
				var diffLower:String = difficulty.toLowerCase();
				var songPath:String = 'data/songs/$path/$path';
				var modernChartPath:String = Util.pathSuffix('$songPath-chart', suffix) + '.json';
				var modernMetaPath:String = Util.pathSuffix('$songPath-metadata', suffix) + '.json';
				var smChartPath:String = Util.pathSuffix(songPath, suffix) + '.sm';
				var sharkChartPath:String = Util.pathSuffix(songPath, suffix) + '.ssc';
				var legacyChartPath:String = Util.pathSuffix(Util.pathSuffix(songPath, diffLower), suffix) + '.json';
				var legacyNormalChartPath:String = Util.pathSuffix(songPath, suffix) + '.json';
				var cneMetaPath:String = Util.pathSuffix('meta', suffix) + '.json';
				// umm yea bro

				Log.warning('chart files of any type not found... (chart not generated)');
				Log.minor('verify paths:');
				Log.minor('- modern:');
				Log.minor('  - chart: $modernChartPath');
				Log.minor('  - metadata: $modernMetaPath');
				Log.minor('- stepmania sm: $smChartPath');
				Log.minor('- stepmania ssc: $sharkChartPath');
				Log.minor('- legacy: $legacyChartPath');
				Log.minor('- codename engine:');
				Log.minor('  - metadata: $cneMetaPath');
				new Song(path, 4);
		}
	}
	static function loadLegacyJson(path:String, difficulty:String = 'normal') {
		var jsonPathD:String = 'data/songs/$path/$path';
		var diffSuffix:String = '-$difficulty';
		
		var jsonPath:String = '$jsonPathD$diffSuffix.json';
		if (!Paths.exists(jsonPath)) jsonPath = '$jsonPathD.json';
		if (Paths.exists(jsonPath)) {
			var content:String = Paths.text(jsonPath);
			var jsonData:Dynamic = TJSON.parse(content);
			return jsonData;
		} else {
			Log.warning('chart JSON not found... (chart not generated)');
			Log.minor('verify path:');
			Log.minor('- chart: $jsonPath');
			return null;
		}
	}

	public function generateNotes(singleSegmentHolds:Bool = false):Array<Note> {
		var time:Float = Sys.time();
		Log.minor('generating notes from song');
		var notes:Array<Note> = generateNotesFromArray(notes, singleSegmentHolds, this);
		Log.info('generated ${notes.length} notes! (${Math.round((Sys.time() - time) * 1000) / 1000}s)');
		return notes;
	}
	public static function generateNotesFromArray(songNotes:Array<SongNote>, singleSegmentHolds:Bool = false, ?song:Song) {
		var noteArray:Array<Note> = [];
		var tempMetronome:Metronome = null;
		var type:Dynamic = (CharterState.inEditor ? CharterState.CharterNote : Note);
		if (song != null) {
			tempMetronome = new Metronome();
			tempMetronome.tempoChanges = song.tempoChanges;
		}
		
		for (songNote in songNotes) {
			tempMetronome?.setMS(songNote.msTime);
			var hitNote:Note = Type.createInstance(type, [songNote.player, songNote.msTime, songNote.laneIndex, songNote.msLength, songNote.kind]);
			noteArray.push(hitNote);
			
			if (hitNote.msLength > 0) { //hold bits
				var endMs:Float = songNote.msTime + songNote.msLength;
				if (!singleSegmentHolds && tempMetronome != null) {
					var bitTime:Float = songNote.msTime;
					while (bitTime < endMs) {
						tempMetronome.setStep(Std.int(tempMetronome.step + .05) + 1);
						var newTime:Float = tempMetronome.ms;
						if (bitTime < songNote.msTime) {
							Log.warning('??? $bitTime < ${songNote.msTime} (sustain bit off by ${songNote.msTime - bitTime}ms)');
							bitTime = newTime;
							break;
						}
						var bitLength:Float = Math.min(newTime - bitTime, endMs - bitTime);
						var holdBit:Note = Type.createInstance(type, [songNote.player, bitTime, songNote.laneIndex, bitLength, songNote.kind, true]);
						hitNote.children.push(holdBit);
						holdBit.parent = hitNote;
						noteArray.push(holdBit);
						bitTime = newTime;
					}
				} else {
					var holdBit:Note = Type.createInstance(type, [songNote.player, songNote.msTime, songNote.laneIndex, songNote.msLength, songNote.kind, true]);
					hitNote.children.push(holdBit);
					holdBit.parent = hitNote;
					noteArray.push(holdBit);
				}
				var endBit:Note = Type.createInstance(type, [songNote.player, endMs, songNote.laneIndex, 0, songNote.kind, true]);
				hitNote.children.push(endBit);
				noteArray.push(endBit);
				
				endBit.parent = hitNote;
				hitNote.tail = endBit;
			}
		}
		
		return noteArray;
	}
	
	public function loadMusic(path:String, overwrite:Bool = true) { // this could be better
		if (instLoaded && !overwrite) return true;
		var instPath:String = path + Util.pathSuffix('Inst', audioSuffix);
		// Log.minor('attempting to load instrumental from $instPath...');
		try {
			inst.loadEmbedded(Paths.ogg(instPath));
			if (inst.length > 0) {
				songLength = inst.length;
				instLoaded = true;
				inst.play();
				inst.stop();
				Log.info('instrumental loaded!!');
				return true;
			}
		} catch (e:Exception) {
			Log.error('error when loading instrumental -> ${e.message}');
			instLoaded = false;
		}
		return false;
	}
	
	public static function sortByTime(a:TimedEvent, b:TimedEvent) {
		return Std.int(a.msTime - b.msTime);
	}
	public function sort() {
		notes.sort(sortByTime);
		events.sort(sortByTime);
	}
}

enum SongFormat {
	AUTO;
	MODERN;
	LEGACY; // psych / pre0.3
	STEPMANIA;
	SHARK;
	CNE;

	UNKNOWN;
}

interface TimedEvent {
	public var msTime:Float;
}
@:structInit class SongNote implements TimedEvent {
	public var laneIndex:Int;
	public var msTime:Float = 0;
	public var kind:String = '';
	public var msLength:Float = 0;
	public var player:Bool = true;
}
@:structInit class SongEvent implements TimedEvent {
	public var name:String;
	public var msTime:Float;
	public var params:Map<String, Any>;
}

typedef LegacySongSection = {
	var sectionNotes:Array<Array<Any>>;
	var ?sectionBeats:Float;
	var ?lengthInSteps:Float;
	var mustHitSection:Bool;
	var gfSection:Bool;
	var changeBPM:Bool;
	var bpm:Float;
}