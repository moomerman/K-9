package game

import hm "core:container/handle_map"
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
	events:        [dynamic]GameEvent,
	level_number:  int,
	bones:         int,
	fish:          int,
	won, lost:     bool,
}

GameEvent :: enum {
	attack_landed,
	player_moved,
	player_damaged,
	pickup,
	enemy_died,
	player_died,
	level_complete,
}

init :: proc(g: ^Game) {
	g^ = {}
	g.events = make([dynamic]GameEvent, context.allocator)
	g.level_number = 1
	start_level(g)
}

update :: proc(g: ^Game, dt: f32) {
	it := hm.iterator_make(&g.level.entities)
	for e, _ in hm.iterate(&it) {
		e.anim_timer += dt
		if e.move_timer < MOVE_DURATION {e.move_timer += dt}
		if e.flash_timer > 0 {e.flash_timer -= dt}
	}
}

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
	delete(g.events)
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
	g.level = parse_level_from_strings(level_for_number(g.level_number))
	init_entities(g, starting_hp)
}

init_entities :: proc(g: ^Game, player_hp: int) {
	entrance_candidates := list_walkable_tiles_in_column(&g.level, 0)
	entrance_pos := entrance_candidates[rand.int_max(len(entrance_candidates))]

	exit_candidates := list_walkable_tiles_in_column(&g.level, g.level.width - 1)
	exit_pos := exit_candidates[rand.int_max(len(exit_candidates))]
	spawn_entity(g, Entity{kind = .exit, pos = exit_pos})

	excluded := make([dynamic][2]int, context.temp_allocator)
	append(&excluded, entrance_pos, exit_pos)

	key_candidates := list_walkable_tiles_excluding(&g.level, excluded[:])
	key_pos := key_candidates[rand.int_max(len(key_candidates))]
	spawn_entity(g, Entity{kind = .key, pos = key_pos})
	append(&excluded, key_pos)

	// don't spawn enemies right next to the player
	for d in ([4][2]int{{0, -1}, {0, 1}, {-1, 0}, {1, 0}}) {
		append(&excluded, entrance_pos + d)
	}

	patrol_count := 1 + g.level_number
	guard_count := (g.level_number + 1) / 2
	sleeper_count := g.level_number / 2

	spawn_enemies(g, .patrol_dog, patrol_count, 1, false, &excluded)
	spawn_enemies(g, .guard_dog, guard_count, 2, false, &excluded)
	spawn_enemies(g, .sleeping_dog, sleeper_count, 1, true, &excluded)

	if rand.float32() < 0.3 {
		candidates := list_walkable_tiles_excluding(&g.level, excluded[:])
		if len(candidates) > 0 {
			pos := candidates[rand.int_max(len(candidates))]
			spawn_entity(g, Entity{kind = .bone, pos = pos})
		}
	}

	if rand.float32() < 0.3 {
		candidates := list_walkable_tiles_excluding(&g.level, excluded[:])
		if len(candidates) > 0 {
			pos := candidates[rand.int_max(len(candidates))]
			spawn_entity(g, Entity{kind = .fish, pos = pos})
			append(&excluded, pos)
		}
	}

	// add player last so it gets drawn on top
	g.player_handle = spawn_entity(g, Entity{kind = .player, pos = entrance_pos, hp = player_hp})
}

spawn_enemies :: proc(
	g: ^Game,
	kind: EntityKind,
	count, hp: int,
	asleep: bool,
	excluded: ^[dynamic][2]int,
) {
	for _ in 0 ..< count {
		candidates := list_walkable_tiles_excluding(&g.level, excluded[:])
		if len(candidates) == 0 {break}
		pos := candidates[rand.int_max(len(candidates))]
		spawn_entity(g, Entity{kind = kind, pos = pos, hp = hp, is_asleep = asleep})
		append(excluded, pos)
	}
}

player_move :: proc(g: ^Game, dir: Direction) {
	delta := dir_to_delta(dir)
	if !try_act(g, g.player_handle, delta) {return}
	on_player_entered_tile(g)
	enemies_act(g)
	append(&g.events, GameEvent.player_moved)

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
			if is_enemy(creature.kind) && is_enemy(e.kind) {
				return false
			}
			append(&g.events, GameEvent.attack_landed)
			creature.hp -= 1
			creature.flash_timer = FLASH_DURATION
			if creature.kind == .player {
				append(&g.events, GameEvent.player_damaged)
			}
			creature.is_asleep = false
			if creature.hp <= 0 {
				if creature.kind == .player {
					append(&g.events, GameEvent.player_died)
				} else {
					append(&g.events, GameEvent.enemy_died)
				}
				hm.remove(&g.level.entities, creature_h)
			}
			return true
		}

		e.prev_pos = e.pos
		e.pos = target
		e.move_timer = 0
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
			append(&g.events, GameEvent.pickup)
			hm.remove(&g.level.entities, h)
		case .exit:
			if g.level.has_key {
				g.won = true
				append(&g.events, GameEvent.level_complete)
			}
		case .bone:
			g.bones += 1
			append(&g.events, GameEvent.pickup)
			hm.remove(&g.level.entities, h)
		case .fish:
			g.fish += 1
			append(&g.events, GameEvent.pickup)
			hm.remove(&g.level.entities, h)
		case .player, .patrol_dog, .guard_dog, .sleeping_dog:
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

