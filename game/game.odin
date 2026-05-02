package game

import hm "core:container/handle_map"
import "core:fmt"
import "core:math/rand"

Direction :: enum {
	north,
	south,
	east,
	west,
}

Game :: struct {
	level:         Level,
	player_handle: EntityHandle,
	won, lost:     bool,
}

init :: proc(g: ^Game) {
	g.level = parse_level_from_strings(LEVEL_1[:])
	init_entities(g)
}

update :: proc(g: ^Game, dt: f32) {}

shutdown :: proc(g: ^Game) {
	hm.dynamic_destroy(&g.level.entities)
	delete(g.level.tiles)
}

init_entities :: proc(g: ^Game) {
	g.player_handle = hm.add(&g.level.entities, Entity{kind = .player, pos = {2, 2}, hp = 5})
	_ = hm.add(&g.level.entities, Entity{kind = .key, pos = {8, 6}})
	_ = hm.add(&g.level.entities, Entity{kind = .exit, pos = {14, 10}})
	_ = hm.add(&g.level.entities, Entity{kind = .patrol_dog, pos = {12, 8}, hp = 1})
	_ = hm.add(&g.level.entities, Entity{kind = .guard_dog, pos = {10, 2}, hp = 2})
}

player_move :: proc(g: ^Game, dir: Direction) {
	delta := dir_to_delta(dir)
	if !try_act(g, g.player_handle, delta) {return}
	on_player_entered_tile(g)
	enemies_act(g)
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
		case .player, .patrol_dog, .guard_dog:
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
		if is_enemy(e.kind) {
			append(&handles, h)
		}
	}

	for h in handles {
		if !hm.is_valid(&g.level.entities, h) {continue}
		e, _ := hm.get(&g.level.entities, h)
		switch e.kind {
		case .patrol_dog:
			patrol_dog_act(g, h)
		case .guard_dog:
			guard_dog_act(g, h)
		case .player, .key, .exit:
		}
	}
}

patrol_dog_act :: proc(g: ^Game, h: EntityHandle) {
	deltas := [4][2]int{{0, -1}, {0, 1}, {-1, 0}, {1, 0}}
	d := deltas[rand.int_max(4)]
	try_act(g, h, d)
}

guard_dog_act :: proc(g: ^Game, h: EntityHandle) {
	dog, ok := hm.get(&g.level.entities, h)
	if !ok {return}
	player, p_ok := hm.get(&g.level.entities, g.player_handle)
	if !p_ok {return}

	if !has_line_of_sight(&g.level, dog.pos, player.pos) {
		return
	}

	step: [2]int
	if dog.pos.x == player.pos.x {
		step.y = player.pos.y > dog.pos.y ? 1 : -1
	} else {
		step.x = player.pos.x > dog.pos.x ? 1 : -1
	}
	try_act(g, h, step)
}
