package funkin.objects.play;

import haxe.Constraints;
import funkin.shaders.RGBSwap;
import funkin.objects.Character;
import funkin.objects.play.Note;
import funkin.backend.play.Scoring;
import funkin.backend.play.NoteEvent;
import funkin.backend.play.NoteStyle;
import funkin.backend.rhythm.Conductor;

import flixel.input.keyboard.FlxKey;
import flixel.util.FlxSignal.FlxTypedSignal;
import flixel.graphics.frames.FlxFramesCollection;

using Lambda;
using StringTools;
using funkin.backend.play.NoteStyle.NoteStyleUtil;

class Lane extends FunkinSpriteGroup {
	public var rgbShader:RGBSwap;
	public var splashRGB:RGBSwap;
	
	public var startX:Float;
	public var startY:Float;
	
	public var held:Bool = false;
	public var heldNote:Note = null;
	public var pressed:Bool = false;
	
	public var noteData:Int;
	public var oneWay:Bool = true;
	public var noteClass:Class<Note> = Note;
	public var style(default, set):NoteStyle;
	public var scrollSpeed(default, set):Float = 1;
	public var direction:Float = 90;
	public var spawnRadius:Float;
	public var hitWindow:Float = Scoring.safeFrames / 60 * 1000;
	public var conductorInUse:Conductor = FunkinState.getCurrentConductor();
	public var inputKeys:Array<FlxKey> = [];
	public var character:ICharacter = null;
	public var strumline:Strumline;
	
	public var cpu(default, set):Bool = false;
	public var allowInput:Bool = true;
	public var inputFilter:Note -> Bool;
	public var noteEvent:FlxTypedSignal<NoteEvent -> Void> = new FlxTypedSignal();
	public var extraWindow:Float = 0; // antimash mechanic
	var queueComputeLimit:Int = 500;
	var spawnLimit:Int = 75;
	
	public var receptor:Receptor;
	public var arrowPath:ArrowPath;
	public var notes:FunkinTypedSpriteGroup<Note>;
	public var wooshNotes:FunkinTypedSpriteGroup<Note>;
	public var noteSparks:FunkinTypedSpriteGroup<NoteSpark>;
	public var noteSplashes:FunkinTypedSpriteGroup<NoteSplash>;
	public var queue:Array<ChartNote> = [];
	
	public var canSplash:Bool = true;
	public var canSpark:Bool = true;

	public var selfDraw:Bool = false;
	public var topMembers:Array<FlxSprite> = [];
	
	public var songPosition(get, never):Float;
	
	function set_scrollSpeed(newSpeed:Float) {
		return scrollSpeed = newSpeed;
	}
	function set_cpu(isCpu:Bool) {
		if (cpu == isCpu) return isCpu;
		if (receptor != null)
			receptor.autoReset = isCpu;
		return cpu = isCpu;
	}
	inline function get_songPosition():Float {
		return conductorInUse.songPosition;
	}
	public function new(x:Float, y:Float, data:Int, dir:Float = 90, speed:Float = 1, ?style:NoteStyleAsset = 'funkin') {
		super(x, y);
		
		rgbShader = new RGBSwap();
		splashRGB = new RGBSwap();
		
		startX = x;
		startY = y;
		noteData = data;
		direction = dir;
		scrollSpeed = speed;
		this.style = NoteStyle.fetch(style);
		
		inputFilter = (note:Note) -> {
			var time:Float = note.msTime - conductorInUse.songPosition;
			return (time <= note.hitWindow + extraWindow) && (time >= -note.hitWindow);
		};
		
		receptor = new Receptor(0, 0, data, style);
		arrowPath = new ArrowPath(this);
		arrowPath.render = false;
		notes = new FunkinTypedSpriteGroup();
		wooshNotes = new FunkinTypedSpriteGroup();
		noteSparks = new FunkinTypedSpriteGroup(0, 0, 5);
		noteSplashes = new FunkinTypedSpriteGroup(0, 0, 5);
		spawnRadius = Note.distanceToMS(FlxG.height + 75, scrollSpeed);
		receptor.lane = this; //lol
		
		this.add(arrowPath);
		this.add(receptor);
		for (mem in [wooshNotes, notes, noteSparks, noteSplashes]) {
			topMembers.push(mem); // render conditionally
			this.add(mem);
		}
		
		spark().alpha = .0001;
		splash().alpha = .0001;
		
		updateLaneScale(scale);
	}
	override function initVars():Void {
		super.initVars();
		scale.destroy();
		scale = new flixel.math.FlxPoint.FlxCallbackPoint(updateLaneScale);
		scale.set(1, 1);
	}
	function updateLaneScale(point:FlxPoint) {
		if (receptor != null) {
			var mult:Float = receptor.defaultScale;
			receptor.scale.set(point.x * mult, point.y * mult);
			receptor.updateHitbox();
		}
	}
	
