-- Lyrics (SubRip subtitle) loader

local class = require("30log")
local slfs, lfs = pcall(require, "love.filesystem")
local lyrics = {}

local function startParse(lines)
	local timing_list = {}
	
	-- Skip single line
	local line = lines()
	-- Loop
	while line do
		local data = {}
		local timing = lines()
		local h, m, s, ms = timing:match("(%d%d+):(%d%d):(%d%d),(%d%d%d)")
		
		data.time = tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(s) + tonumber(ms) * 0.001
		h, m, s, ms = timing:match("(%d%d+):(%d%d):(%d%d),(%d%d%d)", timing:find("-->", 1, true) + 3)
		local endtime = tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(s) + tonumber(ms) * 0.001
		
		-- Read contents
		local list = {}
		local line = lines()
		while #line > 0 do
			list[#list + 1] = line
			line = lines()
		end
		data.content = table.concat(list, " ")	-- Space separated
		
		if endtime ~= data.time then
			-- Make it as separated timing points
			local dummy = {}
			
			timing_list[#timing_list + 1] = data
			timing_list[#timing_list + 1] = dummy
			dummy.time = endtime
			dummy.content = ""
		else
			-- It's same
			timing_list[#timing_list + 1] = data
		end
	end
	
	return timing_list
end

function lyrics.loadFile(path)
	return startParse(io.lines(path))
end

if slfs then
	function lyrics.loadFileLOVE(path)
		return startParse(lfs.lines(path))
	end
end

return lyrics
