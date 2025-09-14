package funkin.shaders;

class RGBSwap { // im coming
	public var red(default, set):FlxColor;
	public var blue(default, set):FlxColor;
	public var green(default, set):FlxColor;
	public var shader(default, null):RGBSwapShader = new RGBSwapShader();
	
	public function copy(?targetShd:RGBSwap):RGBSwap {
		if (targetShd != null) {
			targetShd.green = green;
			targetShd.blue = blue;
			targetShd.red = red;
		} else {
			targetShd = new RGBSwap(red, green, blue);
		}
		return targetShd;
	}
	public function set_red(newC:FlxColor) {
		shader.red.value = [newC.redFloat, newC.greenFloat, newC.blueFloat];
		return red = newC;
	}
	public function set_green(newC:FlxColor) {
		shader.green.value = [newC.redFloat, newC.greenFloat, newC.blueFloat];
		return green = newC;
	}
	public function set_blue(newC:FlxColor) {
		shader.blue.value = [newC.redFloat, newC.greenFloat, newC.blueFloat];
		return blue = newC;
	}
	public function set(red:FlxColor = FlxColor.RED, green:FlxColor = FlxColor.LIME, blue:FlxColor = FlxColor.BLUE) {
		this.red = red;
		this.blue = blue;
		this.green = green;
	}
	
	public function new(red:FlxColor = FlxColor.RED, green:FlxColor = FlxColor.LIME, blue:FlxColor = FlxColor.BLUE) {
		this.set(red, green, blue);
	}
}

class RGBSwapShader extends flixel.system.FlxAssets.FlxShader {
	@:glFragmentHeader('
		#pragma header

		uniform vec3 red;
		uniform vec3 green;
		uniform vec3 blue;
		
		vec4 applyColorTransform(vec4 color) {
		    if (color.a == 0.) {
		        return vec4(0.);
		    }
		    if (!hasTransform) {
		        return color;
		    }
		    if (!hasColorTransform) {
		        return color * openfl_Alphav;
		    }

		    color = vec4(color.rgb / color.a, color.a);
		    color = clamp(openfl_ColorOffsetv + color * openfl_ColorMultiplierv, 0., 1.);

		    if (color.a > 0.) {
		        return vec4(color.rgb * color.a * openfl_Alphav, color.a * openfl_Alphav);
		    }
		    return vec4(0.);
		}

		vec4 flixel_texture2DCustom(sampler2D bitmap, vec2 uv) {
			vec4 color = texture2D(bitmap, uv);
			if (color.a == 0.0) {
				return color;
			}

			color.rgb = min(vec3(color.r * red + color.g * green + color.b * blue), color.a);
			return applyColorTransform(color);
		}
	')

	@:glFragmentSource('
		#pragma header

		void main() {
			gl_FragColor = flixel_texture2DCustom(bitmap, openfl_TextureCoordv);
		}
	')

	public function new() {
		super();
	}
}