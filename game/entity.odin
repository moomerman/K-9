package game

import hm "core:container/handle_map"

EntityHandle :: hm.Handle32

EntityKind :: enum {
	player,
	key,
	exit,
	patrol_dog,
	guard_dog,
}

Entity :: struct {
	handle:    EntityHandle,
	kind:      EntityKind,
	pos:       [2]int,
	chase_dir: [2]int,
	hp:        int,
}

is_creature :: proc(k: EntityKind) -> bool {
	return k == .player || is_enemy(k)
}

is_enemy :: proc(k: EntityKind) -> bool {
	return k == .patrol_dog || k == .guard_dog
}

get_entity_hp :: proc(g: ^Game, h: EntityHandle) -> int {
	if e, ok := hm.get(&g.level.entities, h); ok {
		return e.hp
	}
	return 0
}
