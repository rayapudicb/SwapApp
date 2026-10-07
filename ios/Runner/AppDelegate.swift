import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let privacyShieldTag = 937_421
  private var inactive = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(captureStateChanged),
      name: UIScreen.capturedDidChangeNotification,
      object: nil
    )
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationWillResignActive(_ application: UIApplication) {
    super.applicationWillResignActive(application)
    inactive = true
    updatePrivacyShield()
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    inactive = false
    updatePrivacyShield()
  }

  @objc private func captureStateChanged() {
    updatePrivacyShield()
  }

  private func updatePrivacyShield() {
    if inactive || UIScreen.main.isCaptured {
      installPrivacyShield()
    } else {
      window?.viewWithTag(privacyShieldTag)?.removeFromSuperview()
    }
  }

  private func installPrivacyShield() {
    guard let window = window, window.viewWithTag(privacyShieldTag) == nil else { return }
    let shield = UIView(frame: window.bounds)
    shield.tag = privacyShieldTag
    shield.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    shield.backgroundColor = UIColor.systemBackground

    let icon = UIImageView(image: UIImage(systemName: "lock.shield"))
    icon.tintColor = UIColor.secondaryLabel
    icon.contentMode = .scaleAspectFit
    icon.translatesAutoresizingMaskIntoConstraints = false
    shield.addSubview(icon)
    NSLayoutConstraint.activate([
      icon.centerXAnchor.constraint(equalTo: shield.centerXAnchor),
      icon.centerYAnchor.constraint(equalTo: shield.centerYAnchor),
      icon.widthAnchor.constraint(equalToConstant: 48),
      icon.heightAnchor.constraint(equalToConstant: 48),
    ])
    window.addSubview(shield)
  }
}
