package main

import k2 ".deps/github.com/karl-zylinski/karl2d"

import hm "core:container/handle_map"
import "core:fmt"
import "core:math"

import "assets"
import g "game"

TILE_SIZE :: 16

game: g.Game
music: k2.Audio_Stream

init :: proc() {
	k2.init(1000, 600, "K-9", {window_mode = .Windowed_Resizable})
	assets.load_sounds()
	assets.load_textures()
	music = assets.load_music(assets.level_music)
	k2.play_audio_stream(music)
	g.init(&game)
}

step :: proc() -> bool {
	if !k2.update() {return false}
	dt := k2.get_frame_time()

	{ 	//input
		handle_input()
	}

	{ 	// update
		g.update(&game, dt)
		play_event_sounds()
		k2.update_audio_stream(music)
	}

	{ 	// render
		k2.clear(k2.BLACK)
		draw_game()
		draw_hud()
		draw_overlay()
		k2.present()
	}

	free_all(context.temp_allocator)
	return true
}

handle_input :: proc() {
	if game.won || game.lost {
		if k2.key_went_down(.Space) {
			g.advance(&game)
		}
	} else {
		if k2.key_went_down(.Up) {
			g.player_move(&game, .north)
		} else if k2.key_went_down(.Down) {
			g.player_move(&game, .south)
		} else if k2.key_went_down(.Left) {
			g.player_move(&game, .west)
		} else if k2.key_went_down(.Right) {
			g.player_move(&game, .east)
		} else if k2.key_went_down(.N1) {
			g.player_drop_bone(&game)
		}
	}
}

draw_game :: proc() {
	sw := f32(k2.get_screen_width())
	sh := f32(k2.get_screen_height())

	world_w := f32(game.level.width * TILE_SIZE)
	world_h := f32(game.level.height * TILE_SIZE)

	zoom := math.floor(sh / world_h)
	if zoom < 1 {zoom = 1}

	play_w := world_w * zoom
	play_h := world_h * zoom
	offset := k2.Vec2{(sw - play_w) / 2, (sh - play_h) / 2}

	border_w :: 4
	border := k2.Rect {
		offset.x - border_w,
		offset.y - border_w,
		play_w + border_w * 2,
		play_h + border_w * 2,
	}
	k2.draw_rect_outline(border, border_w, k2.DARK_BLUE)

	cam := k2.Camera {
		offset = offset,
		zoom   = zoom,
	}
	k2.set_camera(cam)
	defer k2.set_camera(nil)

	draw_level()

	it := hm.iterator_make(&game.level.entities)
	for e, _ in hm.iterate(&it) {
		draw_entity(e)
	}
}

draw_level :: proc() {
	for y in 0 ..< game.level.height {
		for x in 0 ..< game.level.width {
			tile := game.level.tiles[y * game.level.width + x]
			tile_color: k2.Color
			switch tile {
			case .wall:
				tile_color = k2.DARK_GRAY
			case .floor:
				tile_color = k2.LIGHT_BLUE
			}
			rect := k2.Rect {
				x = f32(x * TILE_SIZE),
				y = f32(y * TILE_SIZE),
				w = TILE_SIZE,
				h = TILE_SIZE,
			}
			k2.draw_rect(rect, tile_color)
		}
	}
}

