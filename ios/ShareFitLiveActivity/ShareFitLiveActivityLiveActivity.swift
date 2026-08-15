import ActivityKit
import WidgetKit
import SwiftUI

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

struct ShareFitLiveActivityLiveActivity: Widget {
    private let accent = Color(red: 0.35, green: 0.47, blue: 0.95)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ShareFitLiveActivityAttributes.self) { context in
            HStack(spacing: 14) {
                workoutIcon(for: context.attributes.workoutType)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(accent, in: Circle())
                VStack(alignment: .leading, spacing: 5) {
                    Text(context.state.title).font(.headline)
                    Text(context.state.content)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                elapsedTime(context.state)
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .monospacedDigit()
            }
            .padding()
            .activityBackgroundTint(Color(uiColor: .systemBackground))
            .activitySystemActionForegroundColor(accent)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    workoutIcon(for: context.attributes.workoutType)
                        .foregroundStyle(accent)
                        .font(.title2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    elapsedTime(context.state)
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(context.state.title).font(.headline)
                            Text(context.state.content)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        if context.state.isPaused {
                            Label("일시정지", systemImage: "pause.fill")
                                .font(.caption.bold())
                                .foregroundStyle(.orange)
                        }
                    }
                }
            } compactLeading: {
                workoutIcon(for: context.attributes.workoutType)
                    .foregroundStyle(accent)
            } compactTrailing: {
                elapsedTime(context.state)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .frame(maxWidth: 54)
            } minimal: {
                workoutIcon(for: context.attributes.workoutType)
                    .foregroundStyle(accent)
            }
            .keylineTint(accent)
        }
    }

    @ViewBuilder
    private func elapsedTime(_ state: ShareFitLiveActivityAttributes.ContentState) -> some View {
        if state.isPaused {
            Text(formattedElapsed(state.elapsedSeconds))
        } else {
            let timerStart = state.updatedAt.addingTimeInterval(TimeInterval(-state.elapsedSeconds))
            Text(timerInterval: timerStart...Date.distantFuture, countsDown: false)
        }
    }

    private func workoutIcon(for workoutType: String) -> Image {
        Image(systemName: workoutType == "running" ? "figure.run" : "dumbbell.fill")
    }

    private func formattedElapsed(_ seconds: Int) -> String {
        let safeSeconds = max(seconds, 0)
        let hours = safeSeconds / 3600
        let minutes = (safeSeconds % 3600) / 60
        let remainingSeconds = safeSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        }
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}
