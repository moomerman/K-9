package assets

import k2 "../.deps/github.com/karl-zylinski/karl2d"

SFX_VOLUME :: 0.5

title_music := #load("music/title.ogg")
level_music := #load("music/level.ogg")
sprites: k2.Texture

load_music :: proc(bytes: []u8) -> k2.Audio_Stream {
	music := k2.load_audio_stream_from_bytes(bytes)
	k2.set_audio_stream_loop(music, true)
	k2.set_audio_stream_volume(music, 0.30)
	return music
}

load_sfx :: proc(bytes: []u8) -> k2.Sound {
	s := k2.load_sound_from_bytes(bytes)
	k2.set_sound_volume(s, SFX_VOLUME)
	return s
}

load_textures :: proc() {
	sprites = k2.load_texture_from_bytes(#load("textures/sprites.png"))
	k2.set_texture_filter(sprites, .Point)
}

sounds: struct {
	move:   k2.Sound,
	hit:    k2.Sound,
	hurt:   k2.Sound,
	pickup: k2.Sound,
	death:  k2.Sound,
	win:    k2.Sound,
	wake:   k2.Sound,
}

load_sounds :: proc() {
	sounds.move = load_sfx(#load("sfx/move.wav"))
	sounds.hit = load_sfx(#load("sfx/hit.wav"))
	sounds.hurt = load_sfx(#load("sfx/hurt.wav"))
	sounds.pickup = load_sfx(#load("sfx/pickup.wav"))
	sounds.death = load_sfx(#load("sfx/death.wav"))
	sounds.win = load_sfx(#load("sfx/win.wav"))
}