draw_entity :: proc(e: ^g.Entity) {
	entity_color: k2.Color
	switch e.kind {
	case .key:
		entity_color = k2.WHITE
	case .exit:
		if game.level.has_key {
			pulse := 0.5 + 0.5 * math.sin(e.anim_timer * 6)
			entity_color = k2.Color{u8(50 * pulse), 200, u8(50 * pulse), 255}
		} else {
			entity_color = k2.Color{0, 100, 0, 255}
		}
	case .bone:
		entity_color = k2.BLUE
	case .player, .patrol_dog, .guard_dog, .sleeping_dog:
	}

	t := f32(0)
	if g.MOVE_DURATION > 0 {
		t = math.min(e.move_timer / g.MOVE_DURATION, 1.0)
	}

	ease := 1.0 - (1.0 - t) * (1.0 - t)
	draw_x := math.lerp(f32(e.prev_pos.x), f32(e.pos.x), ease) * TILE_SIZE
	draw_y := math.lerp(f32(e.prev_pos.y), f32(e.pos.y), ease) * TILE_SIZE

	if e.kind == .key || e.kind == .exit || e.kind == .bone {
		bob := math.sin(e.anim_timer * 4) * 2
		draw_y += bob
	}

	if source, has_sprite := sprite_source(e); has_sprite {
		flash_grow := f32(0)
		tint := k2.WHITE
		if e.flash_timer > 0 {
			flash_grow = 4
			tint = k2.Color{255, 100, 100, 255}
		}

		dest := k2.Rect {
			x = draw_x - flash_grow,
			y = draw_y - flash_grow,
			w = TILE_SIZE + flash_grow * 2,
			h = TILE_SIZE + flash_grow * 2,
		}
		k2.draw_texture_fit(assets.sprites, source, dest, tint = tint)
	} else {
		color := entity_color
		if e.flash_timer > 0 {
			color = k2.WHITE
		}
		rect := k2.Rect {
			x = draw_x,
			y = draw_y,
			w = TILE_SIZE,
			h = TILE_SIZE,
		}
		k2.draw_rect(rect, color)
	}
}

draw_hud :: proc() {
	player_hp := g.get_entity_hp(&game, game.player_handle)
	hud_text := fmt.tprintf("LEVEL %d   HP %d", game.level_number, player_hp)
	k2.draw_text(hud_text, {16, 16}, 24, k2.WHITE)

	if game.bones > 0 {
		inv := fmt.tprintf("1. Bones: %d", game.bones)
		k2.draw_text(inv, {16, 48}, 24, k2.WHITE)
	}
}

draw_overlay :: proc() {
	if game.won || game.lost {
		sw := f32(k2.get_screen_width())
		sh := f32(k2.get_screen_height())

		k2.draw_rect({0, 0, sw, sh}, k2.Color{0, 0, 0, 180})

		msg: string
		if game.won {
			msg = fmt.tprintf("LEVEL %d COMPLETE — SPACE TO CONTINUE", game.level_number)
		} else {
			msg = fmt.tprintf("DIED ON LEVEL %d — SPACE TO RESTART", game.level_number)
		}

		size := k2.measure_text(msg, 32)
		pos := k2.Vec2{(sw - size.x) / 2, (sh - size.y) / 2}
		k2.draw_text(msg, pos, 32, k2.WHITE)
	}
}

play_event_sounds :: proc() {
	for event in game.events {
		switch event {
		case .player_moved:
			k2.play_sound(assets.sounds.move)
		case .attack_landed:
			k2.play_sound(assets.sounds.hit)
		case .player_damaged:
			k2.play_sound(assets.sounds.hurt)
		case .pickup:
			k2.play_sound(assets.sounds.pickup)
		case .enemy_died:
			k2.play_sound(assets.sounds.death)
		case .player_died:
			k2.play_sound(assets.sounds.death)
		case .level_complete:
			k2.play_sound(assets.sounds.win)
		}
	}
	clear(&game.events)
}

sprite_source :: proc(e: ^g.Entity) -> (k2.Rect, bool) {
	SPRITE :: 16
	switch e.kind {
	case .player:
		return k2.Rect{0, 0, SPRITE, SPRITE}, true
	case .patrol_dog:
		return k2.Rect{16, 0, SPRITE, SPRITE}, true
	case .guard_dog:
		return k2.Rect{32, 0, SPRITE, SPRITE}, true
	case .sleeping_dog:
		if e.is_asleep {
			return k2.Rect{64, 0, SPRITE, SPRITE}, true
		} else {
			return k2.Rect{48, 0, SPRITE, SPRITE}, true
		}
	case .key, .exit, .bone:
		return {}, false
	}
	return {}, false
}

shutdown :: proc() {
	g.shutdown(&game)
	k2.destroy_audio_stream(music)
	k2.shutdown()
}

main :: proc() {
	init()
	for step() {}
	shutdown()
}
