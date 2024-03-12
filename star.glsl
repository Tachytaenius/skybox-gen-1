const float tau = 6.28318530718;

varying vec3 directionPreNormalise;

#ifdef VERTEX

uniform mat4 clipToSky;

vec4 position(mat4 loveTransform, vec4 vertexPosModel) {
	directionPreNormalise = (
		clipToSky * vec4(
			VertexTexCoord.st * 2.0 - 1.0,
			-1.0,
			1.0
		)
	).xyz;
	return loveTransform * vertexPosModel;
}

#endif

#ifdef PIXEL

uniform vec3 forwardVector;

uniform vec3 starDirection;
uniform float starAngularRadius;

vec3 axisAngleBetweenVectors(vec3 a, vec3 b) {
	float angle = acos(dot(a, b));
	vec3 axis = normalize(cross(a, b)); // Forgetting to normalise this had some crazy warping results, going from square to circle as I moved around a star
	return angle * axis;
}

// Quaternions aren't actually vectors, of course. They're scalars.
// At least, I think they are, since they're a generalisation of complex numbers,
// and I'd say a complex number is a scalar, albeit a curious one...

vec4 quatFromAxisAngle(vec3 v) {
	vec3 axis = normalize(v);
	float angle = length(v);
	float s = sin(angle / 2.0);
	float c = cos(angle / 2.0);
	return normalize(vec4(axis * s, c));
}

vec3 rotate(vec3 v, vec4 q) {
	vec3 uv = cross(q.xyz, v);
	vec3 uuv = cross(q.xyz, uv);
	return v + ((uv * q.w) + uuv) * 2.0;
}

float squarePolar(float angle) {
	return min(
		1.0 / (
			abs(cos(angle + tau / 8.0))
		),
		1.0 / (
			abs(sin(angle + tau / 8.0))
		)
	) / 2.0;
}
 
vec4 effect(vec4 colour, sampler2D image, vec2 textureCoords, vec2 windowCoords) {
	vec3 direction = normalize(directionPreNormalise);

	// The idea:
	// Get the rotation from the star direction to the forward vector and rotate the sky direction and star direction by it (star direction now can be replaced with forward vector).
	// What you are left with is a situation where the rotation from the sky direction to the star direction is preserved (I'm pretty sure), but you can now calculate an angle from the [rotated] star direction to the [rotated] sky direction, by-- since the rotated star direction is on a "pole" of the unit sphere (vec3(0, 0, 1), the forward vector)-- flattening the rotated sky direction onto a plane (by removing its z coordinate) and getting the angle of the remaining x and y coordinates.
	// Now that we have an idea of angles, we can make a square. We just use the angle as the input to a polar function that makes a square.

	// One problem: the star rotates as I move around it. I feel the solution may involve adding a corrective term to the angle derived from something based on the up vector (rotate the up vector by the rotation, then do something with it?), which should lie on the "equator" of the unit sphere (as in, the points with z = 0). Is this happening because the rotation I said was preserved isn't?

	vec3 directionRotated = rotate(
		direction,
		quatFromAxisAngle(
			axisAngleBetweenVectors(starDirection, forwardVector)
		)
	);
	float squaringAngle = atan(directionRotated.y, directionRotated.x);
	float effectiveStarAngularRadius = starAngularRadius * squarePolar(squaringAngle);

	float angleDistance = acos(dot(direction, starDirection));

	if (angleDistance <= effectiveStarAngularRadius) {
		return colour;
	}
	
	return vec4(0.0);
}

#endif
