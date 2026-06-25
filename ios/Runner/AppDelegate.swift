import Flutter
import AVFoundation
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var musicPlayer: AVAudioPlayer?
  private var effectsPlayer: AVAudioPlayer?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
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

      switch call.method {
      case "startBackgroundLoop":
        self.startBackgroundLoop()
        result(nil)
      case "stopBackgroundLoop":
        self.stopBackgroundLoop()
        result(nil)
      case "playPulsePass":
        self.playPulsePass()
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
      try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
    }
  }

  private func startBackgroundLoop() {
    configureAudioSession()
    guard let url = assetURL(for: "assets/audio/background_loop.wav") else {
      return
    }

    do {
      musicPlayer = try AVAudioPlayer(contentsOf: url)
      musicPlayer?.numberOfLoops = -1
      musicPlayer?.volume = 0.28
      musicPlayer?.prepareToPlay()
      musicPlayer?.play()
    } catch {
    }
  }

  private func stopBackgroundLoop() {
    musicPlayer?.stop()
    musicPlayer = nil
  }

  private func playPulsePass() {
    configureAudioSession()
    guard let url = assetURL(for: "assets/audio/pulse_pass.wav") else {
      return
    }

    do {
      effectsPlayer = try AVAudioPlayer(contentsOf: url)
      effectsPlayer?.volume = 0.78
      effectsPlayer?.prepareToPlay()
      effectsPlayer?.play()
    } catch {
    }
  }

  private func disposeAudio() {
    stopBackgroundLoop()
    effectsPlayer?.stop()
    effectsPlayer = nil
  }

  private func assetURL(for asset: String) -> URL? {
    let assetKey = FlutterDartProject.lookupKey(forAsset: asset)
    let appFrameworkURL = Bundle.main.bundleURL
      .appendingPathComponent("Frameworks/App.framework/flutter_assets", isDirectory: true)
      .appendingPathComponent(assetKey)

    if FileManager.default.fileExists(atPath: appFrameworkURL.path) {
      return appFrameworkURL
    }

    return Bundle.main.resourceURL?.appendingPathComponent(assetKey)
  }
}
