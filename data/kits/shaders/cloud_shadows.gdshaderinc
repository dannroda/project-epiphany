// Sombras de nubes que cruzan el piso; las prende CloudShadows (x fuerza, y tamaño en metros, zw deriva en m/s).
global uniform vec4 cloud_shadows;

float cloud_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float cloud_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(cloud_hash(i), cloud_hash(i + vec2(1.0, 0.0)), f.x),
			mix(cloud_hash(i + vec2(0.0, 1.0)), cloud_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float cloud_shade(vec3 world, float time) {
	if (cloud_shadows.x <= 0.0) {
		return 1.0;
	}
	vec2 p = (world.xz - cloud_shadows.zw * time) / cloud_shadows.y;
	float n = cloud_noise(p) * 0.65 + cloud_noise(p * 2.3 + 17.0) * 0.35;
	return 1.0 - cloud_shadows.x * smoothstep(0.46, 0.58, n);
}
