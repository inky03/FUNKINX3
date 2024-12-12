package;

import Conductor.MetronomeMeasure;
import openfl.events.KeyboardEvent;
import flixel.util.FlxStringUtil;
import flixel.input.keyboard.FlxKey;
import flixel.addons.display.FlxBackdrop;

import openfl.display.Sprite;
import openfl.display.Bitmap;
import openfl.text.TextFormat;
import openfl.text.TextField;

class CharterState extends MusicBeatState {
	public static var inEditor:Bool = false;
	public static var song:Song;
	
	public var quant:Int = 4;
	public var quantText:FlxText;
	public var quantGraphic:FunkinSprite;
	public var measureLines:FlxTypedSpriteGroup<MeasureLine>;
	public var strumlines:FlxTypedSpriteGroup<CharterStrumline>;
	public var strumlineHighlight:FunkinSprite;
	public var charterDisplay:CharterDisplay;
	
	public var keybinds:Array<Array<FlxKey>> = [];
	public var tickSound:FlxSound;
	public var hitsound:FlxSound;
	
	public var scrollSpeed(default, set):Float = 1;
	public var songPaused(default, set):Bool;
	
	var scrolling:Bool = false;
	var strumGrabY:Null<Float> = null;
	var heldNotes:Array<Note> = [];
	var heldKeys:Array<FlxKey> = [];
	var heldKeybinds:Array<Bool> = [];
	var quants:Array<Int> = [4, 8, 12, 16, 24, 32, 48, 64, 96, 192];
	
