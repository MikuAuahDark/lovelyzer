-- Audio loader wrapper
-- Uses FFmpeg API, FFmpeg commandline, or fallback to LOVE Decoder

local AquaShine = ...
local ffi = require("ffi")
local love = require("love")
local audio_loader

local function has_ffmpeg_cli()
	if jit.os == "Windows" then
		return os.execute("where ffmpeg") == 0
	elseif os.execute() == 1 then
		return os.execute("which ffmpeg") == 0
	else
		return false
	end
end

if AquaShine.FFmpegExt then
	-- Use FFX (FFmpeg API)
	local avutil = AquaShine.FFmpegExt.avutil
	local swresample = AquaShine.FFmpegExt.swresample
	local avcodec = AquaShine.FFmpegExt.avcodec
	local avformat = AquaShine.FFmpegExt.avformat
	local swscale = AquaShine.FFmpegExt.swscale
	
	local function delete_frame(frame)
		local x = ffi.new("AVFrame*[1]")
		x[0] = frame
		
		avutil.av_frame_free(x)
	end
	
	function audio_loader(path)
		-- Contains:
		-- - sounddata
		-- - title*
		-- - artist*
		-- - album*
		-- - cover_art*
		-- * - optional
		local output = {}
		local tempfmtctx = ffi.new("AVFormatContext*[1]")
		
		if avformat.avformat_open_input(tempfmtctx, path, nil, nil) < 0 then
			error("Failed to load audio: failed to load file", 2)
		end
		
		if avformat.avformat_find_stream_info(tempfmtctx[0], nil) < 0 then
			avformat.avformat_close_input(tempfmtctx)
			error("Failed to load audio: avformat_find_stream_info failed", 2)
		end
		
		local vididx, audioidx
		for i = 1, tempfmtctx[0].nb_streams do
			local codec_type = tempfmtctx[0].streams[i - 1].codec.codec_type
			
			if codec_type == "AVMEDIA_TYPE_AUDIO" and not(audioidx) then
				audioidx = i - 1
			elseif codec_type == "AVMEDIA_TYPE_VIDEO" and not(vididx) then
				vididx = i - 1
			end
			
			if audioidx and vididx then break end
		end
		
		if not(audioidx) then
			avformat.avformat_close_input(tempfmtctx)
			error("Failed to load audio: audio stream not found", 2)
		end
		
		-- Read tags (metadata)
		do
			local tag = nil
			tag = avutil.av_dict_get(tempfmtctx[0].metadata, "", tag, 2)
			
			while tag ~= nil do
				local k, v = ffi.string(tag.key):lower(), ffi.string(tag.value)
				output[k] = v
				tag = avutil.av_dict_get(tempfmtctx[0].metadata, "", tag, 2)
			end
		end
		
		local audiostream = tempfmtctx[0].streams[audioidx]
		local acodec, acctx, aframe, SwrCtx
		local videostream, vcodec, vcctx, vframe, vframergb, vimgdt, SwsCtx
		
		acodec = avcodec.avcodec_find_decoder(audiostream.codec.codec_id)
		if acodec == nil then
			avformat.avformat_close_input(tempfmtctx)
			error("Failed to load audio: no suitable codec found", 2)
		end
		
		acctx = avcodec.avcodec_alloc_context3(acodec)
		if avcodec.avcodec_copy_context(acctx, audiostream.codec) < 0 then
			avcodec.avcodec_close(acctx)
			avformat.avformat_close_input(tempfmtctx)
			error("Failed to load audio: avcodec_copy_context failed", 2)
		end
		
		if avcodec.avcodec_open2(acctx, acodec, nil) < 0 then
			avcodec.avcodec_close(acctx)
			avformat.avformat_close_input(tempfmtctx)
			error("Failed to load audio: avcodec_open2 failed", 2)
		end
		
		SwrCtx = ffi.new("SwrContext*[1]")
		SwrCtx[0] = swresample.swr_alloc_set_opts(nil,
			3,
			"AV_SAMPLE_FMT_S16",
			44100,
			audiostream.codec.channel_layout,
			audiostream.codec.sample_fmt,
			audiostream.codec.sample_rate,
			0, nil
		)
		
		if swresample.swr_init(SwrCtx[0]) < 0 then
			avcodec.avcodec_close(acctx)
			avformat.avformat_close_input(tempfmtctx)
			error("Failed to load audio: swresample init failed", 2)
		end
		
		aframe = avutil.av_frame_alloc()
		
		-- If there's video stream that means there's cover art
		if vididx then
			videostream = tempfmtctx[0].streams[vididx]
			vcodec = avcodec.avcodec_find_decoder(videostream.codec.codec_id)
			
			if vcodec then
				vcctx = avcodec.avcodec_alloc_context3(vcodec)
				
				if avcodec.avcodec_copy_context(vcctx, videostream.codec) >= 0 then
					if avcodec.avcodec_open2(vcctx, vcodec, nil) >= 0 then
						vframe = avutil.av_frame_alloc()
						vframergb = avutil.av_frame_alloc()
						vimgdt = love.image.newImageData(vcctx.width, vcctx.height)
						
						avutil.av_image_fill_arrays(
							vframergb.data,
							vframergb.linesize,
							ffi.cast("uint8_t*", vimgdt:getPointer()),
							"AV_PIX_FMT_RGBA",
							vcctx.width,
							vcctx.height, 1
						)
						SwsCtx = swscale.sws_getContext(
							vcctx.width,
							vcctx.height,
							vcctx.pix_fmt,
							vcctx.width,
							vcctx.height,
							"AV_PIX_FMT_RGBA",		-- Don't forget that ImageData expects RGBA values
							2, 						-- SWS_BILINEAR
							nil, nil, nil
						)
					else
						avcodec.avcodec_close(vcctx)
						vididx = nil
					end
				else
					avcodec.avcodec_close(vcctx)
					vididx = nil
				end
			end
		end
		
		-- Init SoundData
		local samplecount_love = math.ceil((tonumber(tempfmtctx[0].duration) / 1000000 + 1) * 44100)
		output.sounddata = love.sound.newSoundData(samplecount_love, 44100, 16, 2)
		
		local framefinished = ffi.new("int[1]")
		local packet = ffi.new("AVPacket[1]")
		local outbuf = ffi.new("uint8_t*[2]")
		local out_size = samplecount_love
		outbuf[0] = ffi.cast("uint8_t*", output.sounddata:getPointer())
		
		-- Decode audio and cover art image
		local readframe = avformat.av_read_frame(tempfmtctx[0], packet)
		while readframe >= 0 do
			if packet[0].stream_index == audioidx then
				local decodelen = avcodec.avcodec_decode_audio4(acctx, aframe, framefinished, packet)
				
				if decodelen < 0 then
					delete_frame(aframe)
					avcodec.av_free_packet(packet)
					swresample.swr_free(SwrCtx)
					avcodec.avcodec_close(acctx)
					
					if vididx then
						swscale.sws_freeContext(SwsCtx)
						delete_frame(vframe)
						delete_frame(vframergb)
						avcodec.avcodec_close(vcodec)
					end
					
					avformat.avformat_close_input(tempfmtctx)
					
					error("Failed to load audio: decoding error", 2)
				end
				
				if framefinished[0] > 0 then
					local samples = swresample.swr_convert(SwrCtx[0],
						outbuf, aframe.nb_samples,
						ffi.cast("const uint8_t**", aframe.extended_data),
						aframe.nb_samples
					)
					
					if samples < 0 then
						delete_frame(aframe)
						avcodec.av_free_packet(packet)
						swresample.swr_free(SwrCtx)
						avcodec.avcodec_close(acctx)
					
						if vididx then
							swscale.sws_freeContext(SwsCtx)
							delete_frame(vframe)
							delete_frame(vframergb)
							avcodec.avcodec_close(vcctx)
						end
						
						avformat.avformat_close_input(tempfmtctx)
						
						error("Failed to load audio: resample error", 2)
					end
					
					outbuf[0] = outbuf[0] + samples * 4
					out_size = out_size - samples
				end
			elseif vididx and packet[0].stream_index == vididx then
				avcodec.avcodec_decode_video2(vcctx, vframe, framefinished, packet)
				
				if framefinished[0] > 0 then
					-- Cover art decoded
					swscale.sws_scale(SwsCtx,
						ffi.cast("const uint8_t *const *", vframe.data),
						vframe.linesize, 0, vcctx.height,
						vframergb.data, vframergb.linesize
					)
					
					output.cover_art = love.graphics.newImage(vimgdt)
					swscale.sws_freeContext(SwsCtx)
					delete_frame(vframe)
					delete_frame(vframergb)
					avcodec.avcodec_close(vcctx)
					vididx = nil
				end
			end
			
			avcodec.av_free_packet(packet)
			readframe = avformat.av_read_frame(tempfmtctx[0], packet)
		end
		
		-- Flush buffer
		swresample.swr_convert(SwrCtx[0], outbuf, out_size, nil, 0)
		
		-- Free
		delete_frame(aframe)
		avcodec.av_free_packet(packet)
		swresample.swr_free(SwrCtx)
		avcodec.avcodec_close(acctx)
		avformat.avformat_close_input(tempfmtctx)
		
		return output
	end