player_drop_bone :: proc(g: ^Game) {
	if g.bones <= 0 {return}
	player, ok := hm.get(&g.level.entities, g.player_handle)
	if !ok {return}

	g.bones -= 1
	spawn_entity(g, Entity{kind = .bone, pos = player.pos, lifetime = 6})

	enemies_act(g)
	tick_bones(g)

	if !hm.is_valid(&g.level.entities, g.player_handle) {
		g.lost = true
	}
}

tick_bones :: proc(g: ^Game) {
	handles := make([dynamic]EntityHandle, context.temp_allocator)
	it := hm.iterator_make(&g.level.entities)
	for e, h in hm.iterate(&it) {
		if e.kind != .bone {continue}
		if e.lifetime <= 0 {continue}
		e.lifetime -= 1
		if e.lifetime <= 0 {
			append(&handles, h)
		}
	}
	for h in handles {
		hm.remove(&g.level.entities, h)
	}
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
		case .sleeping_dog:
			sleeping_dog_act(g, h)
		case .player, .key, .exit, .bone, .fish:
		}
	}
}

patrol_dog_act :: proc(g: ^Game, h: EntityHandle) {
	dog, ok := hm.get(&g.level.entities, h)
	if !ok {return}
	player, p_ok := hm.get(&g.level.entities, g.player_handle)
	if !p_ok {return}

	diff := player.pos - dog.pos
	manhattan := abs(diff.x) + abs(diff.y)
	if manhattan == 1 {
		try_act(g, h, diff)
		return
	}

	deltas := [4][2]int{{0, -1}, {0, 1}, {-1, 0}, {1, 0}}
	d := deltas[rand.int_max(4)]
	try_act(g, h, d)
}

guard_dog_act :: proc(g: ^Game, h: EntityHandle) {
	chase_target(g, h)
}

sleeping_dog_act :: proc(g: ^Game, h: EntityHandle) {
	dog, ok := hm.get(&g.level.entities, h)
	if !ok {return}
	player, p_ok := hm.get(&g.level.entities, g.player_handle)
	if !p_ok {return}

	if dog.is_asleep {
		diff := player.pos - dog.pos
		if abs(diff.x) + abs(diff.y) <= 3 {
			dog.is_asleep = false
		} else {
			return
		}
	}

	chase_target(g, h)
}

chase_target :: proc(g: ^Game, h: EntityHandle) {
	dog, ok := hm.get(&g.level.entities, h)
	if !ok {return}

	if dog.distracted > 0 {
		dog.distracted -= 1
		return
	}

	// consume bone
	if bone_h, found := bone_at(g, dog.pos); found {
		hm.remove(&g.level.entities, bone_h)
		dog.chase_dir = {}
		dog.distracted = DISTRACTED_TURNS_AFTER_BONE
		return
	}

	target_pos, found := find_chase_target(g, dog.pos)
	if found {
		step: [2]int
		if dog.pos.x == target_pos.x {
			step.y = target_pos.y > dog.pos.y ? 1 : -1
		} else {
			step.x = target_pos.x > dog.pos.x ? 1 : -1
		}
		dog.chase_dir = step
	}

	if dog.chase_dir != {0, 0} {
		if !try_act(g, h, dog.chase_dir) {
			dog.chase_dir = {}
		}
	}
}

find_chase_target :: proc(g: ^Game, from: [2]int) -> ([2]int, bool) {
	// chase bones
	nearest_pos: [2]int
	nearest_dist := max(int)
	found := false

	it := hm.iterator_make(&g.level.entities)
	for e, _ in hm.iterate(&it) {
		if e.kind != .bone {continue}
		if !has_line_of_sight(&g.level, from, e.pos) {continue}
		diff := e.pos - from
		dist := abs(diff.x) + abs(diff.y)
		if dist < nearest_dist {
			nearest_dist = dist
			nearest_pos = e.pos
			found = true
		}
	}
	if found {return nearest_pos, true}

	// chase player
	player, p_ok := hm.get(&g.level.entities, g.player_handle)
	if !p_ok {return {}, false}
	if has_line_of_sight(&g.level, from, player.pos) {
		return player.pos, true
	}
	return {}, false
}

bone_at :: proc(g: ^Game, pos: [2]int) -> (EntityHandle, bool) {
	it := hm.iterator_make(&g.level.entities)
	for e, h in hm.iterate(&it) {
		if e.kind == .bone && e.pos == pos {
			return h, true
		}
	}
	return {}, false
}

player_use_fish :: proc(g: ^Game) {
	if g.fish <= 0 {return}
	player, ok := hm.get(&g.level.entities, g.player_handle)
	if !ok {return}
	if player.hp >= 9 {return}

	g.fish -= 1
	player.hp = min(player.hp + 2, 9)
	append(&g.events, GameEvent.pickup)

	enemies_act(g)
	tick_bones(g)

	if !hm.is_valid(&g.level.entities, g.player_handle) {
		g.lost = true
	}
}
