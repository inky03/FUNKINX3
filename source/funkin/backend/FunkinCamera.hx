package funkin.backend;

class FunkinCamera extends FlxCamera {
	public var pauseZoomLerp:Bool = false; // OK, this is hacky but i cant be arsed
	public var pauseFollowLerp:Bool = false;
	public var zoomTarget:Null<Float> = null;
	public var zoomFollowLerp:Float = -1;
	var time:Float = -1;

	override public function update(elapsed:Float):Void {
		if (target != null) updateFollowMod(elapsed);
		if (zoomTarget != null) updateZoomFollow(elapsed);

		updateScroll();
		updateFlash(elapsed);
		updateFade(elapsed);

		flashSprite.filters = filtersEnabled ? filters : null;

		updateFlashSpritePosition();
		updateShake(elapsed);
	}
	public override function follow(target:FlxObject, ?style:FlxCameraFollowStyle, ?lerp:Float):Void {
		super.follow(target, style, lerp);
		followLerp = lerp ?? -1;
	}
	public override function snapToTarget() {
		super.snapToTarget();
		if (zoomTarget != null)
			zoom = zoomTarget;
	}
	override function render() {
		if (filters != null) {
			for (filter in filters) {
				if (!Std.isOfType(filter, openfl.filters.ShaderFilter))
					continue;
				
				var filt:openfl.filters.ShaderFilter = cast filter;
				
				if (Std.isOfType(filt.shader, FunkinRuntimeShader)) {
					var funk:FunkinRuntimeShader = cast filt.shader;
					funk.postUpdateView(this);
				}
			}
		}
		super.render();
	}

	public function updateFollowMod(elapsed:Float):Void {
		// Either follow the object closely,
		// or double check our deadzone and update accordingly.
		if (deadzone == null) {
			target.getMidpoint(_point);
			_point.addPoint(targetOffset);
			_scrollTarget.set(_point.x - width * 0.5, _point.y - height * 0.5);
		}
		else {
			var edge:Float;
			var targetX:Float = target.x + targetOffset.x;
			var targetY:Float = target.y + targetOffset.y;

			if (style == SCREEN_BY_SCREEN) {
				if (targetX >= viewRight)
					_scrollTarget.x += viewWidth;
				else if (targetX + target.width < viewLeft)
					_scrollTarget.x -= viewWidth;

				if (targetY >= viewBottom)
					_scrollTarget.y += viewHeight;
				else if (targetY + target.height < viewTop)
					_scrollTarget.y -= viewHeight;
				
				// without this we see weird behavior when switching to SCREEN_BY_SCREEN at arbitrary scroll positions
				bindScrollPos(_scrollTarget);
			}
			else
			{
				edge = targetX - deadzone.x;
				if (_scrollTarget.x > edge)
					_scrollTarget.x = edge;
				edge = targetX + target.width - deadzone.x - deadzone.width;
				if (_scrollTarget.x < edge)
					_scrollTarget.x = edge;

				edge = targetY - deadzone.y;
				if (_scrollTarget.y > edge)
					_scrollTarget.y = edge;
				edge = targetY + target.height - deadzone.y - deadzone.height;
				if (_scrollTarget.y < edge)
					_scrollTarget.y = edge;
			}

			if (target is FlxSprite) {
				if (_lastTargetPosition == null)
					_lastTargetPosition = FlxPoint.get(target.x, target.y); // Creates this point.
				
				_scrollTarget.x += (target.x - _lastTargetPosition.x) * followLead.x;
				_scrollTarget.y += (target.y - _lastTargetPosition.y) * followLead.y;

				_lastTargetPosition.x = target.x;
				_lastTargetPosition.y = target.y;
			}
		}

		if (pauseFollowLerp) return;
		if (followLerp < 0) {
			scroll.copyFrom(_scrollTarget); // no easing
		} else if (followLerp > 0) {
			scroll.x = Util.smoothLerp(scroll.x, _scrollTarget.x, followLerp * elapsed);
			scroll.y = Util.smoothLerp(scroll.y, _scrollTarget.y, followLerp * elapsed);
		}
	}
	public function updateZoomFollow(elapsed:Float) {
		if (pauseZoomLerp) return;
		if (zoomFollowLerp < 0) {
			zoom = zoomTarget;
		} else if (zoomFollowLerp > 0) {
			zoom = Util.smoothLerp(zoom, zoomTarget, zoomFollowLerp * elapsed);
		}
	}

	override function set_followLerp(value:Float)
		return followLerp = value;
}