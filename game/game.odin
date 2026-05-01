package game

import hm "core:container/handle_map"
import "core:fmt"

Tile :: enum {
	floor,
	wall,
}

Direction :: enum {
	north,
	south,
	east,
	west,
}

EntityHandle :: hm.Handle32

EntityKind :: enum {
	player,
	key,
	exit,
}

Entity :: struct {
	handle: EntityHandle,
	kind:   EntityKind,
	pos:    [2]int,
}

Level :: struct {
	width, height: int,
	tiles:         []Tile,
	entities:      hm.Dynamic_Handle_Map(Entity, EntityHandle),
	has_key:       bool,
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

	key := Entity {
		kind = .key,
		pos  = {8, 6},
	}
	key_h := hm.add(&g.level.entities, key)
	if e, ok := hm.get(&g.level.entities, key_h); ok {e.handle = key_h}

	exit := Entity {
		kind = .exit,
		pos  = {14, 10},
	}
	exit_h := hm.add(&g.level.entities, exit)
	if e, ok := hm.get(&g.level.entities, exit_h); ok {e.handle = exit_h}

	g.level.width = 16
	g.level.height = 12
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

player_move :: proc(g: ^Game, dir: Direction) {
	delta: [2]int
	switch dir {
	case .north:
		delta = {0, -1}
	case .south:
		delta = {0, 1}
	case .east:
		delta = {1, 0}
	case .west:
		delta = {-1, 0}
	}
	if !try_move(g, g.player_handle, delta) {return}

	on_player_entered_tile(g)
}

is_walkable :: proc(level: ^Level, x, y: int) -> bool {
	if x < 0 || x >= level.width || y < 0 || y >= level.height {
		return false
	}
	tile := level.tiles[y * level.width + x]
	if tile == .floor {
		return true
	}
	return false
}

try_move :: proc(g: ^Game, h: EntityHandle, delta: [2]int) -> bool {
	if e, ok := hm.get(&g.level.entities, h); ok {
		nx := e.pos.x + delta.x
		ny := e.pos.y + delta.y
		if !is_walkable(&g.level, nx, ny) {
			return false
		}
		e.pos = {nx, ny}
		return true
	}
	return false
}

on_player_entered_tile :: proc(g: ^Game) {
	player, _ := hm.get(&g.level.entities, g.player_handle)

	it := hm.iterator_make(&g.level.entities)
	for e, h in hm.iterate(&it) {
		if h == g.player_handle {continue}
		if e.pos != player.pos {continue}

		switch e.kind {
		case .key:
			g.level.has_key = true
			hm.remove(&g.level.entities, h)
		case .exit:
			if g.level.has_key {
				fmt.println("WON!")
			}
		case .player:
		// unreachable — already skipped above
		}
	}
}
