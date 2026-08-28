package assets

import k2 "../.deps/github.com/karl-zylinski/karl2d"

SFX_VOLUME :: 0.5
MUSIC_VOLUME :: 0.30

title_music := #load("music/title.ogg")
level_music := #load("music/level.ogg")
sprites: k2.Texture

load_music :: proc(bytes: []u8) -> k2.Audio_Stream {
	return k2.load_audio_stream_from_bytes(bytes)
}

play_music :: proc(music: k2.Audio_Stream) -> k2.Sound {
	return k2.play_audio_stream(music, volume = MUSIC_VOLUME, loop = true)
}

play_sfx :: proc(clip: k2.Audio_Clip) {
	k2.play_audio_clip(clip, volume = SFX_VOLUME)
}

load_textures :: proc() {
	sprites = k2.load_texture_from_bytes(#load("textures/sprites.png"))
	k2.set_texture_filter(sprites, .Point)
}

sounds: struct {
	move:   k2.Audio_Clip,
	hit:    k2.Audio_Clip,
	hurt:   k2.Audio_Clip,
	pickup: k2.Audio_Clip,
	death:  k2.Audio_Clip,
	win:    k2.Audio_Clip,
	wake:   k2.Audio_Clip,
}

load_sounds :: proc() {
	sounds.move = k2.load_audio_clip_from_bytes(#load("sfx/move.wav"))
	sounds.hit = k2.load_audio_clip_from_bytes(#load("sfx/hit.wav"))
	sounds.hurt = k2.load_audio_clip_from_bytes(#load("sfx/hurt.wav"))
	sounds.pickup = k2.load_audio_clip_from_bytes(#load("sfx/pickup.wav"))
	sounds.death = k2.load_audio_clip_from_bytes(#load("sfx/death.wav"))
	sounds.win = k2.load_audio_clip_from_bytes(#load("sfx/win.wav"))
}
