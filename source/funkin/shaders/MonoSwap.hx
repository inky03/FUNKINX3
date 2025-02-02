package funkin.shaders;

class MonoSwap {
	public var white(default, set):FlxColor;
	public var black(default, set):FlxColor;
	public var shader(default, null):MonoSwapShader = new MonoSwapShader();
	
	public function set_white(newC:FlxColor) {
		shader.white.value = [newC.redFloat, newC.greenFloat, newC.blueFloat, newC.alphaFloat];
		return white = newC;
	}
	public function set_black(newC:FlxColor) {
		shader.black.value = [newC.redFloat, newC.greenFloat, newC.blueFloat, newC.alphaFloat];
		return black = newC;
	}
	public function new(white:FlxColor = FlxColor.WHITE, black:FlxColor = FlxColor.BLACK) {
		this.white = white;
		this.black = black;
	}
}

class MonoSwapShader extends flixel.system.FlxAssets.FlxShader {
	@:glFragmentHeader('
		#pragma header
		
		uniform vec4 white;
		uniform vec4 black;
		
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
			if (color.a == 0.) {
				return color;
			}
			
			float lum = (.2126 * color.r + .7152 * color.g + .0722 * color.b) / color.a;
			
			vec4 mixed = mix(black, white, lum);
			color.rgb = mixed.rgb * mixed.a * color.a;
			color.a *= mixed.a;
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