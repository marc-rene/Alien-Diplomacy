package com.aliendiploracy.speech

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot

class SpeechRecognizerPlugin(godot: Godot) : GodotPlugin(godot) {

    private val TAG = "SpeechRecognizerPlugin"
    private var recognizer: SpeechRecognizer? = null

    override fun getPluginName(): String = "SpeechRecognizerPlugin"

    override fun getPluginSignals(): Set<SignalInfo> = setOf(
        SignalInfo("transcription_ready", String::class.java),
        SignalInfo("recording_state_changed", Boolean::class.javaObjectType),
        SignalInfo("speech_error", Int::class.javaObjectType)
    )

    @UsedByGodot
    fun startListening() {
        val ctx = activity ?: return

        if (ctx.checkSelfPermission(Manifest.permission.RECORD_AUDIO)
                != PackageManager.PERMISSION_GRANTED) {
            Log.e(TAG, "RECORD_AUDIO permission not granted")
            emitSignal("speech_error", -1)
            return
        }

        ctx.runOnUiThread {
            // Diagnostic: is any recognition service available at all?
            val available = SpeechRecognizer.isRecognitionAvailable(ctx)
            Log.d(TAG, "isRecognitionAvailable = $available")
            if (!available) {
                Log.e(TAG, "No recognition service found on this device")
                emitSignal("speech_error", -2)
                return@runOnUiThread
            }

            // Always recreate — avoids ERROR_CLIENT (5) from a poisoned previous session
            recognizer?.destroy()
            recognizer = SpeechRecognizer.createSpeechRecognizer(ctx)
            recognizer?.setRecognitionListener(listener)
            Log.d(TAG, "Recognizer created, calling startListening")

            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                    RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, ctx.packageName)
                putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, false)
            }
            recognizer?.startListening(intent)
        }
    }

    @UsedByGodot
    fun stopListening() {
        activity?.runOnUiThread {
            Log.d(TAG, "stopListening called")
            recognizer?.stopListening()
            emitSignal("recording_state_changed", false)
        }
    }

    private val listener = object : RecognitionListener {
        override fun onReadyForSpeech(params: Bundle?) {
            Log.d(TAG, "onReadyForSpeech — microphone is open")
            emitSignal("recording_state_changed", true)
        }
        override fun onBeginningOfSpeech() {
            Log.d(TAG, "onBeginningOfSpeech — audio detected")
        }
        override fun onRmsChanged(rmsdB: Float) {}
        override fun onBufferReceived(buffer: ByteArray?) {}
        override fun onEndOfSpeech() {
            Log.d(TAG, "onEndOfSpeech — processing")
        }
        override fun onError(error: Int) {
            Log.e(TAG, "onError: $error")
            emitSignal("recording_state_changed", false)
            emitSignal("speech_error", error)
            activity?.runOnUiThread {
                recognizer?.destroy()
                recognizer = null
            }
        }
        override fun onResults(results: Bundle?) {
            val text = results
                ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                ?.firstOrNull() ?: ""
            Log.d(TAG, "onResults: \"$text\"")
            emitSignal("recording_state_changed", false)
            emitSignal("transcription_ready", text)
            // cancel() stops auto-restart without destroying — recognizer is reusable next fist
            activity?.runOnUiThread {
                recognizer?.cancel()
            }
        }
        override fun onPartialResults(partialResults: Bundle?) {}
        override fun onEvent(eventType: Int, params: Bundle?) {}
    }

    override fun onMainDestroy() {
        activity?.runOnUiThread {
            recognizer?.destroy()
            recognizer = null
        }
        super.onMainDestroy()
    }
}
