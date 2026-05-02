package main

import k2 ".deps/github.com/karl-zylinski/karl2d"
import hm "core:container/handle_map"
import "core:fmt"
import "core:math"
import g "game"

TILE_SIZE :: 16

game: g.Game

init :: proc() {
	k2.init(1000, 600, "K-9", {window_mode = .Windowed_Resizable})
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

	// draw level
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

	// draw entitites
	it := hm.iterator_make(&game.level.entities)
	for e, _ in hm.iterate(&it) {
		entity_color: k2.Color
		switch e.kind {
		case .player:
			entity_color = k2.YELLOW
		case .key:
			entity_color = k2.WHITE
		case .exit:
			entity_color = k2.GREEN
		case .patrol_dog:
			entity_color = k2.RED
		case .guard_dog:
			entity_color = k2.ORANGE
		}
		rect := k2.Rect {
			x = f32(e.pos.x * TILE_SIZE),
			y = f32(e.pos.y * TILE_SIZE),
			w = TILE_SIZE,
			h = TILE_SIZE,
		}
		k2.draw_rect(rect, entity_color)
	}
}

draw_hud :: proc() {
	player_hp := g.get_entity_hp(&game, game.player_handle)
	hud_text := fmt.tprintf("LEVEL %d   HP %d", game.level_number, player_hp)
	k2.draw_text(hud_text, {16, 16}, 24, k2.WHITE)
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

shutdown :: proc() {
	g.shutdown(&game)
	k2.shutdown()
}

main :: proc() {
	init()
	for step() {}
	shutdown()
}
