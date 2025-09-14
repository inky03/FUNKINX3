package funkin.states;

import openfl.display.Sprite;
import openfl.display.Bitmap;
import openfl.text.TextField;
import openfl.text.TextFormat;
import flixel.util.FlxStringUtil;
import flixel.addons.display.FlxBackdrop;

import funkin.backend.play.Chart;
import funkin.backend.play.NoteStyle;
import funkin.objects.play.Strumline;
import funkin.objects.Character;

class CharterState extends FunkinState {
	public static var instance:CharterState;
	public static var chart:Chart;
	
	public var strumlineGroup:FunkinTypedSpriteGroup<Strumline>;
	
	public var charterDisplay:CharterDisplay;
	
	public var songPaused(default, set):Bool;
	public var noteCount:Int = 0;
	
	public var music:FunkinSoundGroup;
	var vocalsSounds:Array<FunkinSound> = [];
	
	public function new(?targetChart:Chart) {
		super();
		Mods.currentMod ??= '';
		
		chart = targetChart ?? chart ?? Chart.loadChart('test');
	}
	override public function create() {
		super.create();
		
		instance = this;
		conductorInUse = new Conductor();
		conductorInUse.tempoChanges = chart.tempoChanges;
		
		charterDisplay = new CharterDisplay(conductorInUse);
		Main.instance.addChild(charterDisplay);
		
		var background:FlxBackdrop = new FlxBackdrop(Paths.image('charter/bg'));
		background.antialiasing = Options.data.antialiasing;
		background.scale.set(.85, .85);
		background.velocity.set(5, 5);
		add(background);
	
		var chartStyle:String = chart.noteStyle;
		var mania:String = '${chart.keyCount}k';
		var noteStyle:String = chartStyle;
		if (NoteStyle.exists('$chartStyle-$mania'))
			noteStyle = '$chartStyle-$mania';
		
		music = new FunkinSoundGroup();
		strumlineGroup = new FunkinTypedSpriteGroup();
		
		var strumlineX:Float = 0;
		for (i in 0 ... chart.getStrumlineCount()) {
			var strumline:Strumline = new Strumline(chart.keyCount, 90, chart.scrollSpeed, noteStyle);
			strumline.x = strumlineX;
			strumline.allowInput = strumline.cpu = false;
			strumline.fitToSize(0, strumline.height * .7);
			
			strumlineX += strumline.width + 150 * strumline.scale.x;
			
			strumlineGroup.add(strumline);
		}
		strumlineGroup.screenCenter();
		add(strumlineGroup);
		
		chart.instLoaded = false;
		chart.loadMusic('data/songs/${chart.path}/', false);
		if (chart.instLoaded) {
			music.add(chart.inst);
			music.syncBase = chart.inst;
			music.onSoundFinished.add((snd:FunkinSound) -> {
				if (snd == music.syncBase)
					finishSong();
			});
			conductorInUse.syncTracker = chart.inst;
		}
		loadVocals(chart.path, chart.audioSuffix);
		songPaused = true;
	}
	public function finishSong():Void {
		conductorInUse.songPosition = music.length;
		songPaused = true;
	}
	public function loadVocals(path:String, audioSuffix:String = ''):Void {
		vocalsSounds.resize(0);
		
		for (chara in [chart.player1, chart.player2, chart.player3]) {
			var sound:openfl.media.Sound = Character.getVocals(chart.path, chart.audioSuffix, chara);
			if (sound != null)
				vocalsSounds.push(FunkinSound.load(sound));
		}
		if (vocalsSounds.length == 0) {
			var sound:openfl.media.Sound = Character.getVocals(chart.path, chart.audioSuffix, '');
			if (sound != null) {
				vocalsSounds.push(FunkinSound.load(sound));
			} else {
				Log.warning('song vocals not found...');
			}
		}
		for (sound in vocalsSounds) {
			sound.volume = 0;
			sound.play().stop();
			sound.volume = 1;
			music.add(sound);
		}
	}
	function set_songPaused(isPaused:Bool):Bool {
		if (isPaused) {
			music.stop();
		} else {
			if (conductorInUse.songPosition >= (music.syncBase?.length ?? 0))
				return songPaused = true;
			music.play(true, conductorInUse.songPosition);
		}
		
		for (strumline in strumlineGroup) {
			FlxTween.cancelTweensOf(strumline, ['alpha']);
			FlxTween.tween(strumline, {alpha: (isPaused ? .75 : 1)}, .25, {ease: FlxEase.circOut});
			for (lane in strumline.lanes) {
				if (isPaused)
					lane.receptor?.playAnimation('static');
			}
		}
		conductorInUse.paused = isPaused;
		return songPaused = isPaused;
	}
	