	override public function create() {
		super.create();
		Main.watermark.visible = false;
		Main.instance.addChild(charterDisplay = new CharterDisplay(conductorInUse = new Conductor())); // wow!
		
		song ??= Song.loadSong('test');
		inEditor = true;
		
		FlxG.camera.zoom = .5;
		
		beatHit.add(beatHitEvent);
		barHit.add(barHitEvent);
		
		var background:FlxBackdrop = new FlxBackdrop(Paths.image('charter/bg'));
		background.antialiasing = true;
		background.scale.set(.85, .85);
		add(background);
		
		var underlay:FunkinSprite = new FunkinSprite(0, 0, false).makeGraphic(1, FlxG.height, 0xff808080);
		underlay.screenCenter();
		underlay.alpha = .5;
		add(underlay);
		
		measureLines = new FlxTypedSpriteGroup<MeasureLine>();
		strumlines = new FlxTypedSpriteGroup<CharterStrumline>();
		add(measureLines);
		add(strumlines);
		
		for (key in [FlxKey.ONE, FlxKey.TWO, FlxKey.THREE, FlxKey.FOUR, FlxKey.FIVE, FlxKey.SIX, FlxKey.SEVEN, FlxKey.EIGHT]) {
			keybinds.push([key]);
			heldNotes.push(null);
			heldKeybinds.push(false);
		}
		
		var strumlineSpacing:Float = 150;
		var xx:Float = 0;
		var h:Float = 0;
		for (i in 0...2) {
			var strumline = new CharterStrumline(4);
			strumline.x = xx;
			strumline.cpu = false;
			strumline.oneWay = false;
			strumlines.add(strumline);
			xx += strumline.strumlineWidth + strumlineSpacing;
			h = Math.max(h, strumline.strumlineHeight);
			for (lane in strumline.lanes) {
				lane.receptor.autoReset = true;
				lane.oneWay = false;
			}
		}
		strumlines.y = FlxG.height * .5 - h * .5;
		strumlines.x = (FlxG.width - (xx - strumlineSpacing)) * .5;
		
		strumlineHighlight = new FunkinSprite().makeGraphic(1, 1, FlxColor.WHITE);
		strumlineHighlight.setGraphicSize(strumlines.width, strumlines.height);
		strumlineHighlight.updateHitbox();
		strumlineHighlight.blend = ADD;
		strumlineHighlight.alpha = .25;
		
		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, keyPressEvent);
		FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, keyReleaseEvent);
		
		if (song != null) {
			song.instLoaded = false;
			var songPaths:Array<String> = ['data/songs/${song.path}/', 'songs/${song.path}/'];
			for (path in songPaths) song.loadMusic(path, false);
			if (song.instLoaded)
				song.inst.onComplete = finishSong;
			
			scrollSpeed = song.scrollSpeed;
			conductorInUse.metronome.tempoChanges = song.tempoChanges;
			conductorInUse.syncTracker = song.instLoaded ? song.inst : null;
			
			for (note in song.generateNotes()) {
				var strumline:Strumline = (note.player ? strumlines.members[0] : strumlines.members[1]);
				strumline?.queueNote(note);
			}
		}
		songPaused = true;
		charterDisplay.songLength = findSongLength();
		
		var bgPadding:Float = 50;
		underlay.setGraphicSize(strumlines.width + bgPadding * 2, FlxG.height * 5);
		
		quantGraphic = new FunkinSprite().loadAtlas('charter/quant');
		quantGraphic.addAnimation('quant', 'new quant', 0);
		quantGraphic.playAnimation('quant', true);
		quantGraphic.updateHitbox();
		//quantGraphic.x = strumlines.x + xx - strumlineSpacing;
		quantGraphic.y = strumlines.y + (h - quantGraphic.height) * .5;
		quantGraphic.screenCenter(X);
		add(quantGraphic);
		
		quantText = new FlxText(0, 0, 300);
		quantText.setFormat(Paths.ttf('vcr'), 40, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		quantText.borderSize = 4;
		quantText.updateHitbox();
		quantText.y = strumlines.y + (h - quantText.height) * .5;
		quantText.screenCenter(X);
		add(quantText);
		changeQuant(0);
		
		add(strumlineHighlight);
		
		for (i in 0...Math.ceil(findSongLength() / conductorInUse.crochet / 4)) { // todo: actually make this fucking good :sob:
			var test:MeasureLine = new MeasureLine(strumlines.x - bgPadding, strumlines.y, i, i * 4, 4, strumlines.width + bgPadding * 2, Note.msToDistance(conductorInUse.crochet, scrollSpeed));
			measureLines.add(test);
		}
		
		tickSound = new FlxSound().loadEmbedded(Paths.sound('beatTick'));
		hitsound = new FlxSound().loadEmbedded(Paths.sound('hitsound'));
		hitsound.volume = .7;
	}
	
	override public function update(elapsed:Float) {
		elapsed = getRealElapsed();
		
		if (FlxG.keys.justPressed.ENTER) {
			song ??= new Song('unnamed');
			song.tempoChanges = conductorInUse.metronome.tempoChanges;
			saveToSong(song);
			PlayState.song = song;
			FlxG.switchState(new PlayState());
			return;
		}
		
		var strumlinesHighlighted:Bool = FlxG.mouse.overlaps(strumlineHighlight);
		strumlineHighlight.setPosition(strumlines.x, strumlines.y);
		if (FlxG.mouse.justPressed && strumlinesHighlighted)
			strumGrabY = (FlxG.mouse.y - strumlines.y);
		if (FlxG.mouse.justReleased)
			strumGrabY = null;
		strumlineHighlight.visible = (strumlinesHighlighted || strumGrabY != null);
		if (FlxG.mouse.pressed && strumGrabY != null) {
			var h:Float = strumlines.height;
			var middle:Float = (FlxG.height - h) * .5;
			var maxDist:Float = (FlxG.height - h - 25) * .5 / FlxG.camera.zoom;
			strumlines.y = Util.clamp(FlxG.mouse.y - strumGrabY, -maxDist + middle, maxDist + middle);
			strumlineHighlight.setPosition(strumlines.x, strumlines.y);
			
			quantGraphic.y = strumlines.y + (h - quantGraphic.height) * .5;
			quantText.y = strumlines.y + (h - quantText.height) * .5;
		}
		
		if (FlxG.keys.pressed.W || FlxG.keys.pressed.S) {
			var up:Bool = FlxG.keys.pressed.W;
			var msPerSec:Float = (FlxG.keys.pressed.SHIFT ? 2000 : 1000);
			var scrollMod:Int = 1;
			if (up) scrollMod *= -1;
			
			if (songPaused)
				songPaused = false;
			conductorInUse.paused = true;
			conductorInUse.songPosition += scrollMod * elapsed * msPerSec;
			restrictConductor();
			
			if ((msPerSec != 1000 || up || !scrolling) && song != null && song.instLoaded)
				song.inst.time = conductorInUse.songPosition;
			
			scrolling = true;
		} else if (scrolling) {
			songPaused = true;
			scrolling = false;
		}
		
		if (FlxG.keys.justPressed.SPACE) songPaused = !songPaused;
		super.update(elapsed);
		for (strumline in strumlines) {
			for (lane in strumline.lanes) {
				for (note in lane.notes) {
					if (!conductorInUse.paused) {
						if (conductorInUse.songPosition >= note.msTime) {
							if (conductorInUse.songPosition <= note.endMs || !note.goodHit) {
								lane.receptor?.playAnimation('confirm', true);
								if (!note.goodHit && !note.isHoldPiece)
									hitsound.play(true);
								note.goodHit = true;
							}
						}
					} else {
						note.goodHit = (conductorInUse.songPosition > note.msTime + 1);
					}
				}
			}
		}
		
		if (songPaused) {
			FlxG.camera.zoom = Util.smoothLerp(FlxG.camera.zoom, .5, elapsed * 9);
		} else {
			var metronome:Conductor.Metronome = conductorInUse.metronome;
			var beatZoom:Float = 1 - FlxEase.quintOut(metronome.beat % 1);
			var barZoom:Float = 1 - FlxEase.quintOut(Math.min((metronome.bar % 1) * metronome.timeSignature.numerator, 1));
			FlxG.camera.zoom = .5 + beatZoom * .003 + barZoom * .005;
		}
		
		for (line in measureLines) {
			line.y = strumlines.y + strumlines.height * .5 + Note.msToDistance(conductorInUse.metronome.convertMeasure(line.startTime, BEAT, MS) - conductorInUse.songPosition, scrollSpeed);
		}
		
		if (!paused)
			updateHolds();
	}
	override public function updateConductor(elapsed:Float = 0) {
		var prevStep:Int = curStep;
		var prevBeat:Int = curBeat;
		var prevBar:Int = curBar;

		conductorInUse.update(elapsed * 1000);
		
		curStep = Math.floor(conductorInUse.metronome.step);
		curBeat = Math.floor(conductorInUse.metronome.beat);
		curBar = Math.floor(conductorInUse.metronome.bar);
		
		if (!songPaused) {
			if (prevBar != curBar) barHit.dispatch(curBar);
			if (prevBeat != curBeat) beatHit.dispatch(curBeat);
			if (prevStep != curStep) stepHit.dispatch(curStep);
		}
	}
	
	public function beatHitEvent(beat:Int) {
		tickSound.play(true);
	}
	public function barHitEvent(bar:Int) {}
	public function finishSong() {
		songPaused = true;
	}
	
	public function set_scrollSpeed(newSpeed:Float) {
		for (strumline in strumlines) {
			strumline.scrollSpeed = newSpeed;
			/*for (lane in strumline.lanes)
				lane.spawnRadius *= 1.5;*/
		}
		return scrollSpeed = newSpeed;
	}
	public function set_songPaused(isPaused:Bool) {
		if (song != null && song.instLoaded) {
			if (isPaused) {
				song.inst.stop();
			} else {
				if (conductorInUse.songPosition >= song.inst.length)
					return songPaused = true;
				song.inst.play(true, conductorInUse.songPosition);
			}
		}
		for (strumline in strumlines) {
			FlxTween.cancelTweensOf(strumline, ['receptorAlpha']);
			FlxTween.tween(strumline, {receptorAlpha: (isPaused ? .75 : 1)}, .25, {ease: FlxEase.circOut});
			for (lane in strumline.lanes) {
				if (isPaused)
					lane.receptor?.playAnimation('static');
			}
		}
		conductorInUse.paused = isPaused;
		return songPaused = isPaused;
	}
	
	public function keyPressEvent(event:KeyboardEvent) {
		var key:FlxKey = event.keyCode;
		if (!heldKeys.contains(key)) heldKeys.push(key);
		
		var keybind:Int = Controls.keybindFromArray(keybinds, key);
		if (keybind >= 0 && FlxG.keys.checkStatus(key, JUST_PRESSED))
			inputOn(keybind);
		
		var scrollMod:Int = 1;
		var leniency:Float = 1 / 256;
		var prevBeat:Float = conductorInUse.metronome.beat;
		var quantMultiplier:Float = (quant * .25);
		var pauseSong:Bool = false;
		switch (key) {
			case FlxKey.LEFT | FlxKey.RIGHT:
				changeQuant(key == FlxKey.LEFT ? -1 : 1);
			case FlxKey.UP | FlxKey.DOWN:
				placeNotes();
				pauseSong = true;
				if (key == FlxKey.UP) scrollMod *= -1;
				var targetBeat:Float = prevBeat + scrollMod / quantMultiplier;
				if (Math.abs(prevBeat - Math.round(prevBeat * quantMultiplier) / quantMultiplier) < leniency * 2)
					conductorInUse.metronome.setBeat(Math.round(targetBeat * quantMultiplier) / quantMultiplier);
				else
					conductorInUse.metronome.setBeat((scrollMod > 0 ? Math.floor : Math.ceil)(targetBeat * quantMultiplier) / quantMultiplier);
			case FlxKey.PAGEUP | FlxKey.PAGEDOWN:
				placeNotes();
				pauseSong = true;
				if (key == FlxKey.PAGEUP) scrollMod *= -1;
				if (Math.abs(conductorInUse.metronome.bar - Std.int(conductorInUse.metronome.bar)) < (1 / quant - .0006))
					conductorInUse.metronome.setBar(Math.max(0, conductorInUse.metronome.bar + scrollMod));
				conductorInUse.metronome.setBar((scrollMod < 0 ? Math.floor : Math.ceil)(conductorInUse.metronome.bar));
			case FlxKey.HOME:
				pauseSong = true;
				conductorInUse.metronome.setMS(0);
			case FlxKey.END:
				pauseSong = true;
				conductorInUse.metronome.setMS(findSongLength());
			default:
		}
		
		if (pauseSong && !songPaused)
			songPaused = true;
		
		restrictConductor();
		updateHolds();
	}
	public function restrictConductor() {
		var limitTime:Float = Math.max(conductorInUse.metronome.ms, 0);
		if (song != null && song.instLoaded)
			limitTime = Math.min(limitTime, song.inst.length);
		conductorInUse.songPosition = limitTime;
	}
	public function placeNotes() {
		for (key => held in heldKeybinds) {
			if (held && heldNotes[key] == null)
				placeNote(key);
		}
	}
	public function findSongLength() {
		var length:Null<Float> = song?.songLength;
		if (length == null) // todo
			length = 0;
		return length;
	}
	public function keyReleaseEvent(event:KeyboardEvent) {
		var key:FlxKey = event.keyCode;
		heldKeys.remove(key);
		
		var keybind:Int = Controls.keybindFromArray(keybinds, key);
		if (keybind >= 0) inputOff(keybind);
	}
	
	public function changeQuant(mod:Int) {
		var quantIndex:Int = FlxMath.wrap(quants.indexOf(quant) + mod, 0, quants.length - 1);
		quantGraphic.animation.curAnim.curFrame = Std.int(Math.min(quantIndex, quantGraphic.animation.curAnim.numFrames - 1));
		quant = quants[quantIndex];
		quantText.text = Std.string(quant);
	}
	public function inputOn(keybind:Int) {
		heldKeybinds[keybind] = true;
		placeNote(keybind);
	}
	public function placeNote(keybind:Int) {
		var strumlineId:Int = 0;
		var data:Int = keybind;
		for (strumline in strumlines) {
			if (data >= strumline.laneCount) {
				data -= strumline.laneCount;
				strumlineId ++;
			}
		}
		var quantMultiplier:Float = (quant * .25);
		var strumline:Strumline = strumlines.members[strumlineId];
		var lane = strumline.getLane(data);
		var matchingNote:Null<Note> = null;
		for (note in lane.notes) {
			if (note.isHoldPiece) continue;
			if (Math.abs(note.beatTime - conductorInUse.metronome.beat) < 1 / quantMultiplier - .0012) {
				matchingNote = note;
				break;
			}
		}
		if (matchingNote == null) {
			hitsound.play(true);
			var isPlayer:Bool = (strumlineId == 0);
			var snappedBeat:Float = Math.round(conductorInUse.metronome.beat * quantMultiplier) / quantMultiplier;
			var note:Note = new Note(isPlayer, 0, data);
			note.extraData['keybind'] = keybind;
			note.beatTime = snappedBeat;
			note.preventDespawn = true;
			heldNotes[keybind] = note;
			lane.insertNote(note);
		} else {
			for (child in matchingNote.children) {
				lane.killNote(child);
				child.destroy();
			}
			lane.killNote(matchingNote);
			matchingNote.destroy();
		}
	}
	public function inputOff(keybind:Int) {
		heldKeybinds[keybind] = false;
		var note:Note = heldNotes[keybind];
		if (note != null) {
			FlxG.sound.play(Paths.sound('hitsoundTail'), .7);
			for (child in note.children) child.preventDespawn = false;
			note.preventDespawn = false;
			heldNotes[keybind] = null;
		}
	}
	public function updateHolds() {
		var quantMultiplier:Float = (quant * .25);
		var snappedBeat:Float = Math.round(conductorInUse.metronome.beat * quantMultiplier) / quantMultiplier;
		for (note in heldNotes) {
			if (note == null) continue;
			var lane:Lane = note.lane;
			note.beatLength = snappedBeat - note.beatTime;
			if (note.beatLength > 0) {
				if (note.children.length == 0) {
					var piece:Note = new Note(note.player, note.msTime, note.noteData, note.msLength, note.noteKind, true);
					piece.preventDespawn = true;
					note.children.push(piece);
					piece.parent = note;
					var tail:Note = new Note(note.player, note.msTime, note.noteData, 0, note.noteKind, true);
					tail.preventDespawn = true;
					note.children.push(tail);
					tail.parent = note;
					note.tail = tail;
					
					lane.insertNote(tail);
					lane.insertNote(piece);
					
					piece.beatLength = note.beatLength; //What
					tail.beatTime = snappedBeat;
				} else {
					var piece:Note = note.children[0];
					piece.beatLength = note.beatLength;
					note.tail.beatTime = snappedBeat;
					
					lane.updateNote(note.tail);
					lane.updateNote(piece);
				}
			} else {
				while (note.children.length > 0) {
					var child:Note = note.children.shift();
					lane.killNote(child);
					child.destroy();
				}
			}
		}
	}
	public function saveToSong(song:Song) {
		if (song == null) return;
		song.notes.resize(0);
		for (strumline in strumlines) {
			for (lane in strumline.lanes) {
				for (note in lane.getAllNotes()) {
					if (note.isHoldPiece) continue;
					song.notes.push(note.toSongNote());
				}
			}
		}
		song.findSongLength();
		song.sort();
	}
	
	override public function destroy() {
		inEditor = false;
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, keyPressEvent);
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_UP, keyReleaseEvent);
		Main.instance.removeChild(charterDisplay);
		Main.watermark.visible = true;
		super.destroy();
	}
}

