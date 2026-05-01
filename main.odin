package main

import k2 ".deps/github.com/karl-zylinski/karl2d"
import hm "core:container/handle_map"
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

	{ 	// update
		g.update(&game, dt)
	}

	{ 	// render
		k2.clear(k2.BLACK)
		draw_game()
		k2.present()
	}

	free_all(context.temp_allocator)
	return true
}

draw_game :: proc() {
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

shutdown :: proc() {
	g.shutdown(&game)
	k2.shutdown()
}

main :: proc() {
	init()
	for step() {}
	shutdown()
}
