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

	public var stepHit:FlxTypedSignal<Int->Void> = new FlxTypedSignal<Int->Void>();
	public var beatHit:FlxTypedSignal<Int->Void> = new FlxTypedSignal<Int->Void>();
	public var barHit:FlxTypedSignal<Int->Void> = new FlxTypedSignal<Int->Void>();
	
	public var events:Array<ITimedEvent<Dynamic>> = [];
	
	public var hscripts:HScripts = new HScripts();
	
	public function new() { // no one gaf about your bg color
		super();
	}
	
	override public function create() {
		Main.soundTray.reloadSoundtrayGraphics();
		Paths.trackedAssets.resize(0);
		super.create();
	}
	override public function destroy() {
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
	public function resetState() {
		FlxG.resetState();
	}
	
	override function update(elapsed:Float) {
		if (FlxG.keys.justPressed.F5) resetState();
		if (FlxG.keys.justPressed.F6) Mods.refresh();
		
		if (paused) return;
		
		updateConductor(elapsed);
		super.update(elapsed);
	}
	
	public function updateConductor(elapsed:Float = 0) {
		var prevStep:Int = curStep;
		var prevBeat:Int = curBeat;
		var prevBar:Int = curBar;

		conductorInUse.update(elapsed * 1000);
		
		curStep = Math.floor(conductorInUse.metronome.step);
		curBeat = Math.floor(conductorInUse.metronome.beat);
		curBar = Math.floor(conductorInUse.metronome.bar);
		
		if (prevBar != curBar) barHit.dispatch(curBar);
		if (prevBeat != curBeat) beatHit.dispatch(curBeat);
		if (prevStep != curStep) stepHit.dispatch(curStep);
		
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