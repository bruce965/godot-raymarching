shader_type spatial;
render_mode depth_draw_always, cull_front, skip_vertex_transform, shadows_disabled;

// max number of steps before giving up with ray-marching
const int MAX_RAYMARCH_STEPS = 1000;  // lower = faster, higher = better

// max distance before giving up with ray-marching
const float MAX_RAYMARCH_DISTANCE = 300.;  // lower = faster, higher = better

// thickness of the surface (must be above zero to avoid infinite recursion)
const float SURFACE_THICKNESS = .0001;  // lower = better, higher = faster

float smin(float a, float b, float k) {
	// https://www.shadertoy.com/view/3ssGWj
	float h = clamp(.5+.5*(b-a)/k, 0., 1.);
	return mix(b, a, h) - k*h*(1.-h);
}

// distance between the ray-marched surface and a point
float surfaceDistance(vec3 point) {
	vec3 sphereCenter = vec3(0., -.2, -.5);
	float sphereRadius = 1.;
	
	vec3 sphere2Center = vec3(0., .3, .6);
	float sphere2Radius = .6;
	
	float planeHeight = 0.;
	
	return smin(
		length(sphereCenter - point) - (sphereRadius - SURFACE_THICKNESS),  // sphere 1
		length(sphere2Center - point) - (sphere2Radius - SURFACE_THICKNESS),  // sphere 2
		//length(max(abs(point - SURFACE_THICKNESS)-vec3(1.), 0.)),  // cube
		//point.y - (planeHeight - SURFACE_THICKNESS),  // plane
		.5
	);
}

// get the length of a ray from origin to surface
float rayMarch(vec3 origin, vec3 normalizedDirection) {
	float distanceFromOrigin = 0.;
	float distanceToSurface;
	
	for (int step = 0; step < MAX_RAYMARCH_STEPS; step++) {
		distanceToSurface = surfaceDistance(origin + normalizedDirection * distanceFromOrigin);
		distanceFromOrigin += distanceToSurface;
		
		if (distanceFromOrigin > MAX_RAYMARCH_DISTANCE || distanceToSurface < SURFACE_THICKNESS)
			break;
	}
	
	return distanceFromOrigin;
}

// normal of the ray-marched surface at point
vec3 surfaceNormal(vec3 point) {
	float distanceToSurface = surfaceDistance(point);
	return normalize(vec3(
		distanceToSurface - surfaceDistance(vec3(point.x - SURFACE_THICKNESS, point.y, point.z)),
		distanceToSurface - surfaceDistance(vec3(point.x, point.y - SURFACE_THICKNESS, point.z)),
		distanceToSurface - surfaceDistance(vec3(point.x, point.y, point.z - SURFACE_THICKNESS))
	));
}

/*
// light intensity at point of the ray-marched surface
float surfaceLight(vec3 point) {
	vec3 pointLightPosition = vec3(iMouse.x/80.-5., iMouse.y/80.+1., 0.);
	
	vec3 normalizedLightDirection = normalize(point - pointLightPosition);
	vec3 normal = surfaceNormal(point);
	
	float lightIntensity = max(0., dot(normal, -normalizedLightDirection));
	
	bool isShaded = rayMarch(point + (normal * SURFACE_THICKNESS * 2.), -normalizedLightDirection) < MAX_RAYMARCH_DISTANCE;
	if (isShaded)
		lightIntensity *= .3;
	
	return lightIntensity;
}
*/


varying vec3 rayOrigin;
varying flat mat4 modelViewMatrix;

void vertex() {
	rayOrigin = (INV_VIEW_MATRIX * vec4(0, 0, 0, 1)).xyz;
	modelViewMatrix = MODELVIEW_MATRIX;

	// cull points outside of the bounding box
	VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.)).xyz;
	//VERTEX = (VIEW_MATRIX * vec4(VERTEX, 1)).xyz;
	
	//NORMAL = (MODELVIEW_MATRIX * vec4(VERTEX, 0.0)).xyz;
	//BINORMAL = (MODELVIEW_MATRIX * vec4(VERTEX, 0.0)).xyz;
	//TANGENT = (MODELVIEW_MATRIX * vec4(VERTEX, 0.0)).xyz;
}

void fragment() {
	//vec3 rayOrigin = (INV_VIEW_MATRIX * vec4(0., 0., 0., 1.)).xyz;
	vec3 rayDirection = normalize((INV_VIEW_MATRIX * vec4(VERTEX, 1.)).xyz - rayOrigin);

	float distanceFromOrigin = rayMarch(rayOrigin, rayDirection);

	// check if the camera is below the surface
	if (distanceFromOrigin < SURFACE_THICKNESS)
		discard;

	// check wether the ray hit the surface or not
	if (distanceFromOrigin >= MAX_RAYMARCH_DISTANCE)
		discard;
	
	vec3 surfacePoint = rayOrigin + rayDirection * distanceFromOrigin;
	vec4 viewSpaceSurfacePoint = VIEW_MATRIX * vec4(surfacePoint, 1.);
	vec4 clipSpaceSurfacePoint = PROJECTION_MATRIX * viewSpaceSurfacePoint;
	
	ALBEDO = vec3(1);//vec3(.2, .8, 0.);
	NORMAL = (VIEW_MATRIX * vec4(surfaceNormal(surfacePoint), 0.)).xyz;
	
	// Godot 3
	//DEPTH = (clipSpaceSurfacePoint.z / clipSpaceSurfacePoint.w) * .5 + .5;

	// Godot 4
	DEPTH = clipSpaceSurfacePoint.z / clipSpaceSurfacePoint.w;
	
	// DEBUG
	//ALBEDO = vec3(distanceFromOrigin);
	//ALBEDO = vec3(DEPTH);
	//ALBEDO = surfacePoint.xyz;
	//ALBEDO = surfaceNormal(surfacePoint);
	//ALBEDO = (INV_VIEW_MATRIX * vec4(NORMAL, 0.)).xyz;
}

//void light() {
//	DIFFUSE_LIGHT += dot(NORMAL, LIGHT) * ATTENUATION * ALBEDO;
//
//	// DEBUG
//	//DIFFUSE_LIGHT = ALBEDO;
//}
