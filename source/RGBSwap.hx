import flixel.system.FlxAssets.FlxShader;

class RGBSwap { // im coming
	public var red(default, set):FlxColor;
	public var blue(default, set):FlxColor;
	public var green(default, set):FlxColor;
	public var shader(default, null):RGBSwapShader = new RGBSwapShader();

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
	public function new() {
		red = 0xff0000;
		blue = 0x0000ff;
		green = 0x00ff00;
	}
}

class RGBSwapShader extends FlxShader {
	@:glFragmentHeader('
		#pragma header

		uniform vec3 red;
		uniform vec3 green;
		uniform vec3 blue;

		vec4 flixel_texture2DCustom(sampler2D bitmap, vec2 uv) {
			vec4 color = flixel_texture2D(bitmap, uv);
			if (!hasTransform || color.a == 0.0) {
				return color;
			}

			color.rgb = min(vec3(color.r * red + color.g * green + color.b * blue), color.a);
			// float fullAlpha = (color.a / openfl_Alphav);
			// color.a = pow(fullAlpha, 5) * openfl_Alphav;
			return color;
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