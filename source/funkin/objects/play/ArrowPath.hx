package funkin.objects.play;

import funkin.objects.play.Lane;
import funkin.objects.play.Note;
import funkin.backend.FunkinStrip;
import flixel.graphics.tile.FlxDrawTrianglesItem.DrawData;

class ArrowPath extends NoteObject {
	public var strip:ArrowPathStrip;
	public var render:Bool = true;
	
	public var thickness(get, set):Float;
	public var multAlpha:Float = 1;
	
	public var adaptiveDirection:Bool = false;
	public var minDistance:Float = -180;
	public var maxDistance:Float = 720;
	public var steps:Float = 44;
	
	var drawData:Array<NoteTailDrawData> = [];
	var drawItems:Int = 0;
	
	public function new(lane:Lane) {
		super();
		
		this.strip = new ArrowPathStrip();
		this.laneIndex = lane.noteData;
		this.lane = lane;
	}
	public function copyReceptor(receptor:Receptor) {
		if (receptor == null) return;
		
		scrollPosition.set(receptor.x + receptor.width * .5, receptor.y + receptor.height * .5);
		angle = direction + (receptor.lane.direction ?? 0);
		alpha = receptor.alpha * multAlpha;
		visible = receptor.visible;
	}
	public override function update(elapsed:Float):Void {
		super.update(elapsed);
		strip.update(elapsed);
	}
	public override function draw():Void {
		copyReceptor(lane?.receptor);
		
		if (!visible || !render || alpha <= 0) return;
		
		updateTriangles(lane);
		for (camera in getCamerasLegacy()) {
			if (!camera.visible || !camera.exists) continue;
			
			drawComplex(camera);
			
			#if FLX_DEBUG FlxBasic.visibleCount++; #end
		}
	}
	
	public override function drawComplex(camera:FlxCamera):Void {
		updateShader(camera);
		
		for (i in 0 ... drawItems) {
			var data:NoteTailDrawData = drawData[i];
			var strip:ArrowPathStrip = data.strip;
			strip.updateRender(data);
			strip.draw();
		}
	}
	public function updateTriangles(lane:Lane):Void {
		if (steps < 5) {
			Log.warning('$steps px/step for arrow path is too low !!');
			steps = 5;
		}
		
		var modchartFunc = (customModchart ?? genericModchart);
		
		var scrollDistance:Float = minDistance;
		try {
			(customScrollDistance ?? genericScrollDistance)(this, lane, 0); // error check
			if (updateModchart)
				modchartFunc(this, lane, minDistance);
		} catch (e:haxe.Exception) {
			Log.error('error on path modchart function -> ${e.details()}');
			
			customModchart = null;
			customScrollDistance = null;
			modchartFunc = genericModchart;
			
			if (updateModchart)
				genericModchart(this, lane, minDistance);
		}
		
		drawItems = 0;
		var rad:Float = (Math.PI / 180);
		var prevAngle:Null<Float> = null;
		var defaultAngle:Float = angle * rad;
		
		while (scrollDistance < maxDistance) {
			var prevScale:FlxPoint = FlxPoint.weak(scale.x, scale.y);
			var prevPosition:FlxPoint = FlxPoint.weak(x, y);
			
			scrollDistance += steps;
			modchartFunc(this, lane, scrollDistance);
			
			var curPosition:FlxPoint = FlxPoint.weak(x, y);
			
			var radAngle:Float;
			if (adaptiveDirection) {
				angle = (prevPosition.degreesTo(curPosition) + 180);
				radAngle = angle * rad;
				prevAngle ??= radAngle;
			} else {
				prevAngle ??= defaultAngle;
				radAngle = angle * rad;
			}
			
			var data:NoteTailDrawData = (drawData[drawItems] ?? new NoteTailDrawData());
			data.copyPosition(prevPosition, curPosition);
			data.setScale(prevScale.x, scale.x);
			data.setAngle(prevAngle, radAngle);
			data.strip = strip;
			drawData[drawItems ++] = data;
			
			prevAngle = radAngle;
		}
		
		strip.alpha = alpha;
		strip.color = color;
	}
	
	function get_thickness():Float {
		return strip.thickness;
	}
	function set_thickness(now:Float):Float {
		return strip.thickness = now;
	}
}

class ArrowPathStrip extends FunkinStrip {
	public var thickness:Float = 6;
	
	public var fast(default, set):Bool;
	var sinFunc:Float -> Float;
	var cosFunc:Float -> Float;
	
	public function new() {
		super();
		
		this.fast = true;
		this.makeGraphic(1, 1, FlxColor.WHITE);
		
		indices = new DrawData<Int>(6, true, [0, 1, 2, 1, 2, 3]);
		uvtData = new DrawData<Float>(8, true, [0, 0, 0, 1, 1, 0, 1, 1]);
		vertices = new DrawData<Float>(8, true, [0, 0, 0, 0, 0, 0, 0, 0]);
		// topleft topright bottomleft bottomright
	}
	
	public function updateRender(drawData:NoteTailDrawData):Void {
		if (graphic == null)
			return;
		
		var thickB:Float = (thickness * .5);
		var angleTo:Float = drawData.angleTo;
		var angleFrom:Float = drawData.angleFrom;
		
		setPosition(drawData.xFrom, drawData.yFrom);
		var sprXOffset:Float = -(spriteOffset.x + animOffset.x);
		var sprYOffset:Float = -(spriteOffset.y + animOffset.y);
		var nextXOffset:Float = (drawData.xTo - drawData.xFrom);
		var nextYOffset:Float = (drawData.yTo - drawData.yFrom);
		
		// update vertices
		var width:Float = thickB * drawData.scaleFrom;
		var widthTo:Float = thickB * drawData.scaleTo;
		var xOffset:Float = sprXOffset * drawData.scaleFrom;
		var xOffsetTo:Float = sprXOffset * drawData.scaleTo;
		var yOffset:Float = sprYOffset * drawData.scaleFrom;
		var yOffsetTo:Float = sprYOffset * drawData.scaleTo;
		
		var sin:Float = sinFunc(angleTo) * widthTo;
		var cos:Float = cosFunc(angleTo) * widthTo;
		
		vertices[0] = -sin + nextXOffset + xOffsetTo; // top left
		vertices[1] = cos + nextYOffset + yOffsetTo;
		vertices[2] = sin + nextXOffset + xOffsetTo; // top right
		vertices[3] = -cos + nextYOffset + yOffsetTo;
		
		sin = sinFunc(angleFrom) * width;
		cos = cosFunc(angleFrom) * width;
		
		vertices[4] = -sin + xOffset; // bottom left
		vertices[5] = cos + yOffset;
		vertices[6] = sin + xOffset; // bottom right
		vertices[7] = -cos + yOffset;
	}
	
	function set_fast(yea:Bool):Bool {
		sinFunc = (yea ? FlxMath.fastSin : Math.sin);
		cosFunc = (yea ? FlxMath.fastCos : Math.cos);
		return fast = yea;
	}
}