import Flutter
import UIKit
import ActivityKit

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
    let channel = FlutterMethodChannel(
      name: "com.sharefit.app.sharefit/workout_progress_notification",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard #available(iOS 16.1, *) else {
        result(Optional<Any>.none)
        return
      }
      Task { @MainActor in
        switch call.method {
        case "show":
          guard let arguments = call.arguments as? [String: Any] else {
            result(FlutterError(code: "invalid_arguments", message: nil, details: nil))
            return
          }
          do {
            try await WorkoutLiveActivityController.shared.show(arguments: arguments)
            result(Optional<Any>.none)
          } catch {
            result(FlutterError(code: "live_activity_error", message: error.localizedDescription, details: nil))
          }
        case "stop":
          await WorkoutLiveActivityController.shared.stop()
          result(Optional<Any>.none)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }
}

@available(iOS 16.1, *)
struct ShareFitLiveActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    let title: String
    let content: String
    let elapsedSeconds: Int
    let isPaused: Bool
    let updatedAt: Date
  }
  let workoutType: String
}

@available(iOS 16.1, *)
@MainActor
final class WorkoutLiveActivityController {
  static let shared = WorkoutLiveActivityController()
  private var activity: Activity<ShareFitLiveActivityAttributes>?

  private init() {}

  func show(arguments: [String: Any]) async throws {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
    let state = contentState(from: arguments)
    if let activity {
      await activity.update(using: state)
      return
    }
    for existing in Activity<ShareFitLiveActivityAttributes>.activities {
      await existing.end(using: state, dismissalPolicy: .immediate)
    }
    activity = try Activity.request(
      attributes: ShareFitLiveActivityAttributes(
        workoutType: arguments["workoutType"] as? String ?? "strength"
      ),
      contentState: state,
      pushType: nil
    )
  }

  func stop() async {
    let finalState = ShareFitLiveActivityAttributes.ContentState(
      title: "운동 완료",
      content: "오늘도 수고했어요",
      elapsedSeconds: 0,
      isPaused: true,
      updatedAt: Date()
    )
    for existing in Activity<ShareFitLiveActivityAttributes>.activities {
      await existing.end(using: finalState, dismissalPolicy: .immediate)
    }
    activity = nil
  }

  private func contentState(from arguments: [String: Any]) -> ShareFitLiveActivityAttributes.ContentState {
    ShareFitLiveActivityAttributes.ContentState(
      title: arguments["title"] as? String ?? "운동 중",
      content: arguments["content"] as? String ?? "",
      elapsedSeconds: max((arguments["durationSeconds"] as? NSNumber)?.intValue ?? 0, 0),
      isPaused: arguments["isPaused"] as? Bool ?? false,
      updatedAt: Date()
    )
  }
}
