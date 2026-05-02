package game

import hm "core:container/handle_map"

Tile :: enum {
	floor,
	wall,
}

Level :: struct {
	width, height: int,
	tiles:         []Tile,
	entities:      hm.Dynamic_Handle_Map(Entity, EntityHandle),
	has_key:       bool,
}

parse_level_from_strings :: proc(rows: []string) -> Level {
	height := len(rows)
	width := len(rows[0])

	level := Level {
		width  = width,
		height = height,
		tiles  = make([]Tile, width * height),
	}
	hm.dynamic_init(&level.entities, context.allocator)

	for row, y in rows {
		for ch, x in row {
			switch ch {
			case '#':
				level.tiles[y * width + x] = .wall
			case '.':
				level.tiles[y * width + x] = .floor
			}
		}
	}

	return level
}

has_line_of_sight :: proc(level: ^Level, from, to: [2]int) -> bool {
	if from.x != to.x && from.y != to.y {return false}

	step: [2]int
	if from.x == to.x {
		step.y = to.y > from.y ? 1 : -1
	} else {
		step.x = to.x > from.x ? 1 : -1
	}

	pos := from + step
	for pos != to {
		if level.tiles[pos.y * level.width + pos.x] == .wall {
			return false
		}
		pos += step
	}

	return true
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