	public function woosh():Void {
		for (note in wooshNotes) {
			var startX:Float = note.x;
			var startY:Float = note.y;
			
			FlxTween.tween(note, {x: note.x + FlxG.height * Math.cos(direction / 180 * Math.PI), y: note.y + FlxG.height * Math.sin(direction / 180 * Math.PI)}, .5, {
				ease: FlxEase.expoIn,
				onComplete: (_) -> {
					note.kill();
					wooshNotes.remove(note, true);
					note.destroy();
				},
				onUpdate: (_) -> {
					if (note.tail != null) {
						@:privateAccess note.tail.holdStrip?.setPosition(note.x - startX, note.y - startY);
						@:privateAccess note.tail.tailStrip?.setPosition(note.x - startX, note.y - startY);
					}
				}
			});
		}
	}
	public override function update(elapsed:Float) {
		updateQueue();
		updateNotes();

		super.update(elapsed);
		extraWindow = Math.max(extraWindow - elapsed * 200, 0);
	}
	public function updateQueue() {
		var i:Int = 0;
		var early:Bool;
		var limit:Int = queueComputeLimit;
		
		while (i < queue.length) {
			var note:ChartNote = queue[i];
			if (note == null) {
				Log.warning('note was null in lane $noteData!!');
				queue.remove(note);
				continue;
			}
			
			early = (note.msTime - conductorInUse.songPosition > Math.max(spawnRadius, hitWindow));
			if (!early && (oneWay || (note.msTime + note.msLength - conductorInUse.songPosition) >= -spawnRadius)) {
				queue.remove(note);
				insertNote(note);
				if (notes.countLiving() >= spawnLimit || --limit < 0) break;
			} else {
				i ++;
			}
			
			if (early && oneWay)
				break;
		}
	}
	public function updateNotes() {
		var i:Int = notes.length;
		while (i > 0) {
			var note:Note = notes.members[-- i];
			if (note == null || !note.alive) continue;
			updateNote(note);
		}
	}
	public override function draw() {
		drawThing(selfDraw ? null : false);
	}
	function drawThing(?top:Bool):Void {
		@:privateAccess {
			final oldDefaultCameras = FlxCamera._defaultCameras;
			if (_cameras != null) FlxCamera._defaultCameras = _cameras;

			for (member in members) {
				if (top != null && topMembers.contains(member) != top)
					continue;
				if (member != null && member.exists && member.visible)
					member.draw();
			}

			FlxCamera._defaultCameras = oldDefaultCameras;
		}
	}
	public function forEachNote(func:ChartNote -> Void, includeQueued:Bool = false) {
		if (includeQueued) {
			for (note in queue)
				func(note);
		}
		for (note in notes) {
			if (note.alive && note.chartNote != null)
				func(note.chartNote);
		}
	}
	public function forEachActiveNote(func:Note -> Void) {
		for (note in notes) {
			if (note.alive)
				func(note);
		}
	}
	
