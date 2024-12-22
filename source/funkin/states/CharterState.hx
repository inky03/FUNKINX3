package funkin.states;

import funkin.objects.play.*;
import funkin.shaders.RGBSwap;
import funkin.backend.play.Song;
import funkin.states.FreeplaySubState.FreeplaySongText;

import sys.thread.Thread;
import openfl.display.Sprite;
import openfl.display.Bitmap;
import openfl.text.TextFormat;
import openfl.text.TextField;
import openfl.events.MouseEvent;
import openfl.events.KeyboardEvent;
import flixel.util.FlxStringUtil;
import flixel.input.keyboard.FlxKey;
import flixel.addons.display.FlxBackdrop;

class CharterState extends funkin.backend.states.FunkinState {
	public static var genericRGB:RGBSwap;
	
	public static var instance:CharterState;
	public static var inEditor:Bool = false;
	public static var song:Song;
	
	public var quant:Int = 4;
	public var quantText:FlxText;
	public var quantGraphic:FunkinSprite;
	public var measureLines:FlxTypedSpriteGroup<MeasureLine>;
	public var strumlines:FlxTypedSpriteGroup<CharterStrumline>;
	public var strumlineHighlight:FunkinSprite;
	public var charterDisplay:CharterDisplay;
	public var camHUD:FunkinCamera;
	public var camScroll:FunkinCamera;
	
	public var noteKindBubble:FunkinSprite;
	public var noteKindBubbleText:FreeplaySongText;
	public var noteKindBubbleFocusGraphic:FlxGraphic;
	
	public var selectionBox:FlxSprite;
	public var selectionLeniency:Float = 55;
	public var pickedNote:CharterNote = null;
	public var draggingNotes:Bool = false;
	var pickedLaneIndex:Int = 0;
	var pickedBeat:Float = 0;
	
	public var keybinds:Array<Array<FlxKey>> = [];
	public var tickSound:FlxSound;
	public var hitsound:FlxSound;
	
	public var scrollSpeed(default, set):Float = 1;
	public var songPaused(default, set):Bool;
	var visualScrollSpeed(get, never):Float;
	
	public var fullNoteCount:Int = 0;
	public var hitNoteCount:Int = 0;
	
	var lastMouseY:Float = 0;
	var scrolling:Bool = false;
	var strumGrabY:Null<Float> = null;
	var heldKeys:Array<FlxKey> = [];
	var heldKeybinds:Array<Bool> = [];
	var copiedNotes:Array<SongNote> = [];
	var heldNotes:Array<CharterNote> = [];
	var quants:Array<Int> = [4, 8, 12, 16, 24, 32, 48, 64, 96, 192];
	
	var undoMemory:Int = 15;
	var undoActions:Array<UndoAction> = [];
	var redoActions:Array<UndoAction> = [];
	
