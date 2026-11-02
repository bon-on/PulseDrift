import Flutter
import AVFoundation
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var musicPlayer: AVAudioPlayer?
  private var effectPlayers: [AVAudioPlayer] = []
  // True while the music loop should be audible (startLoop until stopLoop),
  // so it can resume after a call or Siri interrupted the audio session.
  private var musicWanted = false
  private var interruptionObserver: NSObjectProtocol?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    interruptionObserver = NotificationCenter.default.addObserver(
      forName: AVAudioSession.interruptionNotification,
      object: AVAudioSession.sharedInstance(),
      queue: .main
    ) { [weak self] notification in
      self?.handleInterruption(notification)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func handleInterruption(_ notification: Notification) {
    guard
      let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
      let type = AVAudioSession.InterruptionType(rawValue: raw)
    else {
      return
    }
    if type == .ended, musicWanted, let player = musicPlayer, !player.isPlaying {
      configureAudioSession()
      player.play()
    }
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    configureAudioChannel(pluginRegistry: engineBridge.pluginRegistry)
  }

  private func configureAudioChannel(pluginRegistry: FlutterPluginRegistry) {
    guard let registrar = pluginRegistry.registrar(forPlugin: "PulseDriftAudio") else {
      return
    }

    let channel = FlutterMethodChannel(
      name: "pulse_drift/audio",
      binaryMessenger: registrar.messenger()
    )

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }

      let args = call.arguments as? [String: Any]
      let volume = Float(args?["volume"] as? Double ?? 1.0)
      switch call.method {
      case "play":
        if let asset = args?["asset"] as? String {
          self.playEffect(asset: asset, volume: volume)
        }
        result(nil)
      case "startLoop":
        if let asset = args?["asset"] as? String {
          self.startLoop(asset: asset, volume: volume)
        }
        result(nil)
      case "stopLoop":
        self.stopLoop()
        result(nil)
      case "disposeAudio":
        self.disposeAudio()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func configureAudioSession() {
    do {
      try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
    }
  }

  // Effects may overlap, so finished players are pruned and the rest are
  // kept alive until they stop.
  private func playEffect(asset: String, volume: Float) {
    configureAudioSession()
    effectPlayers.removeAll { !$0.isPlaying }
    guard let url = assetURL(for: asset) else {
      return
    }

    do {
      let player = try AVAudioPlayer(contentsOf: url)
      player.volume = volume
      player.prepareToPlay()
      player.play()
      effectPlayers.append(player)
    } catch {
    }
  }

  private func startLoop(asset: String, volume: Float) {
    stopLoop()
    configureAudioSession()
    guard let url = assetURL(for: asset) else {
      return
    }

    do {
      let player = try AVAudioPlayer(contentsOf: url)
      player.numberOfLoops = -1
      player.volume = volume
      player.prepareToPlay()
      player.play()
      musicPlayer = player
      musicWanted = true
    } catch {
    }
  }

  private func stopLoop() {
    musicWanted = false
    musicPlayer?.stop()
    musicPlayer = nil
  }

  private func disposeAudio() {
    stopLoop()
    effectPlayers.forEach { $0.stop() }
    effectPlayers.removeAll()
  }

  private func assetURL(for asset: String) -> URL? {
    let assetKey = FlutterDartProject.lookupKey(forAsset: asset)
    // The lookup key is already relative to the app bundle
    // (Frameworks/App.framework/flutter_assets/...).
    let url = Bundle.main.bundleURL.appendingPathComponent(assetKey)
    return FileManager.default.fileExists(atPath: url.path) ? url : nil
  }
}