	public function fireInput(key:FlxKey, pressed:Bool):Bool {
		if (!inputKeys.contains(key) || !allowInput) return false;
		if (pressed) {
			_noteEvent(basicEvent(PRESSED, getHighestNote(inputFilter)));
		} else {
			var note:Note = heldNote;
			_noteEvent(basicEvent(RELEASED, note));
			if (note != null)
				_noteEvent(basicEvent(RELEASED));
		}
		return true;
	}
	public function ghostTapped(?position:Float)
		_noteEvent(basicEvent(GHOST, null, position));
	public function basicEvent(type:NoteEventType, ?note:Note, ?position:Float):NoteEvent
		return {lane: this, strumline: strumline, receptor: receptor, note: note, type: type, songPosition: position ?? songPosition};
	function _noteEvent(event:NoteEvent) {
		strumline?.noteEvent.dispatch(event);
		noteEvent.dispatch(event);
	}
	public function getHighestNote(?filter:Note -> Bool, hittableOnly:Bool = true) {
		var highNote:Null<Note> = null;
		for (note in notes) {
			if (!note.alive) continue;
			
			var valid:Bool = (filter == null ? true : filter(note));
			
			if (!valid)
				continue;
			if (hittableOnly && (!note.canHit || note.goodHit))
				continue;
			if (highNote == null || note.hitPriority > highNote.hitPriority || (note.hitPriority == highNote.hitPriority && note.msTime < highNote.msTime))
				highNote = note;
		}
		return highNote;
	}
	public function getAllNotes() {
		var notes:Array<ChartNote> = [];
		
		for (note in this.queue)
			notes.push(note);
		for (note in this.notes) {
			if (note.alive && note.chartNote != null)
				notes.push(note.chartNote);
		}
		
		return notes;
	}
	public function resetLane() {
		clearNotes();
		receptor.playAnimation('static');
		removeCovers();
		heldNote = null;
		held = false;
	}
	
	public function splash(?note:Note):NoteSplash {
		var splash:NoteSplash = noteSplashes.recycle(NoteSplash, () -> new NoteSplash(noteData, style), true);
		
		preAdd(splash);
		noteSplashes.moveToTop(splash);
		splash.reload(note?.style ?? style);
		splash.popOnReceptor(receptor);
		splash.alpha = alpha * splash.defaultAlpha;
		splash.scale.set(scale.x * splash.defaultScale, scale.y * splash.defaultScale);
		
		return splash;
	}
	public function popCover(?note:Note):NoteSpark {
		var spark:NoteSpark = noteSparks.recycle(NoteSpark, () -> new NoteSpark(noteData, style), true);
		
		preAdd(spark);
		noteSparks.moveToTop(spark);
		spark.reload(note?.style ?? style);
		spark.heldNote = note;
		spark.popOnReceptor(receptor);
		spark.alpha = alpha * spark.defaultAlpha;
		spark.scale.set(scale.x * spark.defaultScale, scale.y * spark.defaultScale);
		
		return spark;
	}
	public function spark(?note:Note, animate:Bool = true):NoteSpark {
		var spark:NoteSpark = noteSparks.members.find((spark:NoteSpark) -> spark.heldNote == note);
		spark ??= popCover();
		if (animate) {
			spark.spark();
		} else {
			spark.kill();
		}
		return spark;
	}
	public function removeCovers():Void { // rename to removeSpakrs maybe :sob:
		for (spark in noteSparks) {
			if (spark.alive && !spark.sparking) {
				spark.heldNote = null;
				spark.kill();
			}
		}
	}
	
