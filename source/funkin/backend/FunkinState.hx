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
	
	public var events:Array<ITimedEvent<Dynamic>> = [];
	public var conductorInUse(default, set):Conductor;
	
	public var barHit:FlxTypedSignal<Int -> Void> = new FlxTypedSignal();
	public var beatHit:FlxTypedSignal<Int -> Void> = new FlxTypedSignal();
	public var stepHit:FlxTypedSignal<Int -> Void> = new FlxTypedSignal();
	
	public var hscripts:HScriptGroup;
	
	static var clearAssetsNow:Bool = false;
	var firstRun:Bool = true;
	
	public function new() {
		super();
		conductorInUse = Conductor.global;
		add(hscripts = new HScriptGroup([this], ['this' => this]));
		
		persistentUpdate = true;
	}
	
	override public function create() {
		FlxG.fixedTimestep = false;
		
		Main.soundTray.reloadSoundtrayGraphics();
		Paths.trackedAssets.resize(0);
		if (clearAssetsNow) {
			clearAssetsNow = false;
			Log.info('CLEANING ALL ASSETS');
			Paths.trackedAssets.resize(0);
			Paths.clean();
		}
		
		subStateOpened.add(onSubStateOpened);
		subStateClosed.add(onSubStateClosed);
		
		super.create();
	}
	
	public function onSubStateOpened(substate):Void {}
	public function onSubStateClosed(substate):Void {}
	
	override public function destroy() {
		conductorInUse = null;
		
		super.destroy();
	}
	
	function set_conductorInUse(?newConductor:Conductor):Conductor {
		if (conductorInUse == newConductor) return newConductor;
		
		unhookConductor(conductorInUse);
		hookConductor(newConductor);
		
		return conductorInUse = newConductor;
	}
	function unhookConductor(conductor:Conductor) {
		if (conductor == null) return;
		
		conductor.advance.remove(updateEvents);
		conductor.stepHit.remove(rhythmStepHit);
		conductor.beatHit.remove(rhythmBeatHit);
		conductor.barHit.remove(rhythmBarHit);
	}
	function hookConductor(conductor:Conductor) {
		if (conductor == null) return;
		
		if (!conductor.barHit.has(rhythmBarHit)) conductor.barHit.add(rhythmBarHit);
		if (!conductor.beatHit.has(rhythmBeatHit)) conductor.beatHit.add(rhythmBeatHit);
		if (!conductor.stepHit.has(rhythmStepHit)) conductor.stepHit.add(rhythmStepHit);
		if (!conductor.advance.has(updateEvents)) conductor.advance.add(updateEvents);
	}
	function rhythmBarHit(t:Int) barHit.dispatch(t);
	function rhythmBeatHit(t:Int) beatHit.dispatch(t);
	function rhythmStepHit(t:Int) stepHit.dispatch(t);

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
	@:allow(flixel.FlxGame)
	override function tryUpdate(elapsed:Float):Void {
		if (persistentUpdate || subState == null) {
			if (firstRun) {
				firstRun = false;
				update(0);
			} else {
				update(elapsed);
			}
		}
		
		if (subState != null)
			subState.tryUpdate(elapsed);
		if (_requestSubStateReset) {
			_requestSubStateReset = false;
			resetSubState();
		}
	}
	
	public function updateConductor(elapsed:Float = 0) {
		conductorInUse.update(elapsed * 1000 / FlxG.timeScale);
		
		curBar = Math.floor(conductorInUse.bar);
		curBeat = Math.floor(conductorInUse.beat);
		curStep = Math.floor(conductorInUse.step);
	}
	
	public function queueEvent(ms:Float = 0, ?func:Event -> Void) {
		events.push(new Event(ms, func));
	}
	public function updateEvents(time:Float) {
		var limit:Int = 50; //avoid lags
		while (events.length > 0 && time >= events[0].msTime && limit > 0) {
			var event:ITimedEvent<Dynamic> = events.shift();
			if (event.func != null) {
				try {
					event.func(event);
				} catch (e:haxe.Exception) {
					Log.error('error when triggering event -> ${e.details()}');
				}
			}
			limit --;
		}
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
	public static function getCurrentSubState():FlxState {
		var state:FlxState = FlxG.state;
		while (state.subState != null)
			state = state.subState;
		return state;
	}
}