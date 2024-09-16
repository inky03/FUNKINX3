package;

import Note;
import Conductor.Metronome;
import Conductor.TempoChange;

import haxe.Exception;
import moonchart.formats.BasicFormat;
import moonchart.formats.fnf.FNFVSlice;

class Song {
	public var path:String;
	
	public var name:String;
	public var json:Dynamic;
	public var chart:Dynamic;
	public var initialBpm:Float = 100;
	public var keyCount:Int = 4;
	public var notes:Array<Note> = [];
	public var events:Array<SongEvent> = [];
	public var tempoChanges:Array<TempoChange> = [new TempoChange(0, 100, 4, 4)];
	public var scrollSpeed:Float = 1;
	
	public var instLoaded:Bool;
	public var vocalsLoaded:Bool;
	public var instTrack:FlxSound;
	public var vocalTrack:FlxSound;
	
	public function new(path:String, keyCount:Int = 4) {
		this.path = path;
		this.keyCount = keyCount;
		
		instLoaded = false;
		instTrack = new FlxSound();
		vocalTrack = new FlxSound();
		FlxG.sound.list.add(instTrack);
		FlxG.sound.list.add(vocalTrack);
		
		var time:Float = Sys.time();
		trace('loading song music...');
		loadMusic('data/${path}/');
		loadMusic('songs/${path}/');
		trace(instLoaded ? ('Music loaded in ${Math.round((Sys.time() - time) * 1000) / 1000}s!') : ('Music failed to load...'));
	}
	
	public static function loadJson(path:String, difficulty:String = 'normal') {
		var jsonPathD:String = 'data/$path/$path';
		var diffSuffix:String = '-$difficulty';
		
		var jsonPath:String = '$jsonPathD$diffSuffix.json';
		if (!Paths.exists(jsonPath)) jsonPath = jsonPathD;
		if (Paths.exists(jsonPath)) {
			var content:String = Paths.text(jsonPath);
			var jsonData:Dynamic = TJSON.parse(content);
			if (jsonData.song != null) {
				return jsonData.song;
			} else {
				trace('Bad song JSON... (chart not generated)');
				return null;
			}
		} else {
			trace('Chart: $jsonPath');
			trace('Verify path:');
			trace('Song JSON not found... (chart not generated)');
			return null;
		}
	}
	
	public static function loadStepmaniaSong(path:String) {
	}

	// suffix is for playable characters
	public static function loadVSliceSong(path:String, difficulty:String = 'hard', suffix:String = '') {
		trace('Loading VSlice chart "$path"');

		var songPath:String = 'data/$path/$path';
		var chartPath:String = '$songPath-chart$suffix.json';
		var metaPath:String = '$songPath-metadata$suffix.json';
		var song:Song = new Song(path, 4);

		if (!Paths.exists(chartPath) || !Paths.exists(metaPath)) {
			trace('Metadata: $metaPath');
			trace('Chart: $chartPath');
			trace('Verify paths:');
			trace('Chart or Metadata JSON not found... (chart not generated)');
			return song;
		}

		try {
			var chartContent:String = Paths.text(chartPath);
			var metaContent:String = Paths.text(metaPath);
			song.chart = new FNFVSlice().fromJson(chartContent, metaContent);

			var meta:BasicMetaData = song.chart.getChartMeta();
			song.name = meta.title;
			song.scrollSpeed = meta.scrollSpeeds[difficulty] ?? 1;

			var bpmChanges:Array<BasicBPMChange> = meta.bpmChanges;
			var firstChange:BasicBPMChange = bpmChanges[0];
			var tempMetronome:Metronome = new Metronome(firstChange.bpm);
			song.initialBpm = tempMetronome.bpm;
			song.tempoChanges = [new TempoChange(0, song.initialBpm, 4, 4)];
			tempMetronome.tempoChanges = song.tempoChanges;
			for (change in bpmChanges) {
				var beat:Float = Conductor.convertMeasure(change.time, MS, BEAT, tempMetronome);
				song.tempoChanges.push(new TempoChange(beat, change.bpm, Std.int(change.beatsPerMeasure), Std.int(change.stepsPerBeat)));
			}

			var notes:Array<BasicNote> = song.chart.getNotes(difficulty);
			for (note in notes) {
				for (note in generateNotes(note.lane < 4, note.time, Std.int(note.lane % 4), '', note.length ?? 0, 250))
					song.notes.push(note);
			}
		} catch (e:Exception) {
			trace('Error when generating chart! -> <<< ${e.details()} >>>');
			return song;
		}

		return song;
	}
	
