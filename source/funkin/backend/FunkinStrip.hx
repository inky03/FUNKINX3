package funkin.backend;

import flixel.graphics.tile.FlxDrawTrianglesItem.DrawData;

class FunkinStrip extends FunkinSprite {
	public var vertices:DrawData<Float> = new DrawData<Float>();
	public var uvtData:DrawData<Float> = new DrawData<Float>();
	public var indices:DrawData<Int> = new DrawData<Int>();
	public var colors:DrawData<Int> = new DrawData<Int>();
	
	public var repeat:Bool = false;
	
	override public function destroy():Void {
		vertices = null;
		indices = null;
		uvtData = null;
		colors = null;

		super.destroy();
	}
	
	override public function draw():Void {
		if (alpha == 0 || graphic == null || vertices == null)
			return;

		final cameras = getCamerasLegacy();
		for (camera in cameras) {
			if (!camera.visible || !camera.exists)
				continue;

			getScreenPosition(_point, camera).subtractPoint(offset);
			#if !flash
			camera.drawTriangles(graphic, vertices, indices, uvtData, colors, _point, blend, repeat, antialiasing, colorTransform, shader);
			#else
			camera.drawTriangles(graphic, vertices, indices, uvtData, colors, _point, blend, repeat, antialiasing);
			#end
		}
	}
}