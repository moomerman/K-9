package game

import hm "core:container/handle_map"
import "core:fmt"
import "core:math/rand"

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
	patrol_dog,
}

Entity :: struct {
	handle: EntityHandle,
	kind:   EntityKind,
	pos:    [2]int,
	hp:     int,
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
	won, lost:     bool,
}

init :: proc(g: ^Game) {
	player := Entity {
		kind = .player,
		pos  = {2, 2},
		hp   = 9,
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

	dog := Entity {
		kind = .patrol_dog,
		pos  = {12, 8},
		hp   = 2,
	}
	dog_h := hm.add(&g.level.entities, dog)
	if e, ok := hm.get(&g.level.entities, dog_h); ok {e.handle = dog_h}

	g.level.width = 16
	g.level.height = 12
	g.level.tiles = make([]Tile, g.level.width * g.level.height)
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
	delta := dir_to_delta(dir)
	if !try_act(g, g.player_handle, delta) {return}
	on_player_entered_tile(g)
	enemies_act(g)
}

is_walkable :: proc(level: ^Level, pos: [2]int) -> bool {
	if pos.x < 0 || pos.x >= level.width || pos.y < 0 || pos.y >= level.height {
		return false
	}
	tile := level.tiles[pos.y * level.width + pos.x]
	if tile != .wall {
		return true
	}
	return false
}

try_act :: proc(g: ^Game, h: EntityHandle, delta: [2]int) -> bool {
	if e, ok := hm.get(&g.level.entities, h); ok {
		target := e.pos + delta
		if !is_walkable(&g.level, target) {
			return false
		}

		if creature, creature_h, found := creature_at(g, target); found {
			if creature.kind == e.kind {
				return false
			}
			creature.hp -= 1
			fmt.printf("hit %v, hp now %d\n", creature.kind, creature.hp)
			if creature.hp <= 0 {
				hm.remove(&g.level.entities, creature_h)
			}
			return true
		}

		e.pos = target
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
				g.won = true
				fmt.println("WON!")
			}
		case .player:
		case .patrol_dog:
		}
	}
}

creature_at :: proc(g: ^Game, pos: [2]int) -> (^Entity, EntityHandle, bool) {
	it := hm.iterator_make(&g.level.entities)
	for e, h in hm.iterate(&it) {
		if e.pos == pos && is_creature(e.kind) {
			return e, h, true
		}
	}
	return nil, {}, false
}

is_creature :: proc(k: EntityKind) -> bool {
	return k == .player || k == .patrol_dog
}

dir_to_delta :: proc(dir: Direction) -> [2]int {
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
	return delta
}

enemies_act :: proc(g: ^Game) {
	handles := make([dynamic]EntityHandle, context.temp_allocator)

	it := hm.iterator_make(&g.level.entities)
	for e, h in hm.iterate(&it) {
		if e.kind == .patrol_dog {
			append(&handles, h)
		}
	}

	for h in handles {
		if !hm.is_valid(&g.level.entities, h) {continue}
		patrol_dog_act(g, h)
	}
}

patrol_dog_act :: proc(g: ^Game, h: EntityHandle) {
	deltas := [4][2]int{{0, -1}, {0, 1}, {-1, 0}, {1, 0}}
	d := deltas[rand.int_max(4)]
	try_act(g, h, d)
}