	public inline function queueNote(note:ChartNote, sorted:Bool = false, checkExists:Bool = true):ChartNote {
		var pushed:Bool = false;
		
		if (sorted) {
			for (i => otherNote in queue) {
				if (otherNote.msTime >= note.msTime) {
					if (!checkExists || !queue.contains(note))
						queue.insert(i, note);
					pushed = true;
					break;
				}
			}
		}
		if (!pushed && (!checkExists || !queue.contains(note)))
			queue.push(note);
		
		return note;
	}
	public function dequeueNote(note:ChartNote) {
		queue.remove(note);
	}
	public function clearNotes() {
		for (note in notes)
			note.kill();
		notes.clear();
		queue.resize(0);
	}
	public function updateNote(note:Note) {
		if (!note.ignore && (cpu || (held && note.goodHit)) && songPosition >= note.msTime && !note.lost && note.canHit) {
			var killingNote:Bool = false;
			
			if (!note.goodHit)
				_noteEvent(basicEvent(PRESSED, note, cpu ? note.msTime : songPosition));
			
			if (songPosition >= note.endMs)
				note.consumed = killingNote = true;
			
			_noteEvent(basicEvent(HELD, note));
			
			if (killingNote) {
				var releaseTime:Null<Float> = (cpu ? note.endMs : songPosition);
				
				_noteEvent(basicEvent(RELEASED, note, releaseTime));
				if (cpu) _noteEvent(basicEvent(RELEASED, null, releaseTime));
				
				killNote(note);
				return;
			}
		}
		
		note.followLane(this);
		
		var canDespawn:Bool = !note.preventDespawn;
		if (note.lost || note.goodHit) {
			if (canDespawn && (note.endMs - songPosition) < -spawnRadius)
				killNote(note, !oneWay);
		} else {
			if (songPosition - hitWindow > note.msTime) {
				note.lost = true;
				if (!note.ignore) _noteEvent(basicEvent(LOST, note));
			}
		}
		
		if (!oneWay && (note.msTime - songPosition) > spawnRadius)
			killNote(note, true);
	}
	public function findNoteByChartNote(songNote:ChartNote):Note {
		return notes.members.find((note:Note) -> note.chartNote == songNote);
	}
	public function generateNote(?cls:Class<Note>, songNote:ChartNote, pool:Bool = true):Note {
		if (pool) {
			return notes.recycle(noteClass, () -> generateNote(noteClass, songNote, false));
		} else {
			return Type.createInstance(cls ?? noteClass, [songNote, conductorInUse]);
		}
	}
	public function insertNote(songNote:ChartNote):Note {
		var note:Note = generateNote(noteClass, songNote);
		preAdd(note);
		if (note.tail?.alive)
			preAdd(note.tail);
		notes.moveToBottom(note);
		
		note.lane = this;
		note.chartNote = songNote;
		note.hitWindow = hitWindow;
		note.arrowPath = arrowPath;
		
		note.reload(style, this);
		note.scale.set(scale.x * note.defaultScale, scale.y * note.defaultScale);
		note.updateHitbox();
		
		_noteEvent(basicEvent(SPAWNED, note));
		updateNote(note);
		
		return note;
	}
	public dynamic function hitNote(note:Note, kill:Bool = true, ?position:Float) {
		note.goodHit = true;
		
		var event:NoteEvent = basicEvent(HIT, note, position);
		_noteEvent(event);
		
		if (kill && !note.isHoldNote && !event.cancelled)
			killNote(note);
	}
	public function killNote(note:Note, requeue:Bool = false, sort:Bool = true) {
		if (requeue)
			queueNote(note.chartNote, sort, false);
		
		note.kill();
		_noteEvent(basicEvent(DESPAWNED, note));
	}
	
	function set_style(newStyle:NoteStyle):NoteStyle {
		if (style == newStyle) return newStyle;
		style = newStyle;
		loadStyle(newStyle);
		return newStyle;
	}
	public function loadStyle(newStyle:NoteStyleAsset) {
		var style:NoteStyle = NoteStyle.fetch(newStyle);
		
		if (receptor != null)
			receptor.style = style;
		
		var colors:Array<FlxColor> = NoteStyle.getDirectionColors(style, noteData);
		rgbShader.set(colors[0], colors[1], colors[2]);
		
		var splashColors:Array<FlxColor> = NoteSplash.makeSplashColors(colors[0]);
		splashRGB.set(splashColors[0], FlxColor.WHITE, splashColors[1]);
		
		updateLaneScale(scale);
	}
	
