//
//  RecordingSessionSheet.swift
//  audioWaveRecorder
//
//  Created by Sreejesh C on 20/05/26.
//

import SwiftUI

import SwiftUI

enum RecordingSheetLayout {
    static let cardCornerRadius: CGFloat = 28
    static let borderWidth: CGFloat = 1
    static let statusPillHeight: CGFloat = 88
    static let collapsedCardHeight: CGFloat = 72
    static let collapsedWaveHeight: CGFloat = 40
    static let handleSize: CGFloat = 36
    static let handleOverlap: CGFloat = 18
}

struct RecordingSessionSheet: View {
    @Binding var isExpanded: Bool
    let duration: TimeInterval
    let isPaused: Bool
    let frequencyBands: [Float]
    let onTogglePause: () -> Void
    let onDone: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            cardBody

            collapseHandle
                .offset(y: -RecordingSheetLayout.handleOverlap)
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.88), value: isExpanded)
    }


    private var cardBody: some View {
        VStack(spacing: 12) {
            if isExpanded {
                recordingStatusPill
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .bottom)))

                donePill
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                collapsedRecordingBar
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, isExpanded ? 26 : 22)
        .padding(.bottom, isExpanded ? 16 : 12)
        .frame(maxWidth: .infinity)
        .frame(minHeight: isExpanded ? nil : RecordingSheetLayout.collapsedCardHeight)
        .background(
            RoundedRectangle(cornerRadius: RecordingSheetLayout.cardCornerRadius, style: .continuous)
                .fill(AppTheme.card)
        )
        .overlay {
            RoundedRectangle(cornerRadius: RecordingSheetLayout.cardCornerRadius, style: .continuous)
                .strokeBorder(
                    isExpanded || isPaused ? AppTheme.recordingSheetBorder : AppTheme.recordingActive.opacity(0.35),
                    lineWidth: RecordingSheetLayout.borderWidth
                )
        }
        .shadow(color: .black.opacity(0.07), radius: 12, y: 4)
    }


    private var collapsedRecordingBar: some View {
        HStack(spacing: 10) {
            RecordingPulseIndicator(isActive: !isPaused)

            VStack(alignment: .leading, spacing: 2) {
                Text(isPaused ? "Paused" : "Recording")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText)
                Text(duration.mmss)
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .frame(minWidth: 72, alignment: .leading)

            collapsedWaveform
                .frame(maxWidth: .infinity)

            Button(action: onTogglePause) {
                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.recordingControlBackground)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPaused ? "Resume recording" : "Pause recording")

            Button(action: onDone) {
                Image(systemName: "checkmark")
                    .font(.body.weight(.bold))
                    .foregroundStyle(AppTheme.doneAccentGreen)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.doneButtonBackground)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Finish recording")
        }
        .frame(height: RecordingSheetLayout.collapsedCardHeight - 8)
    }

    private var collapsedWaveform: some View {
        ZStack {
            Capsule()
                .fill(AppTheme.recordingControlBackground)

            WaveformOverlayView(
                frequencyBands: frequencyBands,
                isFrozen: isPaused,
                usesContentInsets: false
            )
            .frame(height: RecordingSheetLayout.collapsedWaveHeight)
            .padding(.horizontal, 6)
        }
        .frame(height: RecordingSheetLayout.collapsedWaveHeight + 4)
        .clipShape(Capsule())
    }


    private var collapseHandle: some View {
        Button {
            isExpanded.toggle()
        } label: {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText.opacity(0.55))
                .frame(width: RecordingSheetLayout.handleSize, height: RecordingSheetLayout.handleSize)
                .background(
                    Circle()
                        .fill(AppTheme.card)
                        .shadow(color: .black.opacity(0.08), radius: 4, y: 1)
                )
                .overlay {
                    Circle()
                        .strokeBorder(AppTheme.recordingSheetBorder, lineWidth: RecordingSheetLayout.borderWidth)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isExpanded ? "Collapse recording" : "Expand recording")
    }


    private var recordingStatusPill: some View {
        ZStack {
            Capsule()
                .fill(AppTheme.recordingControlBackground)

            WaveformOverlayView(
                frequencyBands: frequencyBands,
                isFrozen: isPaused
            )
            .frame(maxWidth: .infinity)
            .frame(height: RecordingSheetLayout.statusPillHeight * 0.55)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.horizontal, 8)
            .padding(.bottom, 4)

            HStack(spacing: 8) {
                Button(action: onTogglePause) {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.primaryText)
                }
                .buttonStyle(.plain)

                Text(duration.mmss)
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.primaryText)
            }
        }
        .frame(height: RecordingSheetLayout.statusPillHeight)
        .clipShape(Capsule())
    }


    private var donePill: some View {
        Button(action: onDone) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .font(.body.weight(.bold))
                Text("Done")
                    .font(.title3.weight(.bold))
            }
            .foregroundStyle(AppTheme.doneAccentGreen)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppTheme.doneButtonBackground)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}


private struct RecordingPulseIndicator: View {
    let isActive: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !isActive)) { context in
            let pulse = isActive
                ? 1 + 0.2 * CGFloat(sin(context.date.timeIntervalSinceReferenceDate * 4))
                : 1

            ZStack {
                if isActive {
                    Circle()
                        .fill(AppTheme.recordingActiveSoft)
                        .frame(width: 22, height: 22)
                        .scaleEffect(pulse)
                }

                Circle()
                    .fill(isActive ? AppTheme.recordingActive : AppTheme.secondaryText.opacity(0.35))
                    .frame(width: 10, height: 10)
            }
        }
        .frame(width: 24, height: 24)
        .accessibilityLabel(isActive ? "Recording in progress" : "Recording paused")
    }
}

struct RecordingSheetContainer<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, AppTheme.recordingSheetHorizontalPadding)
            .padding(.bottom, AppTheme.recordingSheetBottomPadding)
            .frame(maxWidth: .infinity)
    }
}
