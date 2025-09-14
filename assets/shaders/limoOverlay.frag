#pragma header

uniform sampler2D image;

vec4 blendOverlay(vec4 base, vec4 blend) {
	vec4 mixed = mix(1.0 - 2.0 * (1.0 - base) * (1.0 - blend), 2.0 * base * blend, step(base, vec4(0.5)));
	
	return mixed;
}

void main() {
	vec2 funnyUv = openfl_TextureCoordv;
	vec4 color = flixel_texture2D(bitmap, funnyUv);

	vec2 reallyFunnyUv = vec2(vec2(0.0, 0.0) - gl_FragCoord.xy / openfl_TextureSize.xy);
	vec4 gf = flixel_texture2D(image, openfl_TextureCoordv.xy + vec2(0.1, 0.2));

	gl_FragColor = blendOverlay(color, gf);
}