	public function getDirection(?dir:Int):String {
		return NoteStyle.getDirectionName(style, dir ?? noteData);
	}
	public function getSingAnimation(?dir:Int):String {
		return NoteStyle.getDirectionSing(style, dir ?? noteData);
	}
	public function getColors(?dir:Int):Array<FlxColor> {
		return NoteStyle.getDirectionColors(style, dir ?? noteData);
	}
	
	override function findMinXHelper():Float { return receptor.x; }
	override function findMaxXHelper():Float { return receptor.x + receptor.width; }
	override function findMinYHelper():Float { return receptor.y; }
	override function findMaxYHelper():Float { return receptor.y + receptor.height; }
	
	override function set_zoomFactor(value:Float):Float {
		super.set_zoomFactor(value);
		for (sprite in topMembers) {
			if (sprite == null) continue;
			var funk:IFunkinSpriteVars = getFunk(sprite);
			if (funk != null) funk.zoomFactor = value;
		}
		return zoomFactor = value;
	}
	override function set_initialZoom(value:Float):Float {
		super.set_initialZoom(value);
		for (sprite in topMembers) {
			if (sprite == null) continue;
			var funk:IFunkinSpriteVars = getFunk(sprite);
			if (funk != null) funk.initialZoom = value;
		}
		return initialZoom = value;
	}
}

class Receptor extends FunkinSprite {
	public var lane:Lane;
	public var noteData:Int;
	
	public var rgbShader:RGBSwap;
	public var rgbEnabled(default, set):Bool;
	public var style(default, set):NoteStyle;
	
	public var grayBeat:Null<Float>;
	public var autoReset:Bool = false;
	public var defaultScale:Float = 1;
	
	public var updateRGBShader:Bool = true;
	
	public function new(x:Float, y:Float, data:Int, ?style:NoteStyleAsset = 'funkin') {
		super(x, y);
		loadAtlas('notes');
		rgbShader = new RGBSwap();
		
		this.noteData = data;
		this.style = NoteStyle.fetch(style);
		
		onAnimationComplete.add((anim:String) -> {
			if (!anim.startsWith('static') && autoReset && (lane == null || !lane.held))
				playAnimation('static', true);
		});
	}

	public override function update(elapsed:Float) {
		super.update(elapsed);
		if (grayBeat != null && lane.conductorInUse.metronome.beat >= grayBeat)
			playAnimation('press');
	}
	
	public override function playAnimation(anim:String, forced:Bool = false, reversed:Bool = false, frame:Int = 0) {
		var overrideAnim:String = '$anim-$noteData';
		if (animationExists(overrideAnim))
			anim = overrideAnim;
		
		if (updateRGBShader) {
			var animData:NoteStyleAnimData = style?.getAssetAnimation(style.data.receptors, anim);
			if (animData != null) {
				if (animData.disableRGB) {
					rgbEnabled = false;
				} else {
					var colors:Array<FlxColor> = style.getDirectionColorMod(noteData, animData.colorMod);
					rgbShader.set(colors[0], colors[1], colors[2]);
					rgbEnabled = true;
				}
			}
		}
		if (anim != 'confirm')
			grayBeat = null;
		
		super.playAnimation(anim, forced, reversed, frame);
		centerOffsets();
		centerOrigin();
	}
	
	function set_style(newStyle:NoteStyle) {
		if (style == newStyle) return newStyle;
		style = newStyle;
		loadStyle(newStyle);
		return newStyle;
	}
	public function loadStyle(newStyle:NoteStyleAsset) {
		var style:NoteStyle = NoteStyle.fetch(newStyle);
		
		NoteStyleUtil.loadNoteStyleAnimations(this, style?.data?.receptors, style?.getDirectionName(noteData));
		updateRGBShader = !(style?.data.general.disableRGB ?? false);
		defaultScale = style?.data?.receptors?.scale ?? 1;
		playAnimation('static', true);
		updateHitbox();
	}
	
	public function set_rgbEnabled(newE:Bool) {
		shader = (newE ? rgbShader.shader : null);
		return rgbEnabled = newE;
	}
	