elseif has_ffmpeg_cli() and not(select(2, pcall(io.popen)):find("not supported")) then
	function audio_loader(path)
		local tempname = os.tmpname()
		local ffmeta = os.execute(string.format("ffmpeg -i %q -f ffmetadata %s", path, tempname))
		
		if ffmeta == 1 then
			os.remove(tempname)
			error("Failed to load audio", 2)
		end
		
		local output = {}
		
		-- Read metadata
		for line in io.lines(tempname) do
			if #line > 0 and line ~= ";FFMETADATA1" then
				local key, value = line:match("([^=]+)=(.+)")
				
				if key and value then
					output[key:lower()] = value
				end
			end
		end
		os.remove(tempname)
		
		-- Load audio
		local audio = io.popen(string.format("ffmpeg -i %q -c:a pcm_s16le -ar 44100 -ac 2 -f s16le -", path), jit.os == "Windows" and "rb" or "r")
		local audiodata = audio:read("*a")
		audio:close()
		
		output.sounddata = love.sound.newSoundData(#audiodata / 4, 44100, 16, 2)
		ffi.copy(ffi.cast("uint8_t*", output.sounddata:getPointer()), audiodata)
		
		-- Try to load cover art
		local cvart = os.execute(string.format("ffmpeg -i %q -c:v png -f image2 %s", path, tempname))
		
		if cvart == 1 then
			os.remove(tempname)
		else
			local f = io.open(tempname, "rb")
			output.cover_art = love.graphics.newImage(love.filesystem.newFileData(f:read("*a"), "_.png"))
			f:close()
			os.remove(tempname)
		end
		
		return output
	end
else
	-- Fallback to LOVE loader
	function audio_loader(path)
		local output = {}
		local f = assert(io.open(path, "rb"))
		
		output.sounddata = love.sound.newSoundData(love.filesystem.newFileData(f:read("*a"), path))
		f:close()
		return output
	end
end

return audio_loader
