package funkin.vis.audioclip.frontends;

import funkin.vis.AudioBuffer;
import lime.media.AudioSource;

/**
 * Implementation of AudioClip for Lime.
 * On OpenFL you will want SoundChannel.__source (with @:privateAccess)
 * For Flixel, you will want to get the FlxSound._channel.__source
 *
 * Note: On one of the recent OpenFL versions (9.3.2)
 * __source was renamed to __audioSource
 * https://github.com/openfl/openfl/commit/eec48a
 *
 */
class LimeAudioClip implements funkin.vis.AudioClip
{
	public var fetchTime:Float = -1;
	public var audioBuffer(default, null):AudioBuffer;
    public var currentFrame(get, never):Int;
	public var source:Dynamic;
	var audSource:AudioSource;

	public function new(audioSource:AudioSource)
	{
		var data:lime.utils.UInt16Array = cast audioSource.buffer.data;

		#if web
		var sampleRate:Float = audioSource.buffer.src._sounds[0]._node.context.sampleRate;
		#else
		var sampleRate = audioSource.buffer.sampleRate;
		#end

		this.audioBuffer = new AudioBuffer(data, sampleRate);
		this.source = audioSource.buffer.src;
		this.audSource = audioSource;
	}
	
	public function frameAtTime(time:Float):Int {
		var dataLength:Int = 0;

		#if web
		dataLength = source.length;
		#else
		dataLength = audioBuffer.data.length;
		#end

		var value = Std.int(time / audSource.length * dataLength);

		if (value < 0)
			return -1;

		return value;
	}
	private function get_currentFrame():Int {
		return frameAtTime(audSource.currentTime);
	}
}