	public static function makeGrayColor(col:FlxColor) {
		var pCol:FlxColor = col;
		col.red = Std.int(FlxMath.bound(col.red - 40 - (col.blue - col.red) * .1 + Math.abs(col.red - col.blue) * .1 + Math.min(col.red - Math.pow(col.blue / 255, 2) * 255 * 3 + col.green * .4, 0) * .1, 0, 255));
		col.green = Std.int(FlxMath.bound(col.green + (col.red + col.blue) * .15 + (col.green - col.blue) * .3, 0, 255));
		col.blue = Std.int(FlxMath.bound(col.blue + (col.green - col.blue) * .04 + (col.red + col.blue) * .25 + Math.abs(col.red - (col.green - col.blue)) * .2 - (col.red - col.blue) * .3, 0, 255));

		col.saturation = FlxMath.bound(col.saturation + (pCol.blueFloat + pCol.greenFloat - (pCol.blueFloat - pCol.redFloat)) * .05 - (1 - pCol.brightness) * .1, 0, 1) * .52;
		col.brightness = FlxMath.bound(col.brightness - ((pCol.blueFloat + pCol.greenFloat - (pCol.blueFloat - pCol.redFloat)) * .04) + (1 - pCol.brightness) * .08, 0, 1) * .75;
		
		return col;
	}
}

class NoteSplash extends FunkinSprite {
	public var lane:Lane;
	public var noteData:Int;
	
	public var rgbShader:RGBSwap;
	public var updateRGBShader:Bool = true;
	public var rgbEnabled(default, set):Bool;
	public var style(default, set):NoteStyle;
	
	public var defaultScale:Float = 1;
	public var defaultAlpha:Float = 1;
	public var animationVariants:Int = 1;
	public var frameRateRange:Array<Int>;
	
	var asset:NoteStyleAssetData = null;

	public function new(data:Int, ?style:NoteStyleAsset = 'funkin') {
		super();
		
		rgbShader = new RGBSwap();
		shader = rgbShader.shader;
		
		this.noteData = data;
		this.style = NoteStyle.fetch(style);
		
		initAnimation();
	}
	function initAnimation():Void {
		onAnimationComplete.add((anim:String) -> kill());
	}
	
	function set_style(newStyle:NoteStyle) {
		if (style == newStyle) return newStyle;
		style = newStyle;
		loadStyle(newStyle);
		return newStyle;
	}
	public function loadStyle(newStyle:NoteStyleAsset) {
		var style:NoteStyle = NoteStyle.fetch(newStyle);
		
		updateRGBShader = !(style?.data.general.disableRGB ?? false);
		asset = style?.data.noteSplashes;
		
		NoteStyleUtil.loadNoteStyleAnimations(this, asset, style?.getDirectionName(noteData));
		animationVariants = asset?.variants ?? 1;
		playAnimation('splash-1', true);
		updateHitbox();
		
		defaultScale = asset?.scale ?? 1;
		defaultAlpha = asset?.alpha ?? 1;
	}
	public function reload(style:NoteStyle) {
		blend = NORMAL;
		
		this.style = style;
	}
	
	public function popOnReceptor(receptor:Receptor) { //lol
		setPosition(receptor.x + receptor.width * .5, receptor.y + receptor.height * .5);
		pop();
	}
	public function pop():NoteSplash {
		var splashAnim:String = 'splash-${FlxG.random.int(1, animationVariants)}';
		
		var range:Array<Int> = frameRateRange;
		if (range == null) {
			var animation:NoteStyleAnimData = style?.getAssetAnimation(asset, splashAnim);
			if (animation != null) {
				if (animation.frameRateRange != null)
					range = animation.frameRateRange;
			}
		}
		
		playAnimation(splashAnim, true);
		updateHitbox();
		offset.set(frameWidth * .5, frameHeight * .5);
		
		if (anim.curAnim == null) {
			kill();
		} else if (range != null) {
			anim.curAnim.frameRate = FlxG.random.int(range[0], range[1]);
		}
		
		return this;
	}
	public override function playAnimation(anim:String, forced:Bool = false, reversed:Bool = false, frame:Int = 0) {
		var overrideAnim:String = '$anim-$noteData';
		if (animationExists(overrideAnim))
			anim = overrideAnim;
		
		if (updateRGBShader) {
			var animData:NoteStyleAnimData = style?.getAssetAnimation(asset, anim);
			if (animData != null) {
				if (animData.disableRGB) {
					rgbEnabled = false;
				} else {
					var colors:Array<FlxColor> = style.getDirectionColorMod(noteData, animData.colorMod);
					rgbShader.set(colors[0], colors[1], colors[2]);
					rgbEnabled = true;
				}
			}
		}
		
		super.playAnimation(anim, forced, reversed, frame);
	}
	
