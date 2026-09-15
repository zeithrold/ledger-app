import AuthenticationServices
import ClerkKit
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var authBridge: LedgerAuthBridge?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LedgerAuth") {
      authBridge = LedgerAuthBridge(messenger: registrar.messenger())
    }
  }
}

/// The SDK owns credentials and hosted-auth verification. Only session identity
/// and explicitly requested short-lived JWTs cross into Dart.
@MainActor
private final class LedgerAuthBridge: NSObject, FlutterStreamHandler {
  private var clerk: Clerk?
  private var sink: FlutterEventSink?
  private var observer: Task<Void, Never>?
  private var revision = 0
  private var signingIn = false

  init(messenger: FlutterBinaryMessenger) {
    super.init()
    FlutterMethodChannel(name: "ledger/auth", binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in
        Task { @MainActor in await self?.handle(call, result: result) }
      }
    FlutterEventChannel(name: "ledger/auth/events", binaryMessenger: messenger)
      .setStreamHandler(self)
  }

  private func snapshot() -> [String: Any] {
    revision += 1
    let session = clerk?.session
    return [
      "revision": revision,
      "active": session?.status == .active,
      "sessionId": session?.id as Any? ?? NSNull(),
      "userId": session?.user?.id as Any? ?? NSNull(),
    ]
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) async {
    do {
      let args = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "initialize":
        guard let key = args["publishableKey"] as? String else {
          result(FlutterError(code: "configuration", message: nil, details: nil)); return
        }
        if clerk == nil {
          clerk = Clerk.configure(publishableKey: key, options: .init(telemetryEnabled: false))
        }
        guard let clerk else { return }
        if !clerk.isLoaded {
          _ = try await clerk.refreshEnvironment()
          _ = try await clerk.refreshClient()
        }
        if observer == nil {
          let events = clerk.auth.events
          observer = Task { @MainActor [weak self] in
            for await _ in events {
              guard let self, !Task.isCancelled else { return }
              self.sink?(self.snapshot())
            }
          }
        }
        result(snapshot())
      case "signIn":
        guard let clerk, clerk.isLoaded, !signingIn else {
          result(FlutterError(code: "unavailable", message: nil, details: nil)); return
        }
        signingIn = true
        defer { signingIn = false }
        try await clerk.auth.startHostedAuth()
        result(snapshot())
      case "token":
        guard let clerk, clerk.session?.status == .active else {
          result(FlutterError(code: "unauthenticated", message: nil, details: nil)); return
        }
        let sessionId = clerk.session?.id
        let token = try await clerk.auth.getToken(.init(skipCache: args["refresh"] as? Bool ?? false))
        guard sessionId == clerk.session?.id else {
          result(FlutterError(code: "session_changed", message: nil, details: nil)); return
        }
        result(token)
      case "signOut":
        guard let clerk else {
          result(FlutterError(code: "unavailable", message: nil, details: nil)); return
        }
        try await clerk.auth.signOut()
        result(snapshot())
      default:
        result(FlutterMethodNotImplemented)
      }
    } catch {
      let cancelled = (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin
        || error is CancellationError
      result(FlutterError(code: cancelled ? "cancelled" : "authentication", message: nil, details: nil))
    }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    if clerk?.isLoaded == true { events(snapshot()) }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }
}
