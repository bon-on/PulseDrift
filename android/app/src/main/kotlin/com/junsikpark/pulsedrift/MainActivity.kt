package com.junsikpark.pulsedrift

import android.content.res.AssetFileDescriptor
import android.media.AudioAttributes
import android.media.MediaPlayer
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var musicPlayer: MediaPlayer? = null
    private var effectsPlayer: MediaPlayer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "pulse_drift/audio",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startBackgroundLoop" -> {
                    startBackgroundLoop()
                    result.success(null)
                }
                "stopBackgroundLoop" -> {
                    stopBackgroundLoop()
                    result.success(null)
                }
                "playPulsePass" -> {
                    playEffect("assets/audio/pulse_pass.wav")
                    result.success(null)
                }
                "disposeAudio" -> {
                    disposeAudio()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        disposeAudio()
        super.onDestroy()
    }

    private fun startBackgroundLoop() {
        stopBackgroundLoop()
        runCatching {
            val descriptor = assetDescriptor("assets/audio/background_loop.wav")
            val player = MediaPlayer()
            player.setAudioAttributes(gameAudioAttributes())
            player.setDataSource(
                descriptor.fileDescriptor,
                descriptor.startOffset,
                descriptor.length,
            )
            descriptor.close()
            player.isLooping = true
            player.setVolume(0.28f, 0.28f)
            player.prepare()
            musicPlayer = player
            player.start()
        }.onFailure {
            musicPlayer = null
        }
    }

    private fun stopBackgroundLoop() {
        musicPlayer?.stop()
        musicPlayer?.release()
        musicPlayer = null
    }

    private fun playEffect(asset: String) {
        effectsPlayer?.release()
        effectsPlayer = null
        runCatching {
            val descriptor = assetDescriptor(asset)
            val player = MediaPlayer()
            player.setAudioAttributes(gameAudioAttributes())
            player.setDataSource(
                descriptor.fileDescriptor,
                descriptor.startOffset,
                descriptor.length,
            )
            descriptor.close()
            player.setVolume(0.78f, 0.78f)
            player.prepare()
            player.setOnCompletionListener {
                it.release()
                if (effectsPlayer === it) {
                    effectsPlayer = null
                }
            }
            effectsPlayer = player
            player.start()
        }.onFailure {
            effectsPlayer = null
        }
    }

    private fun assetDescriptor(asset: String): AssetFileDescriptor {
        val key = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(asset)
        return assets.openFd("flutter_assets/$key")
    }

    private fun gameAudioAttributes(): AudioAttributes {
        return AudioAttributes.Builder()
            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
            .setUsage(AudioAttributes.USAGE_GAME)
            .build()
    }

    private fun disposeAudio() {
        stopBackgroundLoop()
        effectsPlayer?.release()
        effectsPlayer = null
    }
}
