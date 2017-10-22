-- Tweening lirary based on kikito/tween.lua
-- but attempt to eliminate `pairs` call on every update

local class = require("30log")
local tween = class("tween")

tween.easing = {}

-- linear
function tween.easing.linear(t, b, c, d) return c * t / d + b end

-- quad
function tween.easing.inQuad(t, b, c, d) return c * pow(t / d, 2) + b end
function tween.easing.outQuad(t, b, c, d)
	t = t / d
	return -c * t * (t - 2) + b
end
function tween.easing.inOutQuad(t, b, c, d)
	t = t / d * 2
	if t < 1 then return c / 2 * pow(t, 2) + b end
	return -c / 2 * ((t - 1) * (t - 3) - 1) + b
end
function tween.easing.outInQuad(t, b, c, d)
	if t < d / 2 then return outQuad(t * 2, b, c / 2, d) end
	return inQuad((t * 2) - d, b + c / 2, c / 2, d)
end

-- cubic
function tween.easing.inCubic (t, b, c, d) return c * pow(t / d, 3) + b end
function tween.easing.outCubic(t, b, c, d) return c * (pow(t / d - 1, 3) + 1) + b end
function tween.easing.inOutCubic(t, b, c, d)
	t = t / d * 2
	if t < 1 then return c / 2 * t * t * t + b end
	t = t - 2
	return c / 2 * (t * t * t + 2) + b
end
function tween.easing.outInCubic(t, b, c, d)
	if t < d / 2 then return outCubic(t * 2, b, c / 2, d) end
	return inCubic((t * 2) - d, b + c / 2, c / 2, d)
end

-- quart
function tween.easing.inQuart(t, b, c, d) return c * pow(t / d, 4) + b end
function tween.easing.outQuart(t, b, c, d) return -c * (pow(t / d - 1, 4) - 1) + b end
function tween.easing.inOutQuart(t, b, c, d)
	t = t / d * 2
	if t < 1 then return c / 2 * pow(t, 4) + b end
	return -c / 2 * (pow(t - 2, 4) - 2) + b
end
function tween.easing.outInQuart(t, b, c, d)
	if t < d / 2 then return outQuart(t * 2, b, c / 2, d) end
	return inQuart((t * 2) - d, b + c / 2, c / 2, d)
end

