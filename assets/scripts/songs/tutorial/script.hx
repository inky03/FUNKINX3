function createPost() {
	if (game.player2.character == game.player3.character) {
		var gf:Character = game.player3;
		game.player2.kill();
		game.player2 = gf;
	}
}