class MeasureLine extends FlxSpriteGroup {
	public var barText:FlxText;
	public var startTime:Float;
	public var ySpacing(default, set):Float;
	public var lineWidth(default, set):Float;
	public var measureBeats(default, set):Int;
	public var lines:FlxTypedSpriteGroup<FunkinSprite>; //this is getting outta hand
	
	public function new(x:Float = 0, y:Float = 0, bar:Int = 0, time:Float = 0, beats:Int = 4, width:Float = 160, spacing:Float = 160) {
		super(x, y);
		lines = new FlxTypedSpriteGroup<FunkinSprite>();
		measureBeats = beats;
		ySpacing = spacing;
		lineWidth = width;
		startTime = time;
		
		add(lines);
		
		barText = new FlxText(0, 0, 400, Std.string(bar));
		barText.setFormat(Paths.font('vcr.ttf'), 40, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		barText.y += -barText.height * .5 + 3;
		barText.x = -barText.width - 24;
		barText.active = false;
		add(barText);
	}
	
	public function set_measureBeats(newBeats:Int) {
		if (measureBeats == newBeats) return newBeats;
		while (lines.length > 0 && lines.length >= newBeats) {
			var line = lines.members[0];
			lines.remove(line, true);
			line.destroy();
		}
		var isBar:Bool = true;
		for (i in 0...newBeats) {
			var line:FunkinSprite;
			if (i >= lines.length) {
				line = new FunkinSprite();
				line.makeGraphic(1, 1, -1);
				line.spriteOffset.y = .5;
				line.active = false;
				lines.add(line);
			} else
				line = cast lines.members[i];
			line.y = i * ySpacing;
			line.setGraphicSize(width, isBar ? 12 : 6);
			line.alpha = (isBar ? .8 : .5);
			line.updateHitbox();
			line.active = false;
			isBar = false;
		}
		return measureBeats = newBeats;
	}
	public function set_ySpacing(newSpacing:Float) {
		if (ySpacing == newSpacing) return newSpacing;
		var i:Int = 0;
		for (line in lines) {
			line.y = i * newSpacing;
			i ++;
		}
		return ySpacing = newSpacing;
	}
	public function set_lineWidth(newWidth:Float) {
		if (lineWidth == newWidth) return newWidth;
		for (line in lines) {
			line.setGraphicSize(newWidth, line.height);
			line.updateHitbox();
		}
		return lineWidth = newWidth;
	}
}

class CharterDisplay extends Sprite {
	public var metronomeText:TextField;
	public var songPosText:TextField;
	public var background:Bitmap;
	
