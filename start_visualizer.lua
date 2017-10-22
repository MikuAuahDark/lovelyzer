local AquaShine = ...
local fft = require("fft")
local Vis = {}

do
	local channels
	
	local function getsample_safe(sound_data, pos)
		local _, sample = pcall(sound_data.getSample, sound_data, pos)
		
		if _ == false then
			return 0
		end
		
		return sample
	end
	
	function Vis.GetCurrentAudioSample(size)
		size = size or 1
		
		local audio = Vis.SoundDataAudio.sounddata
		local sample_list = {}
		
		if not(audio) then
			for i = 1, size do
				sample_list[#sample_list + 1] = {0, 0}
			end
			
			return sample_list
		end
		
		if not(channels) then
			channels = audio:getChannels()
		end
		
		local pos = Vis.Audio:tell("samples")
		
		if channels == 1 then
			for i = pos, pos + size - 1 do
				-- Mono
				local sample = getsample_safe(audio, i)
				
				sample_list[#sample_list + 1] = {sample, sample}
			end
		elseif channels == 2 then
			for i = pos, pos + size - 1 do
				-- Stereo
				sample_list[#sample_list + 1] = {
					getsample_safe(audio, i * 2),
					getsample_safe(audio, i * 2 + 1),
				}
			end
		end
		
		return sample_list
	end
end

local lc = {}
local rc = {}
local lcn = {}
local rcn = {}
local result_fft = {lcn, rcn}
function Vis.FFTSample(waveform)
	local n = math.floor(#waveform * 0.5)
	for i = 1, #waveform do
		lc[i] = fft.complex.new(waveform[i][1])
		rc[i] = fft.complex.new(waveform[i][2])
	end
	
	local lcfft, rcfft = fft.fft(lc), fft.fft(rc)
	
	for i = 1, n do
		lcn[i] = math.sqrt(lcfft[i].r * lcfft[i].r + lcfft[i].i * lcfft[i].i) / n
		rcn[i] = math.sqrt(rcfft[i].r * rcfft[i].r + rcfft[i].i * rcfft[i].i) / n
	end
	
	return result_fft
end

function Vis.Start(arg)
	local audio_loader = AquaShine.LoadModule("audio_loader")
	local vislist = AquaShine.LoadModule("visscan")
	local input = assert(AquaShine.GetCommandLineConfig("i") or AquaShine.GetCommandLineConfig("input"), "Input file missing")
	local vis = assert(AquaShine.GetCommandLineConfig("visualizer") or arg[1], "Visualizer name missing")
	
	Vis.SoundDataAudio = audio_loader(input)
	Vis.Audio = love.audio.newSource(Vis.SoundDataAudio.sounddata)
	Vis.CurrentVisualizer = assert(vislist[vis], "Invalid visualizer specificed")()
	Vis.VisualizerInfo = Vis.CurrentVisualizer:setup(Vis.SoundDataAudio, {width = 1280, height = 720})
	assert(type(Vis.VisualizerInfo.fftsize) == "number" and Vis.VisualizerInfo.fftsize > 0, "Invalid fftsize specificed")
	
	Vis.Audio:play()
end

function Vis.Update(deltaT)
	local samples = Vis.GetCurrentAudioSample(Vis.VisualizerInfo.fftsize)
	local fftsmp = nil
	
	if Vis.VisualizerInfo.spectrum then
		fftsmp = Vis.FFTSample(samples)
	end
	
	return Vis.CurrentVisualizer:update(deltaT, samples, fftsmp)
end

function Vis.Draw()
	return Vis.CurrentVisualizer:draw()
end

return Vis
