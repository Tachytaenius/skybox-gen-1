-- Could just draw planes and rotate them to face the camera...

local mathsies = require("lib.mathsies")
local mat4 = mathsies.mat4
local vec3 = mathsies.vec3
local quat = mathsies.quat

local tau = math.pi * 2
local forwardVector = vec3(0, 0, 1)
local upVector = vec3(0, 1, 0)
local rightVector = vec3(1, 0, 0)
local skyColour = {0, 0, 0}
local verticalFOV = 90 -- What happens if I change vertical FOV after rendering the cubemap? Does the whole thing change? Ideally not.
local farDistance = 1000
local nearDistance = 0.01

local mouseDx, mouseDy
local stars, camera
local canvas, dummyTexture, starShader

local function normaliseOrZero(v)
	local zeroVector = vec3()
	return v == zeroVector and zeroVector or vec3.normalise(v)
end

local function limitVectorLength(v, m)
	local l = #v
	if l > m then
		return normaliseOrZero(v) * m
	end
	return vec3.clone(v)
end

local function randomSphere(r)
	-- TEMP/TODO
	return vec3.fromAngles(love.math.random() * tau, love.math.random() * tau) * r * love.math.random() ^ (1 / 3)
end

function love.load(args)
	local numStars = tonumber(args[1]) or 100
	local starSphereRadius = tonumber(args[2]) or 200

	stars = {}
	for i = 1, numStars do
		stars[i] = {
			position = randomSphere(starSphereRadius),
			radius = love.math.random () * 2 + 1,
			colour = {1, 1, 1}
		}
	end

	camera = {
		position = vec3(),
		orientation = quat()
	}

	canvas = love.graphics.newCanvas(love.graphics.getDimensions())
	dummyTexture = love.graphics.newImage(love.image.newImageData(1, 1))
	starShader = love.graphics.newShader("star.glsl")
end

function love.mousemoved(_, _, dx, dy)
	mouseDx, mouseDy = dx, dy
end

function love.mousepressed()
	love.mouse.setRelativeMode(not love.mouse.getRelativeMode())
end

function love.update(dt)
	if not (mouseDx and mouseDy) or love.mouse.getRelativeMode() == false then
		mouseDx = 0
		mouseDy = 0
	end

	local speed = love.keyboard.isDown("lshift") and 20 or 4
	local translation = vec3()
	if love.keyboard.isDown("d") then translation = translation + rightVector end
	if love.keyboard.isDown("a") then translation = translation - rightVector end
	if love.keyboard.isDown("e") then translation = translation + upVector end
	if love.keyboard.isDown("q") then translation = translation - upVector end
	if love.keyboard.isDown("w") then translation = translation + forwardVector end
	if love.keyboard.isDown("s") then translation = translation - forwardVector end
	camera.position = camera.position + vec3.rotate(normaliseOrZero(translation) * speed, camera.orientation) * dt

	local maxAngularSpeed = tau * 2
	local keyboardRotationSpeed = tau / 4
	local keyboardRotationMultiplier = keyboardRotationSpeed / maxAngularSpeed
	local mouseMovementForMaxSpeed = 2.5 -- Move 10 units to rotate by maxAngularSpeed radians per second
	local mouseMovementMultiplier = 1 / (mouseMovementForMaxSpeed * maxAngularSpeed)
	local rotation = vec3()
	if love.keyboard.isDown("k") then rotation = rotation + rightVector * keyboardRotationMultiplier end
	if love.keyboard.isDown("i") then rotation = rotation - rightVector * keyboardRotationMultiplier end
	if love.keyboard.isDown("l") then rotation = rotation + upVector * keyboardRotationMultiplier end
	if love.keyboard.isDown("j") then rotation = rotation - upVector * keyboardRotationMultiplier end
	if love.keyboard.isDown("u") then rotation = rotation + forwardVector * keyboardRotationMultiplier end
	if love.keyboard.isDown("o") then rotation = rotation - forwardVector * keyboardRotationMultiplier end
	rotation = rotation + upVector * mouseDx * mouseMovementMultiplier
	rotation = rotation + rightVector * mouseDy * mouseMovementMultiplier
	camera.orientation = quat.normalise(camera.orientation * quat.fromAxisAngle(limitVectorLength(rotation, 1) * maxAngularSpeed * dt))

	mouseDx, mouseDy = nil, nil
end

function love.draw()
	love.graphics.setCanvas(canvas)
	love.graphics.clear()

	local perspectiveProjectionMatrix = mat4.perspectiveLeftHanded(
		canvas:getWidth() / canvas:getHeight(),
		verticalFOV,
		farDistance,
		nearDistance
	)
	-- local cameraMatrix = mat4.camera(camera.position, camera.orientation)
	local cameraMatrixStationary = mat4.camera(vec3(), camera.orientation)
	-- local worldToScreen = perspectiveProjectionMatrix * cameraMatrixStationary
	local clipToSky = mat4.inverse(perspectiveProjectionMatrix * cameraMatrixStationary)

	starShader:send("forwardVector", {vec3.components(forwardVector)})
	starShader:send("clipToSky", {mat4.components(clipToSky)})
	love.graphics.setShader(starShader)
	for _, star in ipairs(stars) do
		local difference = star.position - camera.position
		local distance = #difference
		local direction = vec3.normalise(difference)
		local angularRadius = math.asin(star.radius / distance)
		starShader:send("starDirection", {vec3.components(direction)})
		starShader:send("starAngularRadius", angularRadius)
		love.graphics.setColor(star.colour)
		love.graphics.draw(dummyTexture, 0, 0, 0, canvas:getDimensions())
	end
	love.graphics.setShader()

	love.graphics.setCanvas()
	love.graphics.draw(canvas, 0, love.graphics.getHeight(), 0, 1, -1)
end