	public function set_rgbEnabled(newE:Bool) {
		shader = (newE ? rgbShader.shader : null);
		return rgbEnabled = newE;
	}

	public static function makeSplashColors(baseFill:FlxColor):Array<FlxColor> {
		var fill:FlxColor = baseFill;
		var f = 6.77; // literally just contrast
		var m = Math.pow(1 - (fill.saturation * fill.brightness), 2);
		fill.red = Std.int(FlxMath.lerp(FlxMath.bound(f * (fill.red - 128) + 128, 0, 255), fill.red, m));
		fill.green = Std.int(FlxMath.lerp(FlxMath.bound(f * (fill.green - 128) + 128, 0, 255), fill.green, m));
		fill.blue = Std.int(FlxMath.lerp(FlxMath.bound(f * (fill.blue - 128) + 128, 0, 255), fill.blue, m));
		fill.saturation = fill.saturation * Math.min(fill.brightness / .25, 1);
		fill.brightness = fill.brightness * .5 + .5;
		
		var ring:FlxColor = baseFill;
		ring.red = Std.int(ring.red * .9);
		ring.green = Std.int(ring.green * Math.max(.95 - ring.blue / 255 * .3 - ring.red / 255 * .3, 0));
		ring.blue = Std.int(Math.min((ring.blue * 2 + 80 - ring.red * .3) * ring.brightness, 255));
		ring.saturation = Math.min(ring.saturation * 1.2 * Math.min(ring.brightness / .125, 1), 1);
		ring.brightness = ring.brightness * .875 + .125;

		return [fill, ring];
	}
}

class NoteSpark extends NoteSplash {
	public var heldNote:Note = null;
	public var sparking:Bool = false;
	
	public function new(data:Int, ?style:NoteStyleAsset) {
		super(data, style);
	}
	override function initAnimation():Void {
		onAnimationComplete.add((anim:String) -> {
			if (anim.startsWith('start'))
				playAnimation('loop', true);
			if (anim.startsWith('spark'))
				kill();
		});
	}
	
	public override function loadStyle(newStyle:NoteStyleAsset) {
		var oldAnim:String = currentAnimation;
		var oldFrame:Float = anim.curFrameFloat;
		var style:NoteStyle = NoteStyle.fetch(newStyle);
		
		updateRGBShader = !(style?.data.general.disableRGB ?? false);
		asset = style?.data.noteCovers;
		
		NoteStyleUtil.loadNoteStyleAnimations(this, asset, style?.getDirectionName(noteData));
		defaultScale = asset?.scale ?? 1;
		defaultAlpha = asset?.alpha ?? 1;
		playAnimation('start', true);
		updateHitbox();
		
		offset.set(frameWidth * .5, frameHeight * .5);
		if (animationExists(oldAnim)) {
			playAnimation(oldAnim, true);
			anim.curFrameFloat = oldFrame;
		}
	}
	
	public override function pop():NoteSpark {
		playAnimation('start', true);
		sparking = false;
		revive();
		return this;
	}
	public function spark():NoteSpark {
		playAnimation('spark', true);
		sparking = true;
		heldNote = null;
		return this;
	}
	public override function kill():Void {
		super.kill();
		heldNote = null;
		sparking = false;
	}
}