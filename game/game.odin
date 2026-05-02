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
	level_number:  int,
	won, lost:     bool,
}

init :: proc(g: ^Game) {
	g^ = {}
	g.level_number = 1
	start_level(g)
}

update :: proc(g: ^Game, dt: f32) {}

advance :: proc(g: ^Game) {
	if g.won {
		g.level_number += 1
		start_level(g)
	} else if g.lost {
		g.level_number = 1
		start_level(g)
	}
}

shutdown :: proc(g: ^Game) {
	hm.dynamic_destroy(&g.level.entities)
	delete(g.level.tiles)
}

start_level :: proc(g: ^Game) {
	starting_hp := 3
	if g.level.tiles != nil {
		if e, ok := hm.get(&g.level.entities, g.player_handle); ok {
			starting_hp = min(e.hp + 1, 9)
		}
		hm.dynamic_destroy(&g.level.entities)
		delete(g.level.tiles)
	}
	g.won = false
	g.lost = false
	g.level = parse_level_from_strings(LEVEL_1[:])
	init_entities(g, starting_hp)
}

init_entities :: proc(g: ^Game, player_hp: int) {
	entrance_candidates := list_walkable_tiles_in_column(&g.level, 1)
	entrance_pos := entrance_candidates[rand.int_max(len(entrance_candidates))]
	g.player_handle = hm.add(
		&g.level.entities,
		Entity{kind = .player, pos = entrance_pos, hp = player_hp},
	)

	exit_candidates := list_walkable_tiles_in_column(&g.level, g.level.width - 2)
	exit_pos := exit_candidates[rand.int_max(len(exit_candidates))]
	_ = hm.add(&g.level.entities, Entity{kind = .exit, pos = exit_pos})

	excluded := make([dynamic][2]int, context.temp_allocator)
	append(&excluded, entrance_pos, exit_pos)
	key_candidates := list_walkable_tiles_excluding(&g.level, excluded[:])
	key_pos := key_candidates[rand.int_max(len(key_candidates))]
	_ = hm.add(&g.level.entities, Entity{kind = .key, pos = key_pos})

	append(&excluded, key_pos)
	dog1_candidates := list_walkable_tiles_excluding(&g.level, excluded[:])
	dog1_pos := dog1_candidates[rand.int_max(len(dog1_candidates))]
	_ = hm.add(&g.level.entities, Entity{kind = .patrol_dog, pos = dog1_pos, hp = 1})

	append(&excluded, dog1_pos)
	dog2_candidates := list_walkable_tiles_excluding(&g.level, excluded[:])
	dog2_pos := dog2_candidates[rand.int_max(len(dog2_candidates))]
	_ = hm.add(&g.level.entities, Entity{kind = .guard_dog, pos = dog2_pos, hp = 2})
}

player_move :: proc(g: ^Game, dir: Direction) {
	delta := dir_to_delta(dir)
	if !try_act(g, g.player_handle, delta) {return}
	on_player_entered_tile(g)
	enemies_act(g)

	if !hm.is_valid(&g.level.entities, g.player_handle) {
		g.lost = true
	}
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
