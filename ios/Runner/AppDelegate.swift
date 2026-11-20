import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "DcgGlassTabBar")
    else { return }
    let messenger = registrar.messenger()
    let channel = FlutterMethodChannel(name: "dcgtv/tab_bar", binaryMessenger: messenger)
    if #available(iOS 26.0, *) {
      registrar.register(GlassTabBarFactory(messenger: messenger), withId: GlassTabBarFactory.viewType)
    }
    channel.setMethodCallHandler { call, result in
      guard call.method == "supportsLiquidGlass" else {
        result(FlutterMethodNotImplemented)
        return
      }
      if #available(iOS 26.0, *) {
        result(true)
      } else {
        result(false)
      }
    }
  }
}
