//
//  PlaybackSheetView.swift
//  audioWaveRecorder
//
//  Created by Sreejesh C on 20/05/26.
//

import SwiftUI


struct PlaybackSheetView: View {
    let recording: Recording
    let currentTime: TimeInterval
    let duration: TimeInterval
    let isPlaying: Bool
    let isScrubbing: Bool
    let showsPauseControl: Bool
    let frequencyBands: [Float]
    let progress: Double
    let onTogglePlay: () -> Void
    let onScrubBegan: () -> Void
    let onScrubChanged: (Double) -> Void
    let onScrubEnded: (Double) -> Void
    let onClose: () -> Void

    private var displayedTime: TimeInterval {
        currentTime
    }

    private var overlayIsFrozen: Bool {
        isScrubbing || !isPlaying
    }

    var body: some View {
        VStack(spacing: 14) {
            SheetGrabberView()

            headerRow
                .padding(.horizontal, 20)

            playbackWaveStage
                .padding(.horizontal, 20)

            PlaybackProgressSlider(
                progress: progress,
                onScrubBegan: onScrubBegan,
                onScrubChanged: onScrubChanged,
                onScrubEnded: onScrubEnded
            )
            .id(recording.id)
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 12)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(AppTheme.card)
                .shadow(color: .black.opacity(0.08), radius: 24, y: -4)
        )
        .transaction { transaction in
            if isScrubbing {
                transaction.disablesAnimations = true
            }
        }
    }

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(recording.title)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(displayedTime.mmss) / \(duration.mmss)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(nil, value: displayedTime)
            }
            Spacer(minLength: 8)
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .buttonStyle(.plain)
        }
    }

    private var playbackWaveStage: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                .fill(AppTheme.sheetWaveBackground)

            WaveformOverlayView(
                frequencyBands: frequencyBands,
                isFrozen: overlayIsFrozen,
                usesContentInsets: false
            )
            .equatable()

            Button(action: onTogglePlay) {
                Image(systemName: showsPauseControl ? "pause.fill" : "play.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(width: 48, height: 48)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 44)
            .animation(nil, value: showsPauseControl)
        }
        .frame(height: 150)
        .clipShape(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
        )
    }
}
