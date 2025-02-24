package funkin.objects.stage;

import funkin.vis.dsp.SpectralAnalyzer;

using Lambda;

class ABotVisualizer extends FunkinSpriteGroup {
	public var bars:Array<FunkinSprite> = [];
	public var snd(default, set):FlxSound;
	public var flipFeedback:Bool = true;
	public var boost:Float = 1;
	
	var analyzer:SpectralAnalyzer;
	var volumes:Array<Float> = [];
	var levels:Array<Bar> = [];
	
	public function new(?snd:FlxSound) {
		super();
		
		var positionX:Array<Float> = [0, 59, 56, 66, 54, 52, 51];
		var positionY:Array<Float> = [0, -8, -3.5, -0.4, 0.5, 4.7, 7];
		
		var posX:Float = 0;
		var posY:Float = 0;
		for (i in 0 ... 7) {
			volumes.push(0);
			
			posX += positionX[i];
			posY += positionY[i];
			
			var vis:FunkinSprite = new FunkinSprite(posX, posY);
			bars.push(vis);
			add(vis);
		}
		loadVisAtlas('characters/aBot/vis');
		
		this.snd = snd;
	}
	public function loadVisAtlas(path:String) {
		for (i => bar in bars) {
			bar.loadAtlas(path);
			bar.addAnimation('bar', 'viz${i + 1}', 0);
			bar.playAnimation('bar', true);
			bar.finishAnimation();
			bar.updateHitbox();
		}
	}
	public override function update(elapsed:Float) {
		super.update(elapsed);
		
		if (analyzer == null) return;
		
		levels = analyzer.getLevels(levels, snd.time);
		for (i => level in levels) {
			var bar:FunkinSprite = bars[i];
			if (bar == null || bar.animation.curAnim == null) break;
			
			var maxFrames:Int = bar.animation.curAnim.numFrames - 1;
			var animFrame:Int = Math.round(Util.clamp(level.value * boost * maxFrames, 0, maxFrames));
			if (flipFeedback)
				animFrame = maxFrames - animFrame;
			
			bar.animation.curAnim.curFrame = animFrame;
		}
	}
	
	public function initAnalyzer() {
		if (snd == null) {
			analyzer = null;
			return;
		}
		
		@:privateAccess analyzer = new SpectralAnalyzer(snd._channel.__audioSource, volumes.length, .1, 40);
		analyzer.fftN = 256;
	}
	function set_snd(newSnd:FlxSound) {
		if (snd == newSnd) return newSnd;
		
		snd = newSnd;
		#if funkin.vis
		initAnalyzer();
		#end
		return newSnd;
	}
}