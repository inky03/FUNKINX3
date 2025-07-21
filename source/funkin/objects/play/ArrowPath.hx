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
		
		copyReceptor(lane?.receptor);
		if (render && visible && alpha > 0)
			updateTriangles(lane);
		
	}
	public override function draw():Void {
		if (!visible || !render || alpha <= 0) return;
		
		strip.alpha = alpha;
		strip.color = color;
		
		for (camera in getCamerasLegacy()) {
			if (camera.visible && camera.exists)
				drawComplex(camera);
		}
	}
	
	public override function drawComplex(camera:FlxCamera):Void {
		updateShader(camera);
		
		for (i in 0 ... drawItems) {
			strip.updateRender(drawData[i]);
			strip.drawToCamera(camera);
		}
	}
	public function updateTriangles(lane:Lane):Void {
		if (!updateModchart) return;
		
		if (steps < 5) {
			Log.warning('$steps px/step for arrow path is too low !!');
			steps = 5;
		}
		
		var modchartFunc = (customModchart ?? genericModchart);
		
		var scrollDistance:Float = minDistance;
		try {
			(customScrollDistance ?? genericScrollDistance)(this, lane, 0); // error check
			modchartFunc(this, lane, minDistance);
		} catch (e:haxe.Exception) {
			Log.error('error on path modchart function -> ${e.details()}');
			
			customModchart = null;
			customScrollDistance = null;
			modchartFunc = genericModchart;
			genericModchart(this, lane, minDistance);
		}
		
		drawItems = 0;
		var defaultAngle:Float = angle;
		var prevAngle:Null<Float> = null;
		
		while (scrollDistance < maxDistance) {
			var prevScale:FlxPoint = FlxPoint.weak(scale.x, scale.y);
			var prevPosition:FlxPoint = FlxPoint.weak(x, y);
			
			scrollDistance += steps;
			modchartFunc(this, lane, scrollDistance);
			
			var curPosition:FlxPoint = FlxPoint.weak(x, y);
			
			if (adaptiveDirection) {
				angle = (prevPosition.degreesTo(curPosition) + 180);
				prevAngle ??= angle;
			} else {
				prevAngle ??= defaultAngle;
			}
			
			var data:NoteTailDrawData = (drawData[drawItems] ?? new NoteTailDrawData());
			data.copyPosition(prevPosition, curPosition);
			data.setScale(prevScale.x, scale.x);
			data.setAngle(prevAngle, angle);
			drawData[drawItems ++] = data;
			
			prevAngle = angle;
		}
	}
	
	inline function get_thickness():Float {
		return strip.thickness;
	}
	inline function set_thickness(now:Float):Float {
		return strip.thickness = now;
	}
}

class ArrowPathStrip extends FunkinStrip {
	public var thickness:Float = 2;
	
	public function new() {
		super();
		
		this.smooth = false;
		this.makeGraphic(25, 25, FlxColor.WHITE);
		
		indices = new DrawData<Int>(6, true, [0, 1, 2, 1, 2, 3]);
		uvtData = new DrawData<Float>(8, true, [0, 0, 0, 1, 1, 0, 1, 1]);
		vertices = new DrawData<Float>(8, true, [0, 0, 0, 0, 0, 0, 0, 0]);
		// topleft topright bottomleft bottomright
	}
	
	public function updateRender(drawData:NoteTailDrawData):Void {
		if (graphic == null) return;
		
		// update vertices
		var width:Float = (thickness * .5 * drawData.scaleTo);
		var sin:Float = (FlxMath.fastSin(drawData.angleTo) * width);
		var cos:Float = (FlxMath.fastCos(drawData.angleTo) * width);
		
		vertices[0] = (-sin + drawData.xTo); // top left
		vertices[1] = (cos + drawData.yTo);
		vertices[2] = (sin + drawData.xTo); // top right
		vertices[3] = (-cos + drawData.yTo);
		
		width = (thickness * .5 * drawData.scaleFrom);
		sin = (FlxMath.fastSin(drawData.angleFrom) * width);
		cos = (FlxMath.fastCos(drawData.angleFrom) * width);
		
		vertices[4] = (-sin + drawData.xFrom); // bottom left
		vertices[5] = (cos + drawData.yFrom);
		vertices[6] = (sin + drawData.xFrom); // bottom right
		vertices[7] = (-cos + drawData.yFrom);
	}
}