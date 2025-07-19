package funkin.backend;

import openfl.geom.Matrix;
import flixel.util.FlxDestroyUtil;
import flixel.graphics.frames.FlxFrame;

class FunkinText extends FlxText implements funkin.backend.FunkinSprite.IFunkinSpriteVars {
	public var zoomFactor(default, set):Float = 1;
	public var initialZoom(default, set):Float = 1;
	public var smooth(default, set):Bool = true;
	
	public var transformMatrix(default, null):Matrix = new Matrix();
	public var skew(default, null):FlxPoint = FlxPoint.get();
	public var matrixExposed:Bool = false;
	
	public var animOffset:FlxPoint;
	public var spriteOffset:FlxPoint;
	public var rotateOffsets:Bool = true;
	public var scaleOffsets:Bool = true;
	public var skewOffsets:Bool = true;
	
	var _skewMatrix:Matrix = new Matrix();
	var _transPoint:FlxPoint;
	
	public function new(x:Float = 0, y:Float = 0, fieldWidth:Float = 0, ?text:String, size:Int = 8, isSmooth:Bool = false) {
		super(x, y, fieldWidth, text, size);
		
		_transPoint = new FlxPoint();
		spriteOffset = FlxPoint.get();
		animOffset = FlxPoint.get();
		smooth = isSmooth;
	}
	public override function destroy() {
		_transPoint = FlxDestroyUtil.put(_transPoint);
		spriteOffset = FlxDestroyUtil.put(spriteOffset);
		animOffset = FlxDestroyUtil.put(animOffset);
		super.destroy();
	}
	public function setAnimOffset(x:Float = 0, y:Float = 0):Void {
		animOffset.set(x, y);
	}
	
	public override function drawSimple(camera:FlxCamera) {
		updateShader(camera);
		
		getScreenPosition(_point, camera).subtractPoint(offset);
		if (isPixelPerfectRender(camera))
			_point.floor();

		_point.copyToFlash(_flashPoint);
		camera.copyPixels(_frame, framePixels, _flashRect, _flashPoint, colorTransform, blend, antialiasing);
	}
	public override function drawComplex(camera:FlxCamera) {
		updateShader(camera);
		
		_frame.prepareMatrix(_matrix, FlxFrameAngle.ANGLE_0, checkFlipX(), checkFlipY());
		
		_matrix.translate(-origin.x, -origin.y);
		_matrix.scale(scale.x, scale.y);
		
		if (matrixExposed) {
			_matrix.concat(transformMatrix);
		} else {
			if (bakedRotationAngle <= 0) {
				updateTrig();

				if (angle != 0)
					_matrix.rotateWithTrig(_cosAngle, _sinAngle);
			}
			
			updateSkewMatrix();
			_matrix.concat(_skewMatrix);
		}
		
		transformSpriteOffset(_transPoint);
		getScreenPosition(_point, camera);
		_point.add(-offset.x, -offset.y);
		_point.add(-_transPoint.x, -_transPoint.y);
		_matrix.translate(_point.x + origin.x, _point.y + origin.y);
		
		if (isPixelPerfectRender(camera)) {
			_matrix.tx = Math.floor(_matrix.tx);
			_matrix.ty = Math.floor(_matrix.ty);
		}
		
		FunkinSprite.transformMatrixZoom(_matrix, camera, zoomFactor, initialZoom);
		camera.drawPixels(_frame, framePixels, _matrix, colorTransform, blend, antialiasing, shader);
	}
	
	inline function transformSpriteOffset(point:FlxPoint):FlxPoint {
		var xP:Float = (spriteOffset.x + animOffset.x) * (scaleOffsets ? scale.x : 1);
		var yP:Float = (spriteOffset.y + animOffset.y) * (scaleOffsets ? scale.y : 1);
		
		if (rotateOffsets && angle % 360 != 0) {
			var rad:Float = angle / 180 * Math.PI;
			var cos:Float = FlxMath.fastCos(rad);
			var sin:Float = FlxMath.fastSin(rad);
			point.set(cos * xP - sin * yP, cos * yP + sin * xP);
		} else {
			point.set(xP, yP);
		}
		
		if (skewOffsets && (skew.x != 0 || skew.y != 0)) {
			point.set(
				point.x + point.y * Math.tan(skew.x / 180 * Math.PI),
				point.y + point.x * Math.tan(skew.y / 180 * Math.PI)
			);
		}
		
		return point;
	}
	function updateSkewMatrix():Void {
		_skewMatrix.identity();

		if (skew.x != 0 || skew.y != 0) {
			_skewMatrix.b = Math.tan(skew.y / 180 * Math.PI);
			_skewMatrix.c = Math.tan(skew.x / 180 * Math.PI);
		}
	}
	function updateShader(camera:FlxCamera) {
		if (shader == null || !Std.isOfType(shader, FunkinRuntimeShader))
			return;
		
		var funk:FunkinRuntimeShader = cast shader;
		funk.postUpdateView(camera);
		funk.postUpdateFrame(frame);
	}
	public override function isSimpleRenderBlit(?camera:FlxCamera):Bool {
		return (zoomFactor == 1 && skew.x == 0 && skew.y == 0 && super.isSimpleRenderBlit(camera));
	}
	
	function set_smooth(newSmooth:Bool):Bool {
		antialiasing = (newSmooth && Options.data.antialiasing);
		return (smooth = newSmooth);
	}
	function set_zoomFactor(value:Float):Float {
		return zoomFactor = value;
	}
	function set_initialZoom(value:Float):Float {
		return initialZoom = value;
	}
}