	public var conductor:Conductor;
	public var songLength:Float = 0;
	
	public function new(conductor:Conductor) {
		super();
		
		this.conductor = conductor;
		
		var metronomeTf:TextFormat = new TextFormat(Paths.ttf('vcr'), 15, -1);
		metronomeTf.leading = -2;
		
		background = new Bitmap(new openfl.display.BitmapData(1, 1, true, FlxColor.BLACK));
		background.alpha = .6;
		addChild(background);
		
		metronomeText = new TextField();
		metronomeText.defaultTextFormat = metronomeTf;
		songPosText = new TextField();
		songPosText.defaultTextFormat = new TextFormat(Paths.ttf('vcr'), 12, -1);
		
		for (text in [metronomeText, songPosText]) {
			text.x = 10;
			text.autoSize = LEFT;
			text.multiline = true;
			text.selectable = false;
			text.mouseEnabled = false;
			addChild(text);
		}
	}
	public function updateMetronomeInfo() {
		var metronome:Conductor.Metronome = conductor.metronome;
		metronomeText.text = 'Measure: ${Math.floor(metronome.bar)}\nBeat: ${Math.floor(metronome.beat)}\nStep: ${Math.floor(metronome.step)}';
		songPosText.text = FlxStringUtil.formatTime(metronome.ms * .001, true) + ' / ' + FlxStringUtil.formatTime(songLength * .001, true);
	}
	
