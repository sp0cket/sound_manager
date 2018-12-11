package top.sp0cket.soundmanager

import android.Manifest
import android.annotation.TargetApi
import android.app.Activity
import android.content.pm.PackageManager
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.widget.Toast
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar
import java.net.URLEncoder

class SoundManagerPlugin private constructor(private val activity: Activity,
                                             private val channel: MethodChannel): MethodCallHandler {
  private var mediaPlayer: MediaPlayer? = null
  private val recordFilePath = "/dev/null"  //不保存录音文件
  private var mediaRecorder: MediaRecorder? = null
  private var maxDB = 0.0

  companion object {
    private const val FLUTTER_CHANNEL = "top.sp0cket.flutter/audio"
    private var registrar: Registrar? = null
    @JvmStatic
    fun registerWith(registrar: Registrar) {
      val channel = MethodChannel(registrar.messenger(), FLUTTER_CHANNEL)
      channel.setMethodCallHandler(SoundManagerPlugin(registrar.activity(), channel))
      SoundManagerPlugin.registrar = registrar
    }
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "play" -> playSound((call.arguments as Map<String, String>)["url"]!!)
      "stop" -> stopSound()
      "recoderStart" -> startRecord()
      "recoderStop" -> stopRecord()
      else -> result.notImplemented()
    }
  }
  @TargetApi(Build.VERSION_CODES.M)
  private fun requestPermission() {
    activity.requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), 1)
  }
  private fun handleChinese(string: String) : String {
    val encodedString = URLEncoder.encode(string, "UTF-8")    //将中文进行编码
    return encodedString.replace("%2F", "/")    //将路径中的/符号替换回原样
  }
  private fun playSound(url: String) {
    val assetManager = activity.assets
    val key = registrar?.lookupKeyForAsset(handleChinese(url))
    val afd = assetManager.openFd(key)
    if (mediaPlayer == null) {
      mediaPlayer = MediaPlayer()
      mediaPlayer?.reset()
      mediaPlayer?.setDataSource(afd!!.fileDescriptor, afd.startOffset, afd.length)
      mediaPlayer?.prepare()
      mediaPlayer?.setOnPreparedListener { mediaPlayer ->
        if (mediaPlayer != null && mediaPlayer.isPlaying)
          stopSound()
        mediaPlayer.start()
      }
      mediaPlayer?.setOnCompletionListener {
        channel.invokeMethod("SPMusic.onComplete", null)
        stopSound()
      }
    } else {
      mediaPlayer?.stop()
      mediaPlayer?.release()
      mediaPlayer = null
      playSound(url)
    }
  }
  private fun stopSound() {
    if (mediaPlayer != null) {
      mediaPlayer?.stop()
      mediaPlayer?.release()
      mediaPlayer = null
      channel.invokeMethod("SPMusic.onStop", null)
    }
  }
  private fun startRecord() {
    val audioStatePermission = activity.packageManager.checkPermission(Manifest.permission.RECORD_AUDIO, activity.packageName) == PackageManager.PERMISSION_GRANTED
    if (Build.VERSION.SDK_INT>=23 && !audioStatePermission) {
      requestPermission()
      Toast.makeText(activity, "我们需要通过您的麦克风来采集声音用于识别，请先允许我们使用您的麦克风权限，否则我们将无法识别声音", Toast.LENGTH_LONG).show()
      channel.invokeMethod("SPMusic.maxDB", maxDB)
      return
    }
    if (mediaRecorder == null) {
      mediaRecorder = MediaRecorder()
    }
    mediaRecorder?.setAudioSource(MediaRecorder.AudioSource.MIC)
    mediaRecorder?.setOutputFormat(MediaRecorder.OutputFormat.DEFAULT)
    mediaRecorder?.setAudioEncoder(MediaRecorder.AudioEncoder.AMR_NB)
    mediaRecorder?.setOutputFile(recordFilePath)
    mediaRecorder?.prepare()
    mediaRecorder?.start()
    maxDB = 0.0
    channel.invokeMethod("SPMusic.maxDB", maxDB)
    updateMicStatus()
  }
  private val mUpdateMicStatusTimer = Runnable {
    updateMicStatus()
  }
  private val handler = Handler()
  private fun updateMicStatus() {
    if (mediaRecorder != null) {
      val ratio: Double = mediaRecorder!!.maxAmplitude.toDouble() / 1
      val db: Double

      if (ratio > 1) {
        db = 20 * Math.log10(ratio)
        if (db > maxDB) {
          maxDB = db
          channel.invokeMethod("SPMusic.maxDB", maxDB)
        }
      }
      handler.postDelayed(mUpdateMicStatusTimer, 1000)
    }
  }
  private fun stopRecord() {
    try {
      mediaRecorder?.stop()
    } finally {
      mediaRecorder?.reset()
      mediaRecorder?.release()
      mediaRecorder = null
    }
  }
}