	public static function loadLegacySong(path:String, difficulty:String = 'normal', keyCount:Int = 4) {
		trace('Loading legacy chart "${path}"');
		
		var song = new Song(path, keyCount);
		song.json = Song.loadJson(path, difficulty);
		
		if (song.json == null) return song;
		
		var time = Sys.time();
		try {
			song.name = song.json.song;
			song.initialBpm = song.json.bpm;
			song.tempoChanges = [new TempoChange(0, song.initialBpm, 4, 4)];
			song.scrollSpeed = song.json.speed;
			
			var ms:Float = 0;
			var beat:Float = 0;
			var sectionNumerator:Float = 0;
			var osectionNumerator:Float = 0;
			
			var bpm:Float = song.initialBpm;
			var crochet:Float = 60000 / song.initialBpm;
			var stepCrochet:Float = crochet * .25;
			var focus:Null<Int> = null;
			
			var sections:Array<LegacySongSection> = song.json.notes;
			for (section in sections) {
				var sectionFocus:Int = (section.gfSection ? 2 : (section.mustHitSection ? 0 : 1));
				if (focus != sectionFocus) {
					focus = sectionFocus;
					song.events.push(new SongEvent('Focus', ms, [focus]));
				}
				
				var sectionDenominator:Int = 4;
				var sectionNumerator:Float = section.sectionBeats;
				if (sectionNumerator == 0) sectionNumerator = section.lengthInSteps * .25;
				if (sectionNumerator == 0) sectionNumerator = 4;
				while (sectionNumerator % 1 > 0 && sectionDenominator < 32) {
					sectionNumerator *= 2;
					sectionDenominator *= 2;
				}
				if (section.changeBPM || sectionNumerator != osectionNumerator) {
					osectionNumerator = sectionNumerator;
					if (section.changeBPM) bpm = section.bpm;
					crochet = 60000 / bpm / sectionDenominator * 4;
					stepCrochet = crochet * .25;
					
					song.tempoChanges.push(new TempoChange(beat, section.changeBPM ? section.bpm : 0, Std.int(sectionNumerator), sectionDenominator));
				}
				beat += sectionNumerator;
				ms += sectionNumerator * crochet;
				
				for (dataNote in section.sectionNotes) {
					var noteTime:Float = dataNote[0];
					var noteData:Int = Std.int(dataNote[1]);
					if (noteData < 0) { // old psych event
						song.events.push(new SongEvent(dataNote[2], noteTime, [dataNote[3], dataNote[4]]));
						continue;
					}

					var noteLength:Float = dataNote[2];
					var noteKind:Dynamic = dataNote[3];
					if (!Std.isOfType(noteKind, String)) noteKind = '';
					var playerNote:Bool = ((noteData < keyCount) == section.mustHitSection);
					
					for (note in generateNotes(playerNote, noteTime, noteData % keyCount, noteKind, noteLength, stepCrochet)) song.notes.push(note);
				}
			}
			song.sortNotes();
			trace('Chart loaded successfully! (${Math.round((Sys.time() - time) * 1000) / 1000}s)');
		} catch(e:Exception) {
			trace('Error when generating chart! -> <<< ${e.details()} >>>');
		}
		return song;
	}
	
	public static function generateNotes(playerNote:Bool, noteTime:Float, noteData:Int, noteKind:String = '', noteLength:Float = 0, stepCrochet:Float = 1000) {
		var notes:Array<Note> = [];
		var hitNote:Note = new Note(playerNote, noteTime, noteData, noteLength, noteKind);
		notes.push(hitNote);
		
		if (hitNote.msLength > 0) { //hold bits
			var holdBits:Float = noteLength / stepCrochet;
			for (i in 0...Math.ceil(holdBits)) {
				var bitTime:Float = i * stepCrochet;
				var bitLength:Float = stepCrochet;
				if (i == Math.ceil(holdBits - 1)) bitLength = (noteLength - bitTime);
				var holdBit:Note = new Note(playerNote, noteTime + bitTime, noteData, bitLength, noteKind, true);
				hitNote.children.push(holdBit);
				holdBit.parent = hitNote;
				notes.push(holdBit);
			}
			var endBit:Note = new Note(playerNote, noteTime + noteLength, noteData, 0, noteKind, true);
			hitNote.children.push(endBit);
			notes.push(endBit);
			
			endBit.parent = hitNote;
			hitNote.tail = endBit;
		}
		
		return notes;
	}
	
	public function loadMusic(path:String) {
		if (instLoaded) return true;
		try {
			vocalTrack.loadEmbedded(Paths.ogg('${path}Voices'));
			vocalsLoaded = (vocalTrack.length > 0);
			instTrack.loadEmbedded(Paths.ogg('${path}Inst'));
			instLoaded = (instTrack.length > 0);
			return true;
		} catch(e:Dynamic)
			return false;
	}
	
	public function sortNotes() {
		notes.sort((a, b) -> {
			var ord:Int = Std.int(a.msTime - b.msTime);
			if (ord == 0 && !a.isHoldPiece && b.isHoldPiece) return -1;
			return ord;
		});
	}
}

class SongEvent {
	public var event:String;
	public var msTime:Float;
	public var values:Array<Dynamic>;
	
	public function new(event:String, time:Float = 0, values:Null<Array<Dynamic>>) {
		this.event = event;
		this.msTime = time;
		if (values == null) this.values = [];
		else this.values = values;
	}
}

typedef LegacySongSection = {
	var sectionNotes:Array<Array<Dynamic>>;
	var sectionBeats:Float;
	var lengthInSteps:Float;
	var mustHitSection:Bool;
	var gfSection:Bool;
	var changeBPM:Bool;
	var bpm:Float;
}

typedef SongNote = { //IM STILL DEBATING IF I WANT TO DO THIS
	var msTime:Float;
	var msLength:Float;
	var strumIndex:Int; //todo: change all "noteData" by strumIndex?
	var strumlineIndex:Int;
	var noteKind:String;
}