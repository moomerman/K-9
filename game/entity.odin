package game

import hm "core:container/handle_map"

MOVE_DURATION :: 0.15
FLASH_DURATION :: 0.25

EntityHandle :: hm.Handle32

EntityKind :: enum {
	player,
	key,
	exit,
	patrol_dog,
	guard_dog,
	sleeping_dog,
	bone,
	fish,
}

Entity :: struct {
	handle:      EntityHandle,
	kind:        EntityKind,
	pos:         [2]int,
	prev_pos:    [2]int,
	chase_dir:   [2]int,
	hp:          int,
	is_asleep:   bool,
	lifetime:    int,
	move_timer:  f32,
	flash_timer: f32,
	anim_timer:  f32,
}

spawn_entity :: proc(g: ^Game, e: Entity) -> EntityHandle {
	e := e
	e.prev_pos = e.pos
	e.move_timer = MOVE_DURATION
	return hm.add(&g.level.entities, e)
}

is_creature :: proc(k: EntityKind) -> bool {
	return k == .player || is_enemy(k)
}

is_enemy :: proc(k: EntityKind) -> bool {
	return k == .patrol_dog || k == .guard_dog || k == .sleeping_dog
}

get_entity_hp :: proc(g: ^Game, h: EntityHandle) -> int {
	if e, ok := hm.get(&g.level.entities, h); ok {
		return e.hp
	}
	return 0
}
