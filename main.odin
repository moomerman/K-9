package main

import k2 ".deps/github.com/karl-zylinski/karl2d"
import g "game"

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
		k2.clear(k2.BLUE)
		k2.present()
	}

	free_all(context.temp_allocator)
	return true
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