	override function __enterFrame(deltaTime:Float) {
		updateMetronomeInfo();
		y = FlxG.stage.window.height;
		metronomeText.y = -metronomeText.textHeight - 32;
		songPosText.y = -songPosText.textHeight - 12;
		var bgHeight:Float = songPosText.textHeight + metronomeText.textHeight + 28;
		
		background.scaleX = Math.max(Math.max(songPosText.textWidth, metronomeText.textWidth) + 24, 120);
		background.scaleY = bgHeight;
		background.y = -bgHeight;
	}
}

class CharterStrumline extends Strumline {
	public var receptorAlpha:Float = 1;
	
	public function new(laneCount:Int = 4, direction:Float = 90, scrollSpeed:Float = 1) {
		super(laneCount, direction, scrollSpeed);
	}
	
	public override function draw() {
		for (lane in lanes) { // draw hit notes on bottom
			if (!lane.selfDraw) {
				if (lane.receptor != null)
					lane.receptor.alpha = receptorAlpha;
				lane.topMembers.remove(lane.notes);
				for (note in lane.notes) {
					if (note.goodHit || (note.parent != null && note.parent.goodHit))
						note.draw();
				}
			}
		}
		super.draw();
		for (lane in lanes) { // draw on top
			if (!lane.selfDraw) {
				if (lane.receptor != null)
					lane.receptor.alpha = 1;
				for (note in lane.notes) {
					if (!note.goodHit && !(note.parent != null && note.parent.goodHit))
						note.draw();
				}
				lane.drawTop();
			}
		}
	}
}