	override public function update(elapsed:Float) {
		if (FlxG.keys.justPressed.ESCAPE) {
			FlxG.switchState(() -> new PlayState(chart));
			return;
		}
		
		if (FlxG.keys.justPressed.SPACE) {
			songPaused = !songPaused;
		}
		
		super.update(elapsed);
	}
	
	override public function destroy() {
		Main.instance.removeChild(charterDisplay);
		super.destroy();
		instance = null;
	}
}

// OTHER CLASSES (move to funkin/debug/?)

class CharterDisplay extends Sprite {
	public var funnyQuarterNote:Bitmap;
	public var conductorText:TextField;
	public var noteInfoText:TextField;
	public var songPosText:TextField;
	public var metronomeText:TextField;
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
		
		funnyQuarterNote = new Bitmap(Paths.bmd('charter/quarterNote'), null, true);
		funnyQuarterNote.x = 13;
		addChild(funnyQuarterNote);
		conductorText = new TextField();
		conductorText.defaultTextFormat = metronomeTf;
		noteInfoText = new TextField();
		noteInfoText.defaultTextFormat = new TextFormat(Paths.ttf('vcr'), 11, -1);
		noteInfoText.defaultTextFormat.letterSpacing = -1;
		noteInfoText.alpha = .75;
		songPosText = new TextField();
		songPosText.defaultTextFormat = new TextFormat(Paths.ttf('vcr'), 12, -1);
		metronomeText = new TextField();
		metronomeText.defaultTextFormat = new TextFormat(Paths.ttf('vcr'), 18, -1);
		
		for (text in [conductorText, songPosText, noteInfoText, metronomeText]) {
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
	inline function getTextPos(i:Int) { return 35 + i * 15; }
	function repositionTexts() {
		for (i => pop in popUps) {
			if (!contains(pop)) continue;
			pop.y = getTextPos(i);
		}
	}
	public function updateMetronomeInfo() {
		var charter:CharterState = CharterState.instance;
		
		var metronomeTextT:String = '  = ${conductor.bpm}\n${conductor.timeSignature.toString()}';
		var songPosTextT:String = FlxStringUtil.formatTime(conductor.songPosition * .001, true) + ' / ' + FlxStringUtil.formatTime(songLength * .001, true);
		var conductorTextT:String = 'Measure: ${Math.floor(conductor.bar)}\nBeat: ${Math.floor(conductor.beat)}\nStep: ${Math.floor(conductor.step)}';
		var noteInfoTextT:String = '${charter.noteCount} notes';
		
		if (metronomeText.text != metronomeTextT) metronomeText.text = metronomeTextT;
		if (conductorText.text != conductorTextT) conductorText.text = conductorTextT;
		if (noteInfoText.text != noteInfoTextT) noteInfoText.text = noteInfoTextT;
		if (songPosText.text != songPosTextT) songPosText.text = songPosTextT;
	}
	
	override function __enterFrame(deltaTime:Float) {
		updateMetronomeInfo();
		
		noteInfoText.x = FlxG.stage.window.width - 12 - noteInfoText.textWidth;
		
		var h:Float = FlxG.stage.window.height;
		songPosText.y = h - songPosText.textHeight - 12;
		noteInfoText.y = h - noteInfoText.textHeight - 12;
		conductorText.y = h - conductorText.textHeight - 32;
		var infoHeight:Float = songPosText.textHeight + conductorText.textHeight + 32;
		
		funnyQuarterNote.y = metronomeText.y = h - infoHeight - metronomeText.textHeight;
		background.scaleX = Math.max(Math.max(songPosText.textWidth, conductorText.textWidth) + 24, 120);
		background.scaleY = infoHeight + metronomeText.textHeight + 10;
		background.y = h - background.scaleY;
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