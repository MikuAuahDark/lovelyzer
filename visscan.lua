local AquaShine = ...
local love = require("love")
local class = require("30log")
local vislist = {}

local visclass = class("Visualizer.Base", {
	setup = function(songinfo, screeninfo)
		-- songinfo = {
		--     filename
		--     artist
		--     genre
		--     title
		--     album
		--     cover_art
		-- }
		-- screeninfo = {
		--     width
		--     height
		-- }
		error("Cannot construct abstract class", 2)
		-- return {
		--     fftsize
		--     spectrum
		-- }
	end,
	update = function(deltaT, waveform, spectrum)
		error("Pure virtual method update", 2)
	end,
	draw = function()
		error("Pure virtual method draw", 2)
	end
})

for _, f in ipairs(love.filesystem.getDirectoryItems("visualizer/")) do
	local name = "visualizer/"..f
	if love.filesystem.isDirectory(name) then
		local s, msg = love.filesystem.load(name.."/start.lua")
		
		if s then
			s, msg = pcall(s, AquaShine, visclass, name)
			
			if s then
				vislist[f] = msg
			else
				AquaShine.Log("visscan", "Failed to load visualizer %s: %s", f, msg)
			end
		else
			AquaShine.Log("visscan", "Failed to load visualizer %s: %s", f, msg)
		end
	end
end

return vislist
