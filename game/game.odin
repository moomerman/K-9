package game

import hm "core:container/handle_map"

Tile :: enum {
	floor,
	wall,
}

EntityHandle :: hm.Handle32

EntityKind :: enum {
	player,
}

Entity :: struct {
	handle: EntityHandle,
	kind:   EntityKind,
	pos:    [2]f32,
}

Level :: struct {
	width, height: int,
	tiles:         []Tile,
	entities:      hm.Dynamic_Handle_Map(Entity, EntityHandle),
}

Game :: struct {
	level:         Level,
	player_handle: EntityHandle,
}

init :: proc(g: ^Game) {
	player := Entity {
		kind = .player,
		pos  = {2, 2},
	}

	hm.dynamic_init(&g.level.entities, context.allocator)
	handle := hm.add(&g.level.entities, player)
	if e, ok := hm.get(&g.level.entities, handle); ok {
		e.handle = handle
	}
	g.player_handle = handle

	g.level.width = 16
	g.level.height = 16
	g.level.tiles = make([]Tile, 16 * 16)
	for y in 0 ..< g.level.height {
		for x in 0 ..< g.level.width {
			if x == 0 || y == 0 || x == g.level.width - 1 || y == g.level.height - 1 {
				g.level.tiles[y * g.level.width + x] = .wall
			}
		}
	}
}

update :: proc(g: ^Game, dt: f32) {}

shutdown :: proc(g: ^Game) {
	hm.dynamic_destroy(&g.level.entities)
	delete(g.level.tiles)
}
