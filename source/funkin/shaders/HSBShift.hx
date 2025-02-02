package funkin.shaders;

// legacy

class HSBShift {
	public var hue(default, set):Float;
	public var saturation(default, set):Float;
	public var brightness(default, set):Float;
	public var shader(default, null):HSBShiftShader = new HSBShiftShader();

	private function set_hue(value:Float) {
		shader.hsb.value[0] = value;
		return hue = value;
	}
	
	private function set_saturation(value:Float) {
		shader.hsb.value[1] = value;
		return saturation = value;
	}
	
	private function set_brightness(value:Float) {
		shader.hsb.value[2] = value;
		return brightness = value;
	}
	
	public function new(hue:Float = 0, sat:Float = 0, brt:Float = 0) {
		shader.awesomeOutline.value = [false];
		shader.hsb.value = [0, 0, 0];
		this.brightness = brt;
		this.saturation = sat;
		this.hue = hue;
	}
}

class HSBShiftShader extends flixel.system.FlxAssets.FlxShader {
	@:glFragmentHeader('
		#pragma header
		
		uniform vec3 hsb;
		uniform bool awesomeOutline;
		
		vec3 rgb2hsv(vec3 c) {
			vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
			vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
			vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

			float d = q.x - min(q.w, q.y);
			float e = 1.0e-10;
			return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
		}
		
		vec3 hsv2rgb(vec3 c) {
			vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
			vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
			return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
		}
		
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
			
			vec3 swagColor = rgb2hsv(color.rgb);
			swagColor.x += hsb.x;
			swagColor.y = clamp(swagColor.y + hsb.y, 0., 1.);
			swagColor.z *= 1. + hsb.z;
			
			color.rgb = hsv2rgb(swagColor.rgb);
			
			if (awesomeOutline) {
				// Outline bullshit?
				vec2 size = vec2(3.);

				if (color.a <= 0.5) {
					float w = size.x / openfl_TextureSize.x;
					float h = size.y / openfl_TextureSize.y;

					if (texture2D(bitmap, vec2(uv.x + w, uv.y)).a != 0.
					|| texture2D(bitmap, vec2(uv.x - w, uv.y)).a != 0.
					|| texture2D(bitmap, vec2(uv.x, uv.y + h)).a != 0.
					|| texture2D(bitmap, vec2(uv.x, uv.y - h)).a != 0.) {
						color = vec4(1.0, 1.0, 1.0, 1.0);
					}
				}
			}
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