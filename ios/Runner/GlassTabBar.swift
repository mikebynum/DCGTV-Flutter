import Flutter
import UIKit

@available(iOS 26.0, *)
final class GlassTabBarFactory: NSObject, FlutterPlatformViewFactory {
  static let viewType = "dcgtv/glass_tabs"
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect, viewIdentifier id: Int64, arguments args: Any?
  ) -> FlutterPlatformView {
    let selection = args as? Int ?? 0
    let channel = FlutterMethodChannel(
      name: "\(Self.viewType)/\(id)", binaryMessenger: messenger
    )
    return GlassTabBar(frame: frame, channel: channel, selection: selection)
  }
}

@available(iOS 26.0, *)
private final class GlassTabBar: NSObject, FlutterPlatformView {
  private static let tabs = [
    (title: "Home", symbol: "house.fill"),
    (title: "Watch", symbol: "play.tv.fill"),
    (title: "Schedule", symbol: "calendar"),
    (title: "Shows", symbol: "film.stack.fill"),
  ]
  private static let accent = UIColor { traits in
    if traits.userInterfaceStyle == .dark {
      return UIColor(red: 1, green: 163.0 / 255, blue: 176.0 / 255, alpha: 1)
    }
    return UIColor(red: 200.0 / 255, green: 16.0 / 255, blue: 46.0 / 255, alpha: 1)
  }
  private let glass: UIVisualEffectView
  private let channel: FlutterMethodChannel
  private var buttons: [UIButton] = []

  init(frame: CGRect, channel: FlutterMethodChannel, selection: Int) {
    let effect = UIGlassEffect(style: .regular)
    effect.isInteractive = true
    self.glass = UIVisualEffectView(effect: effect)
    self.channel = channel
    super.init()

    glass.frame = frame
    glass.cornerConfiguration = .capsule()
    let row = UIStackView()
    row.distribution = .fillEqually
    row.translatesAutoresizingMaskIntoConstraints = false
    glass.contentView.addSubview(row)
    NSLayoutConstraint.activate([
      row.leadingAnchor.constraint(equalTo: glass.contentView.leadingAnchor, constant: 5),
      row.trailingAnchor.constraint(equalTo: glass.contentView.trailingAnchor, constant: -5),
      row.topAnchor.constraint(equalTo: glass.contentView.topAnchor, constant: 5),
      row.bottomAnchor.constraint(equalTo: glass.contentView.bottomAnchor, constant: -5),
    ])
    for (index, tab) in Self.tabs.enumerated() {
      let button = UIButton(configuration: .plain())
      button.accessibilityIdentifier = "dcgtv.tab.\(tab.title.lowercased())"
      button.accessibilityLabel = tab.title
      button.addAction(UIAction { [weak self] _ in
        self?.select(index)
        self?.channel.invokeMethod("select", arguments: index)
      }, for: .primaryActionTriggered)
      row.addArrangedSubview(button)
      buttons.append(button)
    }
    select(selection)

    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "setSelection", let index = call.arguments as? Int else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.select(index)
      result(nil)
    }
  }

  deinit {
    channel.setMethodCallHandler(nil)
  }

  func view() -> UIView { glass }

  private func select(_ index: Int) {
    for (i, button) in buttons.enumerated() {
      let tab = Self.tabs[i]
      let selected = i == index
      var configuration = UIButton.Configuration.plain()
      configuration.image = UIImage(systemName: tab.symbol)
      configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(
        pointSize: 20, weight: .semibold
      )
      configuration.imagePlacement = .top
      configuration.imagePadding = 3
      configuration.title = tab.title
      configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer {
        var attributes = $0
        attributes.font = .systemFont(ofSize: 11, weight: .semibold)
        return attributes
      }
      configuration.baseForegroundColor = selected ? Self.accent : .label
      configuration.background.backgroundColor = selected ? .tertiarySystemFill : .clear
      configuration.cornerStyle = .capsule
      configuration.contentInsets = .zero
      button.configuration = configuration
      button.accessibilityTraits = selected ? [.button, .selected] : .button
    }
  }
}