	override public function create() {
		super.create();
		Main.watermark.visible = false;
		Main.instance.addChild(charterDisplay = new CharterDisplay(conductorInUse = new Conductor())); // wow!
		
		beatHit.add(beatHitEvent);
		barHit.add(barHitEvent);
		
		genericRGB ??= new RGBSwap(0xb3a9b8, FlxColor.WHITE, 0x333333);
		song ??= Song.loadSong('test');
		inEditor = true;
		instance = this;
		
		FlxG.camera.zoom = .5;
		
		camHUD = new FunkinCamera();
		camScroll = new FunkinCamera();
		camScroll.bgColor.alpha = 0;
		camHUD.bgColor.alpha = 0;
		FlxG.cameras.add(camScroll, false);
		FlxG.cameras.add(camHUD, false);
		
		noteKindBubble = new FunkinSprite().loadTexture('charter/bubble');
		noteKindBubble.scale.set(.75, .75);
		noteKindBubble.updateHitbox();
		noteKindBubble.camera = camHUD;
		noteKindBubble.color = 0xff323034;
		noteKindBubble.alpha = .6;
		noteKindBubbleText = new FreeplaySongText(0, 0, '', 0x808080, .8); //ffe0b0d0;
		noteKindBubbleText.size = 16;
		noteKindBubbleText.angle = -3;
		noteKindBubbleText.origin.set(0, 6);
		noteKindBubbleText.camera = camHUD;
		
		selectionBox = new FlxSprite().makeGraphic(1, 1, FlxColor.LIME);
		selectionBox.camera = camScroll;
		selectionBox.visible = false;
		selectionBox.blend = ADD;
		selectionBox.alpha = .25;
		selectionBox.origin.set();
		add(selectionBox);
		var background:FlxBackdrop = new FlxBackdrop(Paths.image('charter/bg'));
		background.antialiasing = true;
		background.scale.set(.85, .85);
		background.velocity.set(5, 5);
		add(background);
		var underlay:FunkinSprite = new FunkinSprite(0, 0, false).makeGraphic(1, FlxG.height, 0xff101010);
		underlay.screenCenter();
		underlay.alpha = .7;
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
		strumlines.y = FlxG.height * .5 - h * .5 - 320;
		strumlines.x = (FlxG.width - (xx - strumlineSpacing)) * .5;
		
		strumlineHighlight = new FunkinSprite().makeGraphic(1, 1, 0xffb094b0);
		strumlineHighlight.setGraphicSize(strumlines.width, strumlines.height);
		strumlineHighlight.updateHitbox();
		strumlineHighlight.blend = ADD;
		strumlineHighlight.alpha = .25;
		
		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, keyPressEvent);
		FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, keyReleaseEvent);
		FlxG.stage.addEventListener(MouseEvent.MOUSE_MOVE, mouseMoveEvent);
		
		if (song != null) {
			setWindowTitle();
			song.instLoaded = false;
			var songPaths:Array<String> = ['data/songs/${song.path}/', 'songs/${song.path}/'];
			for (path in songPaths) song.loadMusic(path, false);
			if (song.instLoaded)
				song.inst.onComplete = finishSong;
			
			scrollSpeed = song.scrollSpeed;
			conductorInUse.metronome.tempoChanges = song.tempoChanges;
			conductorInUse.syncTracker = song.instLoaded ? song.inst : null;
			
			for (note in song.generateNotes(true))
				queueNote(note);
		}
		songPaused = true;
		recalculateNoteCount();
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
			var test:MeasureLine = new MeasureLine(strumlines.x - bgPadding, strumlines.y, i, i * 4, 4, strumlines.width + bgPadding * 2, Note.msToDistance(conductorInUse.crochet, visualScrollSpeed));
			measureLines.add(test);
		}
		
		tickSound = FunkinSound.load(Paths.sound('beatTick'));
		hitsound = FunkinSound.load(Paths.sound('hitsound'));
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
		
		// selection and dragging
		var highlightedNote:CharterNote = null;
		var highlightedSelNote:CharterNote = null;
		var anyNoteHovered:Bool = (pickedNote != null);
		forEachNote((note:Note) -> {
			var charterNote:CharterNote = cast note;
			if (charterNote == null) return;
			
			if (!note.isHoldPiece && FlxG.mouse.overlaps(note)) {
				anyNoteHovered = true;
				if (charterNote.selected) {
					if (highlightedSelNote == null) {
						highlightedSelNote = charterNote;
					} else {
						var mousePoint:FlxPoint = FlxG.mouse.getWorldPosition();
						if (mousePoint.distanceTo(note.getMidpoint()) < mousePoint.distanceTo(highlightedSelNote.getMidpoint()))
							highlightedSelNote = charterNote;
					}
					if (FlxG.mouse.justPressed) {
						pickedNote = highlightedSelNote;
						pickedBeat = pickedNote.beatTime;
						pickedLaneIndex = laneToIndex(pickedNote.lane);
					}
				} else {
					if (highlightedNote == null) {
						highlightedNote = charterNote;
					} else {
						var mousePoint:FlxPoint = FlxG.mouse.getWorldPosition();
						if (mousePoint.distanceTo(note.getMidpoint()) < mousePoint.distanceTo(highlightedNote.getMidpoint()))
							highlightedNote = charterNote;
					}
				}
			}
		});
		
		var selectedAny:Bool = false;
		var isSelecting:Bool = (selectionBox.visible && Math.abs(selectionBox.scale.x) >= 12 && Math.abs(selectionBox.scale.y) >= 12);
		if (FlxG.mouse.pressed && strumGrabY == null) {
			if (pickedNote != null) {
				var pickedLane:Lane = null; // drag and twist notes
				for (strumline in strumlines) {
					for (lane in strumline.lanes) {
						if (FlxG.mouse.x >= lane.receptor.x && FlxG.mouse.x <= lane.receptor.x + lane.receptor.width) {
							pickedLane = lane;
							break;
						}
					}
				}
				var selectedNotes:Array<CharterNote> = getSelectedNotes();
				
				readjustScrollCam();
				var quantMult:Float = (quant / 4);
				var cursorBeatTime:Float = Note.distanceToMS(FlxG.mouse.getWorldPosition(camScroll).y, visualScrollSpeed) / conductorInUse.crochet;
				var snappedBeatTime:Float = Math.round(cursorBeatTime * quantMult) / quantMult;
				var beatDiff:Float = (snappedBeatTime - pickedNote.beatTime);
				
				if (shiftNotes(selectedNotes, beatDiff) != 0)
					draggingNotes = true;
				
				if (pickedLane != null && pickedLane != pickedNote.lane) {
					var laneDiff:Int = laneToIndex(pickedLane) - laneToIndex(pickedNote.lane);
					if (twistNotes(selectedNotes, laneDiff) != 0)
						draggingNotes = true;
				}
			} else {
				var mousePos:FlxPoint = FlxG.mouse.getWorldPosition(camScroll);
				if (FlxG.mouse.justPressed || !selectionBox.visible) {
					selectionBox.setPosition(mousePos.x, mousePos.y);
					selectionBox.visible = true;
				}
				selectionBox.scale.set(mousePos.x - selectionBox.x, mousePos.y - selectionBox.y);
			}
		} else if (selectionBox.visible) {
			//do the selection!
			var selectionBounds:FlxRect = selectionBox.getScreenBounds(null, camScroll);
			if (selectionBox.scale.x < 0) selectionBounds.x += selectionBox.scale.x;
			if (selectionBox.scale.y < 0) selectionBounds.y += selectionBox.scale.y;
			
			if (isSelecting) {
				forEachNote((note:Note) -> {
					if (note.isHoldPiece) return;
					var charterNote:CharterNote = cast note;
					if (charterNote == null) return;
					
					charterNote.followLane(note.lane, note.lane.scrollSpeed);
					
					var noteBounds:FlxRect = charterNote.getScreenBounds();
					noteBounds.x += selectionLeniency;
					noteBounds.y += selectionLeniency;
					noteBounds.width -= selectionLeniency * 2;
					noteBounds.height -= selectionLeniency * 2;
					if (noteBounds.overlaps(selectionBounds)) {
						charterNote.selected = true;
						selectedAny = true;
					} else if (!FlxG.keys.pressed.SHIFT) {
						charterNote.selected = false;
					}
				}, true);
			}
			
			selectionBox.visible = false;
		}
		if (highlightedNote == null)
			highlightedNote = highlightedSelNote;
		forEachNote((note:Note) -> {
			var charterNote:CharterNote = cast note;
			if (charterNote == null) return;
			
			charterNote.highlighted = (highlightedNote == note);
		});
		if (FlxG.mouse.justReleased) {
			if (pickedNote != null) {
				final beatDiff:Float = pickedNote.beatTime - pickedBeat;
				final laneDiff:Int = laneToIndex(pickedNote.lane) - pickedLaneIndex;
				if (beatDiff != 0 || laneDiff != 0)
					addUndo({type: SHIFTED_NOTES, notes: getSelectedNotes(), laneMod: laneDiff, beatMod: beatDiff});
			}
			if (!FlxG.keys.pressed.SHIFT && !draggingNotes && !selectedAny && strumGrabY == null) {
				for (note in getSelectedNotes())
					note.selected = false;
			}
			if (highlightedNote != null)
				highlightedNote.selected = true;
			draggingNotes = false;
			pickedNote = null;
		}
		
		// time shift
		if (!FlxG.keys.pressed.CONTROL && FlxG.keys.pressed.W != FlxG.keys.pressed.S) {
			var msPerSec:Float = (FlxG.keys.pressed.SHIFT ? 2000 : 1000);
			if (FlxG.keys.pressed.W)
				msPerSec *= -1;
			
			if (songPaused)
				songPaused = false;
			conductorInUse.paused = true;
			conductorInUse.songPosition += elapsed * msPerSec;
			restrictConductor();
			
			if (song != null && song.instLoaded) {
				if (conductorInUse.songPosition <= 0 && msPerSec < 0) {
					song.inst.stop();
				} else if (msPerSec != 1000 || !scrolling || !song.inst.playing) {
					if (!song.inst.playing)
						song.inst.play(true, conductorInUse.songPosition);
					else
						song.inst.time = conductorInUse.songPosition;
				}
			}
			
			scrolling = true;
		} else if (scrolling) {
			songPaused = true;
			scrolling = false;
		}
		
		// receptor dragging
		var strumlinesHighlighted:Bool = (FlxG.mouse.overlaps(strumlineHighlight) && !isSelecting && !anyNoteHovered && !FlxG.mouse.pressedRight);
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
		
		if (FlxG.keys.justPressed.SPACE) songPaused = !songPaused;
		super.update(elapsed);
		forEachNote((note:Note) -> {
			var lane:Lane = note.lane;
			if (!conductorInUse.paused) {
				if (conductorInUse.songPosition >= note.msTime && (conductorInUse.songPosition <= note.endMs || !note.goodHit)) {
					lane.receptor?.playAnimation('confirm', true);
					if (!note.goodHit && !note.isHoldPiece)
						hitsound.play(true);
					note.goodHit = true;
				}
			} else {
				note.goodHit = (conductorInUse.songPosition > note.msTime + 1);
			}
		});
		
		if (songPaused) {
			FlxG.camera.zoom = Util.smoothLerp(FlxG.camera.zoom, .5, elapsed * 9);
		} else {
			var metronome:Metronome = conductorInUse.metronome;
			var beatZoom:Float = 1 - FlxEase.quintOut(metronome.beat % 1);
			var barZoom:Float = 1 - FlxEase.quintOut(Math.min((metronome.bar % 1) * metronome.timeSignature.numerator, 1));
			FlxG.camera.zoom = .5 + beatZoom * .003 + barZoom * .005;
		}
		
		readjustScrollCam();
		for (line in measureLines) {
			line.y = strumlines.y + strumlines.height * .5 + Note.msToDistance(conductorInUse.metronome.convertMeasure(line.startTime, BEAT, MS) - conductorInUse.songPosition, visualScrollSpeed);
		}
		
		if (!paused)
			updateHolds();
	}
	public function readjustScrollCam() {
		camScroll.scroll.y = Note.msToDistance(conductorInUse.songPosition, visualScrollSpeed) - strumlines.y - strumlines.height * .5;
		camScroll.zoom = FlxG.camera.zoom;
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
	public function mouseMoveEvent(event:MouseEvent) {
		if (FlxG.mouse.pressedRight) {
			if (!songPaused)
				songPaused = true;
			conductorInUse.songPosition -= Note.distanceToMS((event.stageY - lastMouseY) / Util.gameScaleY / FlxG.camera.zoom, visualScrollSpeed);
			restrictConductor();
			
			if (event.stageY <= 5) {
				lastMouseY = (FlxG.stage.window.height - 5) + event.stageY - 10;
				FlxG.stage.window.warpMouse(Std.int(event.stageX), Std.int(lastMouseY));
				return;
			} else if (event.stageY >= FlxG.stage.window.height - 5) {
				lastMouseY = 10 + event.stageY - (FlxG.stage.window.height - 5);
				FlxG.stage.window.warpMouse(Std.int(event.stageX), Std.int(lastMouseY));
				return;
			}
		}
		lastMouseY = event.stageY;
	}
	public function finishSong() {
		songPaused = true;
		conductorInUse.songPosition = song.inst.length;
	}
	public function forEachNote(func:Note -> Void, includeQueued:Bool = false) {
		for (strumline in strumlines)
			strumline.forEachNote(func, includeQueued);
	}
	public function getSelectedNotes() {
		var list:Array<CharterNote> = [];
		forEachNote((note:Note) -> {
			var charterNote:CharterNote = cast note;
			if (charterNote == null) return;
			
			if (charterNote.selected)
				list.push(charterNote);
		}, true);
		return list;
	}
	public function queueNote(note:Note) {
		var strumline:Strumline = (note.player ? strumlines.members[0] : strumlines.members[1]);
		strumline?.queueNote(note);
		return note;
	}
	public function shiftNotes(notesArray:Array<CharterNote>, beatMod:Float = 0):Float {
		if (beatMod == 0) return 0;
		var beatDiff:Float = beatMod;
		var minBeat:Float = Math.POSITIVE_INFINITY;
		var maxBeat:Float = Math.NEGATIVE_INFINITY;
		for (note in notesArray) {
			if (note.isHoldPiece) continue;
			if (note.beatTime < minBeat) minBeat = note.beatTime;
			if (note.beatTime > maxBeat) maxBeat = note.beatTime;
		}
		if (minBeat + beatDiff < 0)
			beatDiff = -minBeat;
		// todo max beat
		if (beatDiff != 0) {
			for (note in notesArray) {
				if (note.isHoldPiece) continue;
				shiftNote(note, note.beatTime + beatDiff);
			}
		}
		return beatDiff;
	}
	public function twistNotes(notesArray:Array<CharterNote>, laneMod:Int = 0):Int {
		if (laneMod == 0) return 0;
		var laneDiff:Int = laneMod;
		var minLane:Int = 9999; // prevent notes from going out of bounds
		var maxLane:Int = -1;
		for (note in notesArray) {
			var laneIdx:Int = laneToIndex(note.lane);
			if (laneIdx < minLane) minLane = laneIdx;
			if (laneIdx > maxLane) maxLane = laneIdx;
		}
		if (minLane + laneDiff < 0)
			laneDiff = -minLane;
		if (maxLane + laneDiff >= getNumLanes())
			laneDiff = getNumLanes() - maxLane - 1;
		
		if (laneDiff != 0) {
			for (note in notesArray) {
				if (note.isHoldPiece) continue;
				var laneIdx:Int = laneToIndex(note.lane);
				var nextLane:Lane = indexToLane(laneIdx + laneDiff);
				if (nextLane == null) continue;
				twistNote(note, nextLane);
			}
		}
		return laneDiff;
	}
	public function shiftNote(note:Note, beatTime:Float) {
		if (note == null) {
			Log.warning('shiftNote: ???');
			return;
		}
		var diff:Float = beatTime - note.beatTime;
		note.beatTime = beatTime;
		note.goodHit = (conductorInUse.songPosition > note.msTime + 1);
		for (child in note.children) {
			child.beatTime += diff;
			child.goodHit = (conductorInUse.songPosition > child.msTime + 1);
		}
	}
	public function twistNote(note:Note, lane:Lane) {
		if (note == null || lane == null) {
			Log.warning('twistNote: ???');
			return;
		}
		if (Std.isOfType(note, CharterNote)) {
			var charterNote:CharterNote = cast note;
			if (charterNote == null) return;
			
			if (charterNote.useLaneRGB)
				note.shader = lane.rgbShader.shader;
		}
		note.player = (lane.strumline == strumlines.members[0]);
		note.noteData = lane.noteData;
		note.reloadAnimations();
		if (note.lane.notes.members.contains(note)) {
			note.lane.notes.remove(note, true);
			lane.insertNote(note);
		} else {
			note.lane.dequeueNote(note);
			lane.queueNote(note, true);
		}
		note.lane = lane;
		
		for (child in note.children)
			twistNote(child, lane);
	}
	public function indexToLane(index:Int) {
		var n:Int = -1;
		for (strumline in strumlines) {
			for (lane in strumline.lanes) {
				n ++;
				if (n == index)
					return lane;
			}
		}
		return null;
	}
	public function laneToIndex(laneToFind:Lane) {
		var n:Int = -1;
		for (strumline in strumlines) {
			for (lane in strumline.lanes) {
				n ++;
				if (lane == laneToFind)
					return n;
			}
		}
		return -1;
	}
	public function getNumLanes() {
		var count:Int = 0;
		for (strumline in strumlines)
			count += strumline.lanes.length;
		return count;
	}
	
	public function set_scrollSpeed(newSpeed:Float) {
		scrollSpeed = newSpeed;
		for (strumline in strumlines) {
			strumline.scrollSpeed = visualScrollSpeed;
			/*for (lane in strumline.lanes)
				lane.spawnRadius *= 1.5;*/
		}
		return newSpeed;
	}
	public function get_visualScrollSpeed() {
		return scrollSpeed / .7;
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
		
		var noteControlMode:Bool = FlxG.keys.pressed.CONTROL;
		var scrollMod:Int = 1;
		var leniency:Float = 1 / 256;
		var prevBeat:Float = conductorInUse.metronome.beat;
		var quantMultiplier:Float = (quant * .25);
		var pauseSong:Bool = false;
		if (noteControlMode) {
			keyPressNoteControl(key);
		}
		switch (key) {
			case FlxKey.DELETE:
				var deletedNotes:Array<CharterNote> = [];
				for (note in getSelectedNotes()) {
					note.lane.dequeueNote(note);
					note.lane.killNote(note);
					deletedNotes.push(note);
				}
				if (deletedNotes.length > 0)
					addUndo({type: REMOVED_NOTES, notes: deletedNotes});
			case FlxKey.LEFT | FlxKey.RIGHT:
				if (key == FlxKey.LEFT) scrollMod *= -1;
				if (noteControlMode) {
					twistNotes(getSelectedNotes(), scrollMod);
				} else {
					changeQuant(scrollMod);
				}
			case FlxKey.UP | FlxKey.DOWN:
				if (key == FlxKey.UP) scrollMod *= -1;
				if (noteControlMode) {
					shiftNotes(getSelectedNotes(), scrollMod / quantMultiplier);
				} else {
					placeNotes();
					pauseSong = true;
					var targetBeat:Float = prevBeat + scrollMod / quantMultiplier;
					if (Math.abs(prevBeat - Math.round(prevBeat * quantMultiplier) / quantMultiplier) < leniency * 2)
						conductorInUse.metronome.setBeat(Math.round(targetBeat * quantMultiplier) / quantMultiplier);
					else
						conductorInUse.metronome.setBeat((scrollMod > 0 ? Math.floor : Math.ceil)(targetBeat * quantMultiplier) / quantMultiplier);
				}
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
	public function undo() {
		var undoAction:UndoAction = undoActions.pop();
		if (undoAction != null) {
			// Sys.println('undoing ${undoAction.type}');
			redoActions.unshift(undoAction);
			switch (undoAction.type) {
				case PLACED_NOTES:
					for (note in undoAction.notes) {
						note.lane.dequeueNote(note);
						note.lane.killNote(note);
					}
				case REMOVED_NOTES:
					for (note in undoAction.notes) {
						note.lane.queueNote(note);
						note.selected = true;
					}
				case SHIFTED_NOTES:
					twistNotes(undoAction.notes, -undoAction.laneMod);
					shiftNotes(undoAction.notes, -undoAction.beatMod);
				default:
			}
			charterDisplay.addMessage(undoAction.message(), true, false);
			recalculateNoteCount();
		}
	}
	public function redo() {
		var undoAction:UndoAction = redoActions.shift();
		if (undoAction != null) {
			// Sys.println('redoing ${undoAction.type}');
			undoActions.push(undoAction);
			switch (undoAction.type) {
				case PLACED_NOTES:
					for (note in undoAction.notes) {
						note.lane.queueNote(note);
						note.selected = true;
					}
				case REMOVED_NOTES:
					for (note in undoAction.notes) {
						note.lane.dequeueNote(note);
						note.lane.killNote(note);
					}
				case SHIFTED_NOTES:
					twistNotes(undoAction.notes, undoAction.laneMod);
					shiftNotes(undoAction.notes, undoAction.beatMod);
				default:
			}
			charterDisplay.addMessage(undoAction.message(), true, true);
			recalculateNoteCount();
		}
	}
	public function addUndo(action:UndoAction) {
		// Sys.println('added undo action ${action.type}');
		setWindowTitle(true);
		undoActions.push(action);
		
		while (undoActions.length > undoMemory) {
			var undoAction:UndoAction = undoActions.shift();
			destroyUndoAction(undoAction, false);
		}
		for (undoAction in redoActions)
			destroyUndoAction(undoAction, true);
		redoActions.resize(0);
		
		charterDisplay.addMessage(action.message(), false, true);
		recalculateNoteCount();
	}
	public function destroyUndoAction(action:UndoAction, parallel:Bool = false) {
		switch (action.type) { // parallel: for redo
			case PLACED_NOTES | REMOVED_NOTES:
				if (parallel == (action.type == REMOVED_NOTES))
					return;
				for (note in action.notes)
					note.destroy();
			default:
		}
	}
	public function recalculateNoteCount() {
		fullNoteCount = 0;
		hitNoteCount = 0;
		for (strumline in strumlines) {
			strumline.forEachNote((note:Note) -> {
				if (!note.isHoldPiece)
					hitNoteCount ++;
				fullNoteCount ++;
			}, true);
		}
	}
	public function copySelectedNotes() {
		var selectedNotes:Array<CharterNote> = getSelectedNotes();
		if (selectedNotes.length > 0) {
			copiedNotes.resize(0);
			for (note in selectedNotes) {
				if (note.isHoldPiece) continue;
				copiedNotes.push(note.toSongNote());
			}
			copiedNotes.sort(Song.sortByTime);
		}
	}
	public function keyPressNoteControl(key:FlxKey) {
		switch (key) {
			case FlxKey.Z:
				undo();
			case FlxKey.Y:
				redo();
			case FlxKey.C: // COPY
				copySelectedNotes();
			case FlxKey.V: // PASTE
				for (note in getSelectedNotes())
					note.selected = false;
				if (copiedNotes.length > 0) {
					var generatedNotes:Array<CharterNote> = [];
					for (note in Song.generateNotesFromArray(copiedNotes, true)) {
						var charterNote:CharterNote = cast note;
						if (charterNote == null) continue;
						
						generatedNotes.push(charterNote);
						charterNote.justCopied = true;
						charterNote.selected = true;
					}
					var quantMult:Float = quant / 4;
					var beatDiff:Float = (Math.round(conductorInUse.metronome.beat * quantMult) / quantMult - generatedNotes[0].beatTime);
					for (note in generatedNotes) {
						note.beatTime += beatDiff;
						queueNote(note);
					}
					addUndo({type: PLACED_NOTES, notes: generatedNotes, pasted: true});
				}
			case FlxKey.X: // CUT
				copySelectedNotes();
				var deletedNotes:Array<CharterNote> = [];
				for (note in getSelectedNotes()) {
					note.lane.dequeueNote(note);
					note.lane.killNote(note);
					deletedNotes.push(note);
				}
				if (deletedNotes.length > 0)
					addUndo({type: REMOVED_NOTES, notes: deletedNotes});
			case FlxKey.A: // SELECT ALL
				var selectedAny:Bool = false;
				forEachNote((note:Note) -> {
					var charterNote:CharterNote = cast note;
					if (charterNote == null) return;
					
					if (!charterNote.selected) {
						charterNote.selected = true;
						selectedAny = true;
					}
				}, true);
				
				if (!selectedAny) {
					forEachNote((note:Note) -> {
						var charterNote:CharterNote = cast note;
						if (charterNote == null) return;
						
						charterNote.selected = false;
					}, true);
				}
			default:
		}
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
		var quantMultiplier:Float = (quant / 4);
		var strumline:Strumline = strumlines.members[strumlineId];
		var lane = strumline.getLane(data);
		var matchingNote:Null<CharterNote> = null;
		for (note in lane.notes) {
			if (note.isHoldPiece) continue;
			if (Math.abs(note.beatTime - conductorInUse.metronome.beat) < 1 / quantMultiplier - .0012) {
				matchingNote = cast note;
				break;
			}
		}
		if (matchingNote == null) {
			hitsound.play(true);
			var isPlayer:Bool = (strumlineId == 0);
			var snappedBeat:Float = Math.round(conductorInUse.metronome.beat * quantMultiplier) / quantMultiplier;
			var note:CharterNote = new CharterNote(isPlayer, 0, data);
			heldNotes[keybind] = note;
			note.beatTime = snappedBeat;
			note.preventDespawn = true;
			note.justPlacing = true;
			lane.insertNote(note);
		} else {
			var deletedNotes:Array<CharterNote> = [matchingNote];
			for (child in matchingNote.children)
				deletedNotes.push(cast child);
			
			for (note in deletedNotes) {
				note.lane.dequeueNote(note);
				note.lane.killNote(note);
			}
			addUndo({type: REMOVED_NOTES, notes: deletedNotes});
		}
	}
	public function inputOff(keybind:Int) {
		heldKeybinds[keybind] = false;
		var note:CharterNote = heldNotes[keybind];
		if (note != null) {
			for (note in getSelectedNotes())
				note.selected = false;
			
			var addedNotes:Array<CharterNote> = [note];
			for (child in note.children)
				addedNotes.push(cast child);
			
			addUndo({type: PLACED_NOTES, notes: addedNotes});
			
			FunkinSound.playOnce(Paths.sound('hitsoundTail'), .7);
			note.justPlacing = false;
			note.preventDespawn = false;
			for (child in note.children) {
				var charterNote:CharterNote = cast child;
				if (charterNote == null) continue;
				
				charterNote.preventDespawn = false;
				charterNote.justPlacing = false;
			}
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
					var piece:CharterNote = new CharterNote(note.player, note.msTime, note.noteData, note.msLength, note.noteKind, true);
					piece.justPlacing = note.justPlacing;
					piece.preventDespawn = true;
					note.children.push(piece);
					piece.parent = note;
					var tail:CharterNote = new CharterNote(note.player, note.msTime, note.noteData, 0, note.noteKind, true);
					tail.justPlacing = note.justPlacing;
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
		song.sort();
		song.findSongLength();
	}
	public function setWindowTitle(mod:Bool = false) {
		var win:lime.ui.Window = FlxG.stage.window;
		win.title = song.name;
		if (mod)
			win.title += '*';
		if (song.difficulty != '')
			win.title += ' (' + song.difficulty.toLowerCase() + ')';
		
		win.title += ' | ' + Main.windowTitle;
	}
	
	override public function destroy() {
		instance = null;
		inEditor = false;
		FlxG.stage.window.title = Main.windowTitle;
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, keyPressEvent);
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_UP, keyReleaseEvent);
		FlxG.stage.removeEventListener(MouseEvent.MOUSE_MOVE, mouseMoveEvent);
		Main.instance.removeChild(charterDisplay);
		Main.watermark.visible = true;
		super.destroy();
	}
}

@:structInit class UndoAction {
	public var notes:Array<CharterNote>;
	public var type:UndoActionType;
	
	public var pasted:Bool = false;
	public var beatMod:Float = 0;
	public var laneMod:Int = 0;
	
	public function message() {
		var notesCount:Int = 0;
		var longMatch:Bool = true;
		var kindMatch:Bool = true;
		var length:Null<Float> = null;
		var kind:Null<String> = null;
		
		for (note in notes) {
			if (note.isHoldPiece)
				continue;
			
			notesCount ++;
			length ??= note.beatLength;
			if ((length > 0) != (note.beatLength > 0))
				longMatch = false;
			kind ??= note.noteKind;
			if (kind != note.noteKind)
				kindMatch = false;
		}
		
		var notesStr:String = (longMatch && length > 0 ? 'long note' : 'note');
		if (notesCount != 1) notesStr += 's';
		if (kindMatch && kind != '') notesStr += ' ($kind)';
		if (notesCount != 1) notesStr = '$notesCount $notesStr';
		
		return switch (type) {
			case PLACED_NOTES:
				'${pasted ? 'copied' : 'added'} $notesStr';
			case REMOVED_NOTES:
				'removed $notesStr';
			case SHIFTED_NOTES:
				'shifted $notesStr';
		}
	}
}
enum UndoActionType {
	PLACED_NOTES;
	REMOVED_NOTES;
	SHIFTED_NOTES;
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

class CharterPopUp extends Sprite {
	public var message(default, set):String;
	public var isUndo(default, set):Bool;
	public var isRedo(default, set):Bool;
	public var text:TextField;
	public var icon:Bitmap;
	
	public function new() {
		super();
		
		icon = new Bitmap();
		icon.smoothing = true;
		icon.scaleX = icon.scaleY = .65;
		icon.y = 3;
		
		var smallTf:TextFormat = new TextFormat('_sans', 12, -1);
		smallTf.letterSpacing = -1;
		text = new TextField();
		text.autoSize = LEFT;
		text.selectable = false;
		text.mouseEnabled = false;
		text.defaultTextFormat = smallTf;
		addChild(text);
	}
	public function set_isRedo(isIt:Bool) {
		icon.bitmapData = Paths.bmd('charter/' + (isIt ? 'redo' : 'undo'));
		return isRedo = isIt;
	}
	public function set_isUndo(isIt:Bool) {
		if (isIt && !contains(icon)) {
			addChild(icon);
		} else if (!isIt && contains(icon)) {
			removeChild(icon);
		}
		text.x = (isIt ? 13 : 0);
		return isUndo = isIt;
	}
	public function set_message(mes:String) {
		text.text = mes;
		return message = mes;
	}
}
class CharterDisplay extends Sprite {
	public var metronomeText:TextField;
	public var noteInfoText:TextField;
	public var songPosText:TextField;
	public var bpmInfoText:TextField;
	public var background:Bitmap;
	
	public var conductor:Conductor;
	public var songLength:Float = 0;
	
	public var popUps:Array<CharterPopUp> = [];
	// maybe put the pop ups in a container
	
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
		noteInfoText = new TextField();
		noteInfoText.defaultTextFormat = new TextFormat(Paths.ttf('vcr'), 11, -1);
		noteInfoText.defaultTextFormat.letterSpacing = -1;
		noteInfoText.alpha = .75;
		songPosText = new TextField();
		songPosText.defaultTextFormat = new TextFormat(Paths.ttf('vcr'), 12, -1);
		bpmInfoText = new TextField();
		bpmInfoText.defaultTextFormat = new TextFormat(Paths.ttf('vcr'), 18, -1);
		
		for (text in [metronomeText, songPosText, noteInfoText, bpmInfoText]) {
			text.x = 10;
			text.autoSize = LEFT;
			text.multiline = true;
			text.selectable = false;
			text.mouseEnabled = false;
			addChild(text);
		}
	}
	public function addMessage(message:String, isUndo:Bool = false, isRedo:Bool = false) {
		var i:Int = 0;
		var toUse:CharterPopUp = null;
		for (pop in popUps) {
			if (!contains(pop)) {
				toUse = pop;
				break;
			}
			i ++;
		}
		var maxHeight:Float = FlxG.stage.window.height - 96;
		if (getTextPos(0) >= maxHeight)
			toUse = popUps[0];
		else if (getTextPos(i) >= maxHeight)
			toUse = popUps[i - 1];
		
		if (toUse == null) {
			toUse = new CharterPopUp();
			popUps.push(toUse);
		}
		toUse.message = message;
		toUse.isUndo = isUndo;
		toUse.isRedo = isRedo;
		toUse.alpha = .75;
		toUse.x = 10;
		
		if (!contains(toUse))
			addChild(toUse);
		repositionTexts();
		FlxTween.cancelTweensOf(toUse);
		FlxTween.tween(toUse, {alpha: 0}, .5, {startDelay: .75, onComplete: (_) -> {
			if (contains(toUse))
				removeChild(toUse);
			popUps.push(popUps.shift());
			repositionTexts();
		}});
	}
	function getTextPos(i:Int)
		return 35 + i * 15;
	function repositionTexts() {
		for (i => pop in popUps) {
			if (!contains(pop)) continue;
			pop.y = getTextPos(i);
		}
	}
	public function updateMetronomeInfo() {
		var metronome:Metronome = conductor.metronome;
		var charter:CharterState = CharterState.instance;
		
		var bpmInfoTextT:String = '${metronome.bpm} bpm\n${metronome.timeSignature.toString()}';
		var songPosTextT:String = FlxStringUtil.formatTime(metronome.ms * .001, true) + ' / ' + FlxStringUtil.formatTime(songLength * .001, true);
		var metronomeTextT:String = 'Measure: ${Math.floor(metronome.bar)}\nBeat: ${Math.floor(metronome.beat)}\nStep: ${Math.floor(metronome.step)}';
		var noteInfoTextT:String = '${charter.hitNoteCount} notes (${charter.fullNoteCount} obj)';
		
		if (metronomeText.text != metronomeTextT) metronomeText.text = metronomeTextT;
		if (noteInfoText.text != noteInfoTextT) noteInfoText.text = noteInfoTextT;
		if (songPosText.text != songPosTextT) songPosText.text = songPosTextT;
		if (bpmInfoText.text != bpmInfoTextT) bpmInfoText.text = bpmInfoTextT;
	}
	
	override function __enterFrame(deltaTime:Float) {
		updateMetronomeInfo();
		
		noteInfoText.x = FlxG.stage.window.width - 12 - noteInfoText.textWidth;
		
		var h:Float = FlxG.stage.window.height;
		songPosText.y = h - songPosText.textHeight - 12;
		noteInfoText.y = h - noteInfoText.textHeight - 12;
		metronomeText.y = h - metronomeText.textHeight - 32;
		var infoHeight:Float = songPosText.textHeight + metronomeText.textHeight + 32;
		
		bpmInfoText.y = h - infoHeight - bpmInfoText.textHeight;
		background.scaleX = Math.max(Math.max(songPosText.textWidth, metronomeText.textWidth) + 24, 120);
		background.scaleY = infoHeight + bpmInfoText.textHeight + 10;
		background.y = h - background.scaleY;
	}
}

class CharterStrumline extends Strumline {
	public var receptorAlpha:Float = 1;
	public var noteHighlight:FlxSprite;
	
	public function new(laneCount:Int = 4, direction:Float = 90, scrollSpeed:Float = 1) {
		super(laneCount, direction, scrollSpeed);
		noteHighlight = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
		noteHighlight.blend = ADD;
	}
	
	public override function draw() {
		for (lane in lanes) { // draw hit notes on bottom
			if (!lane.selfDraw) {
				if (lane.receptor != null)
					lane.receptor.alpha = receptorAlpha;
				for (note in lane.notes) {
					var charterNote:CharterNote = cast note;
					if (charterNote == null) continue;
					
					charterNote.drawCustom(true);
					if (charterNote.wasGoodHit())
						drawHighlight(charterNote);
				}
			}
		}
		super.draw();
		for (lane in lanes) { // draw on top
			if (!lane.selfDraw) {
				if (lane.receptor != null)
					lane.receptor.alpha = 1;
				for (note in lane.notes) {
					var charterNote:CharterNote = cast note;
					if (charterNote == null) {
						note.draw();
						continue;
					}
					
					charterNote.drawCustom(false);
					if (!charterNote.wasGoodHit())
						drawHighlight(charterNote);
				}
				lane.drawTop();
			}
		}
	}
	public function drawHighlight(note:CharterNote) {
		if (note.selected && !note.isHoldPiece) {
			Util.copyColorTransform(noteHighlight.colorTransform, note.colorTransform);
			noteHighlight.setGraphicSize(note.width, note.height);
			noteHighlight.colorTransform.alphaMultiplier = .25;
			noteHighlight.setPosition(note.x, note.y);
			noteHighlight.updateHitbox();
			noteHighlight.draw();
		}
	}
}
class CharterNote extends Note {
	public var highlighted(default, set):Bool = false;
	public var hitAlphaMult:Float = .7;
	public var selected(default, set):Bool = false;
	public var justPlacing:Bool = false;
	public var justCopied:Bool = false;
	public var useLaneRGB:Bool = true;
	
	var pointer:FlxObject;
	var noteKindDecal:FunkinSprite = null;
	
	public function new(player:Bool, msTime:Float, noteData:Int, msLength:Float = 0, type:String = '', isHoldPiece:Bool = false, ?conductor:Conductor) {
		super(player, msTime, noteData, msLength, type, isHoldPiece, conductor);
		pointer = new FlxObject();
	}
	public function set_highlighted(isHighlighted:Bool) {
		if (highlighted == isHighlighted) return isHighlighted;
		for (child in children)
			cast(child, CharterNote).highlighted = isHighlighted;
		highlighted = isHighlighted;
		updateHighlight();
		return isHighlighted;
	}
	public function set_selected(isSelected:Bool) {
		if (selected == isSelected) return isSelected;
		if (!isSelected) justCopied = false;
		for (child in children) {
			var charterNote:CharterNote = cast child;
			charterNote.justCopied = justCopied;
			charterNote.selected = isSelected;
		}
		selected = isSelected;
		updateHighlight();
		return isSelected;
	}
	public function updateHighlight() {
		if (selected) {
			if (justCopied) {
				setColorTransform(0, 1, 1);
			} else {
				setColorTransform(0, 1, 0);
			}
		} else if (highlighted) {
			setColorTransform(1.6, 1.6, 1.6, 1, 32, 32, 32);
		} else {
			setColorTransform();
		}
	}
	public override function set_noteKind(newKind:String) {
		if (noteKind == newKind) return newKind;
		if (newKind == '') {
			if (lane != null) shader = lane.rgbShader.shader;
			noteKindDecal.destroy();
			noteKindDecal = null;
			useLaneRGB = true;
		} else {
			shader = CharterState.genericRGB.shader;
			useLaneRGB = false;
			noteKindDecal ??= new FunkinSprite();
			noteKindDecal.loadTexture('charter/noteKinds/$newKind');
			if (noteKindDecal.graphic == null) noteKindDecal.loadTexture('charter/noteKinds/generic');
		}
		return noteKind = newKind;
	}
	public function wasGoodHit()
		return (goodHit || (parent != null && parent.goodHit));
	public function drawCustom(good:Bool = false) {
		var wasGood:Bool = wasGoodHit();
		if (wasGood != good) return;
		
		var prevAlpha:Float = alpha;
		if (wasGood) alpha *= hitAlphaMult;
		if (justPlacing) alpha *= .75;
		actuallyDraw();
		alpha = prevAlpha;
	}
	public function actuallyDraw() {
		super.draw();
		if (!isHoldPiece && noteKindDecal != null) {
			Util.copyColorTransform(noteKindDecal.colorTransform, this.colorTransform);
			noteKindDecal.scale.set(scale.x, scale.y);
			noteKindDecal.updateHitbox();
			noteKindDecal.setPosition(x + (width - noteKindDecal.width) * .5, y + (height - noteKindDecal.height) * .5);
			noteKindDecal.camera = camera;
			noteKindDecal.draw();
		}
		pointer.x = x;
		pointer.y = y;
		if (!isHoldPiece && noteKind != '' && highlighted && CharterState.inEditor && !FlxG.mouse.pressed) {
			pointer.x += width * .7;
			pointer.y += height * .3;
			var charter:CharterState = CharterState.instance;
			var bubblePos:FlxPoint = getPointerScreenPosition(pointer);
			charter.noteKindBubble.setPosition(
				bubblePos.x,
				bubblePos.y - charter.noteKindBubble.height
			);
			charter.noteKindBubble.draw();
			
			charter.noteKindBubbleText.text = noteKind;
			charter.noteKindBubbleText.setPosition(
				charter.noteKindBubble.x + 46,
				charter.noteKindBubble.y + 20
			);
			charter.noteKindBubbleText.draw();
			
			if (noteKindDecal != null) {
				noteKindDecal.camera = charter.camHUD;
				noteKindDecal.setColorTransform();
				noteKindDecal.scale.set(.35, .35);
				noteKindDecal.updateHitbox();
				noteKindDecal.alpha = .75;
				noteKindDecal.setPosition(
					charter.noteKindBubble.x - noteKindDecal.width * .5 + 25,
					charter.noteKindBubble.y - noteKindDecal.height * .5 + 32,
				);
				noteKindDecal.draw();
			}
		}
	}
	public override function draw() {}
	public function getPointerScreenPosition(pointer:FlxObject, ?camera:FlxCamera):FlxPoint {
		camera ??= pointer.camera ?? FlxG.camera;
		
		var point:FlxPoint = pointer.getScreenPosition(camera);
		point.subtract(camera.viewMarginLeft, camera.viewMarginTop);
		point.scale(camera.zoom);
		return point;
	}
}