package;

import flixel.addons.transition.FlxTransitionableState;
import flixel.util.FlxSignal.FlxTypedSignal;
import flixel.addons.ui.FlxUIState;

class MusicBeatState extends FlxUIState {
	public var curStep:Int = -1;
	public var curBeat:Int = -1;
	public var curBar:Int = -1;
	public var paused:Bool = false;
	public var syncTracker:FlxSound = null;
	public var conductorPaused:Bool = false;

	public var stepHit:FlxTypedSignal<Int->Void> = new FlxTypedSignal<Int->Void>();
	public var beatHit:FlxTypedSignal<Int->Void> = new FlxTypedSignal<Int->Void>();
	public var barHit:FlxTypedSignal<Int->Void> = new FlxTypedSignal<Int->Void>();
	
	override function create() {
		HScriptBackend.stopAllScripts();
		Paths.trackedAssets.resize(0);
		super.create();
		// var stats = hl.Gc.stats();
		// Sys.println('mem: ${DebugDisplay.formatBytes(stats.currentMemory)} / allocated: ${DebugDisplay.formatBytes(stats.totalAllocated)} / alloc count: ${DebugDisplay.formatBytes(stats.allocationCount)}');
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
	
	public function resetMusic() {
		curBar = -1;
		curBeat = -1;
		curStep = -1;
		Conductor.songPosition = 0;
	}
	public function resetState() {
		FlxG.resetState();
	}
	
	override function update(elapsed:Float) {
		if (FlxG.keys.justPressed.F5) resetState();
		
		if (paused) return;
		super.update(elapsed);
		
		if (!conductorPaused) updateConductor(elapsed * 1000);
	}
	
	public function updateConductor(elapsedMS:Float = 0) {
		var prevStep:Int = curStep;
		var prevBeat:Int = curBeat;
		var prevBar:Int = curBar;

		var trackerTime:Float = (syncTracker != null && syncTracker.playing ? syncTracker.time : Conductor.songPosition);
		if (Math.abs(Conductor.songPosition - trackerTime) < 50) {
			Conductor.songPosition += elapsedMS;
		} else {
			Conductor.songPosition = trackerTime;
		}
		
		curStep = Math.floor(Conductor.metronome.step);
		curBeat = Math.floor(Conductor.metronome.beat);
		curBar = Math.floor(Conductor.metronome.bar);
		
		if (prevBar != curBar) barHit.dispatch(curBar);
		if (prevBeat != curBeat) beatHit.dispatch(curBeat);
		if (prevStep != curStep) stepHit.dispatch(curStep);
	}
	
	public function playMusic(mus:String) {
		@:privateAccess
		if (FlxG.sound.music == null || FlxG.sound.music._sound != Paths.music(mus)) {
			FlxG.sound.playMusic(Paths.music(mus));
		}
	}
}