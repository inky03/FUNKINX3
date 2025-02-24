package funkin.backend;

import funkin.backend.scripting.*;
import funkin.backend.rhythm.Event;
import funkin.backend.rhythm.Conductor;

import flixel.util.FlxSignal.FlxTypedSignal;

class FunkinState extends FlxSubState {
	public var curBar:Int = -1;
	public var curBeat:Int = -1;
	public var curStep:Int = -1;

	public var paused:Bool = false;
	public var conductorInUse:Conductor = Conductor.global;
	
	public var barHit:FlxTypedSignal<Int -> Void> = new FlxTypedSignal();
	public var beatHit:FlxTypedSignal<Int -> Void> = new FlxTypedSignal();
	public var stepHit:FlxTypedSignal<Int -> Void> = new FlxTypedSignal();
	
	public var events:Array<ITimedEvent<Dynamic>> = [];
	
	public var hscripts:HScripts;
	
	static var clearAssetsNow:Bool = false;
	
	public function new() { // no one gaf about your bg color
		super();
		hscripts = new HScripts([this], ['this' => this]);
	}
	
	override public function create() {
		Main.soundTray.reloadSoundtrayGraphics();
		Paths.trackedAssets.resize(0);
		if (clearAssetsNow) {
			clearAssetsNow = false;
			Log.info('CLEANING ALL ASSETS');
			Paths.trackedAssets.resize(0);
			Paths.clean();
		}
		
		super.create();
		
		conductorInUse.barHit.add(rhythmBarHit);
		conductorInUse.beatHit.add(rhythmBeatHit);
		conductorInUse.stepHit.add(rhythmStepHit);
	}
	function rhythmBarHit(t:Int) barHit.dispatch(t);
	function rhythmBeatHit(t:Int) beatHit.dispatch(t);
	function rhythmStepHit(t:Int) stepHit.dispatch(t);
	override public function destroy() {
		conductorInUse.stepHit.remove(rhythmStepHit);
		conductorInUse.beatHit.remove(rhythmBeatHit);
		conductorInUse.barHit.remove(rhythmBarHit);
		
		hscripts.destroyAll();
		super.destroy();
	}

	public function sortZIndex() {
		sort(Util.sortZIndex, FlxSort.ASCENDING);
	}
	public function insertZIndex(obj:FunkinSprite) {
		if (members.contains(obj)) remove(obj);
		var low:Float = Math.POSITIVE_INFINITY;
		for (pos => mem in members) {
			low = Math.min(mem.zIndex, low);
			if (obj.zIndex < mem.zIndex) {
				insert(pos, obj);
				return obj;
			}
		}
		if (obj.zIndex < low) {
			insert(0, obj);
		} else {
			add(obj);
		}
		return obj;
	}
	
	public function resetConductor() {
		curBar = -1;
		curBeat = -1;
		curStep = -1;
		conductorInUse.songPosition = 0;
	}
	public function resetState(cleanAllAssets:Bool = false) {
		clearAssetsNow = cleanAllAssets;
		FlxG.resetState();
	}
	
	override function update(elapsed:Float) {
		if (FlxG.keys.justPressed.F5) resetState(FlxG.keys.pressed.SHIFT);
		if (FlxG.keys.justPressed.F6) Mods.refresh();
		
		if (paused) return;
		
		updateConductor(elapsed);
		super.update(elapsed);
	}
	
	public function updateConductor(elapsed:Float = 0) {
		conductorInUse.update(elapsed * 1000);
		
		curBar = Math.floor(conductorInUse.bar);
		curBeat = Math.floor(conductorInUse.beat);
		curStep = Math.floor(conductorInUse.step);
		
		var limit:Int = 50; //avoid lags
		while (events.length > 0 && conductorInUse.songPosition >= events[0].msTime && limit > 0) {
			var event:ITimedEvent<Dynamic> = events.shift();
			if (event.func != null)
				event.func(event);
			limit --;
		}
	}
	
	public function queueEvent(ms:Float = 0, ?func:Event -> Void) {
		events.push(new Event(ms, func));
	}
	
	public function playMusic(mus:String, forced:Bool = false) {
		MusicHandler.playMusic(mus, forced);
		MusicHandler.applyMeta(conductorInUse);
	}
	
	public static function getCurrentConductor():Conductor {
		if (Std.isOfType(FlxG.state, FunkinState))
			return cast(FlxG.state, FunkinState).conductorInUse;
		return Conductor.global;
	}
}