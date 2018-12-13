import Flutter
import UIKit
import AVKit

@available(iOS 10.0, *)
public class SwiftSoundManagerPlugin: NSObject, FlutterPlugin {
    fileprivate let musicPlayer = AVPlayer()
    private static var registrar: FlutterPluginRegistrar!
    private var maxDB: Float = 0
    fileprivate var recorder = try! AVAudioRecorder(url: URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory,  .userDomainMask, true)[0] + "/recordTest.caf"),
                                                    settings: [AVFormatIDKey:kAudioFormatAppleIMA4,
                                                               AVSampleRateKey:44100.0,
                                                               AVNumberOfChannelsKey:2,
                                                               AVEncoderBitRateKey:12800,
                                                               AVLinearPCMBitDepthKey:16,
                                                               AVEncoderAudioQualityKey:AVAudioQuality.max.rawValue])
    fileprivate var recoderTimer: Timer!
    fileprivate static var channel: FlutterMethodChannel!
    public static func register(with registrar: FlutterPluginRegistrar) {
        channel = FlutterMethodChannel(name: "top.sp0cket.flutter/audio", binaryMessenger: registrar.messenger())
        let instance = SwiftSoundManagerPlugin()
        SwiftSoundManagerPlugin.registrar = registrar
        registrar.addMethodCallDelegate(instance, channel: channel)
        try? AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playAndRecord,
                                                         mode: AVAudioSession.Mode(rawValue: convertFromAVAudioSessionMode(AVAudioSession.Mode.spokenAudio)),
                                                         options: .defaultToSpeaker)
        try? AVAudioSession.sharedInstance().setActive(true)
    }
    private func handleChinese(string: String) -> String {
        guard let encodedString = string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return ""
        }
        return encodedString.replacingOccurrences(of: "%2F", with: "/")
    }
    private func playSound(_ url: String) {
        let flutterURL = SwiftSoundManagerPlugin.registrar.lookupKey(forAsset: url)
        let path = Bundle.main.path(forResource: handleChinese(string: flutterURL), ofType: nil)
        let item = AVPlayerItem(url: URL(fileURLWithPath: path!))
        musicPlayer.replaceCurrentItem(with: item)
        musicPlayer.seek(to: CMTime(value: 0, timescale: 1))
        musicPlayer.play()
    }
    private func stopSound() {
        musicPlayer.pause()
        musicPlayer.currentItem?.seek(to: CMTime(value: 0, timescale: 1))
    }
    @objc func levelTimerCallback(_ timer: Timer) {
        recorder.updateMeters()
        var level: Float = 0
        let minDecibels: Float = -80
        let decibels = recorder.averagePower(forChannel: 0)
        print(decibels)
        if decibels < minDecibels {
            level = 0
        } else if decibels >= 0 {
            level = 1
        } else {
            let minAmp = powf(10, 0.05 * minDecibels)
            let amp = powf(10, 0.05 * decibels)
            let adjAmp = (amp - minAmp) * 1 / (1 - minAmp)
            level = powf(adjAmp, 1 / 2)
        }
        if level * 120 > maxDB {
            maxDB = level * 120
            print("最大分贝:\(maxDB)")
            SwiftSoundManagerPlugin.channel.invokeMethod("SPMusic.maxDB", arguments: maxDB)
        }
    }
    private func recoderStart() {
        maxDB = 0
        recorder.prepareToRecord()
        recorder.isMeteringEnabled = true
        recorder.record()
        recoderTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(levelTimerCallback(_:)), userInfo: nil, repeats: true)
        recoderTimer.fire()
    }
    private func recoderStop() {
        recorder.stop()
        recorder.isMeteringEnabled = false
        recoderTimer.invalidate()
    }
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "play":
            guard let arg = call.arguments as? [String: String] else { return }
            playSound(arg["url"]!)
        case "stop":
            stopSound()
        case "recoderStart":
            recoderStart()
        case "recoderStop":
            recoderStop()
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromAVAudioSessionMode(_ input: AVAudioSession.Mode) -> String {
	return input.rawValue
}
