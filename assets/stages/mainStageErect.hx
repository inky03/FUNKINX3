var bfShader:RuntimeShader;
var gfShader:RuntimeShader;
var dadShader:RuntimeShader;
function createPost() {
    bfShader = new RuntimeShader('adjustColor');
    state.player1.shader = bfShader;
    bfShader.setFloat('hue', 12);
    bfShader.setFloat('brightness', -23);
    bfShader.setFloat('contrast', 7);
    bfShader.setFloat('saturation', 0);

    gfShader = new RuntimeShader('adjustColor');
    state.player3.shader = gfShader;
    gfShader.setFloat('hue', -9);
    gfShader.setFloat('brightness', -30);
    gfShader.setFloat('contrast', -4);
    gfShader.setFloat('saturation', 0);

    dadShader = new RuntimeShader('adjustColor');
    state.player2.shader = dadShader;
    dadShader.setFloat('hue', -32);
    dadShader.setFloat('brightness', -33);
    dadShader.setFloat('contrast', -23);
    dadShader.setFloat('saturation', 0);

    game.stage.getProp('brightLightSmall').blend = BlendMode.ADD;
    game.stage.getProp('orangeLight').blend = BlendMode.ADD;
    game.stage.getProp('lightgreen').blend = BlendMode.ADD;
    game.stage.getProp('lightred').blend = BlendMode.ADD;
    game.stage.getProp('lightAbove').blend = BlendMode.ADD;
}