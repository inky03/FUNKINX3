#pragma header

vec2 screenCoord;
uniform vec2 uScreenResolution;
uniform vec4 uCameraBounds;

vec2 screenToWorld(vec2 screenCoord) {
	float left = uCameraBounds.x;
	float top = uCameraBounds.y;
	float right = uCameraBounds.z;
	float bottom = uCameraBounds.w;
	vec2 scale = vec2(right - left, bottom - top);
	vec2 offset = vec2(left, top);
	return screenCoord * scale + offset;
}

vec2 worldToScreen(vec2 worldCoord) {
	float left = uCameraBounds.x;
	float top = uCameraBounds.y;
	float right = uCameraBounds.z;
	float bottom = uCameraBounds.w;
	vec2 scale = vec2(right - left, bottom - top);
	vec2 offset = vec2(left, top);
	return (worldCoord - offset) / scale;
}

vec2 bitmapCoordScale() {
	return openfl_TextureCoordv / screenCoord;
}

vec2 screenToBitmap(vec2 screenCoord) {
	return screenCoord * bitmapCoordScale();
}

vec4 sampleBitmapScreen(vec2 screenCoord) {
	return texture2D(bitmap, screenToBitmap(screenCoord));
}

vec4 sampleBitmapWorld(vec2 worldCoord) {
	return sampleBitmapScreen(worldToScreen(worldCoord));
}

// prevent auto field generation
#define UNIFORM uniform

uniform float uTime;
uniform float uScale;
uniform float uIntensity;
uniform vec3 uRainColor;

float rand(vec2 a) {
	return fract(sin(dot(a, vec2(12.9898, 78.233))) * 300.1234);
}

float rainDist(vec2 p, float scale, float intensity) {
	// scale everything
	p *= 0.1;
	// sheer
	p.x += p.y * 0.1;
	// scroll
	p.y -= uTime * 500.0 / scale;
	// expand Y
	p.y *= 0.03;
	float ix = floor(p.x);
	// shift Y
	p.y += mod(ix, 2.0) * 0.5 + (rand(vec2(ix)) - 0.5) * 0.3;
	float iy = floor(p.y);
	vec2 index = vec2(ix, iy);
	// mod
	p -= index;
	// shift X
	p.x += (rand(index.yx) * 2.0 - 1.0) * 0.35;
	// distance
	vec2 a = abs(p - 0.5);
	float res = max(a.x * 0.8, a.y * 0.5) - 0.1;
	// decimate
	bool empty = rand(index) < mix(1.0, 0.1, intensity);
	return empty ? 1.0 : res;
}

vec2 worldToBackground(vec2 worldCoord) {
	// this should work as long as the background sprite is placed at the origin without scaling
	return worldCoord / uScreenResolution;
}

void main() {
	screenCoord = openfl_TextureCoordv;

	vec2 wpos = screenToWorld(screenCoord);
	float intensity = uIntensity;

	vec3 add = vec3(0);
	float rainSum = 0.0;

	const int numLayers = 4;
	float scales[4];
	scales[0] = 1.0;
	scales[1] = 1.8;
	scales[2] = 2.6;
	scales[3] = 4.8;

	for (int i = 0; i < numLayers; i++) {
		float scale = scales[i];
		float r = rainDist(wpos * scale / uScale + 500.0 * float(i), scale, intensity);
		if (r < 0.0) {
			float v = (1.0 - exp(r * 5.0)) / scale * 2.0;
			wpos.x += v * 10.0 * uScale;
			wpos.y -= v * 2.0 * uScale;
			add += vec3(0.1, 0.15, 0.2) * v;
			rainSum += (1.0 - rainSum) * 0.75;
		}
	}

	vec4 color = sampleBitmapWorld(wpos);
	color.rgb = mix(color.rgb + add, uRainColor, 0.1 * rainSum);

	gl_FragColor = color;
}
