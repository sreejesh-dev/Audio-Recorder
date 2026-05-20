//
//  PlaybackProgressSlider.swift
//  audioWaveRecorder
//
//  Created by Sreejesh C on 20/05/26.
//

import SwiftUI

struct PlaybackProgressSlider: View {
    let progress: Double
    let onScrubBegan: () -> Void
    let onScrubChanged: (Double) -> Void
    let onScrubEnded: (Double) -> Void

    @State private var isEditing = false
    @State private var dragProgress: Double = 0

    var body: some View {
        Slider(
            value: sliderBinding,
            in: 0...1,
            onEditingChanged: handleEditingChanged
        )
        .tint(AppTheme.waveformBlue)
    }

    private var sliderBinding: Binding<Double> {
        Binding(
            get: { isEditing ? dragProgress : progress },
            set: { newValue in
                let clamped = min(max(newValue, 0), 1)
                dragProgress = clamped
                guard isEditing else { return }
                onScrubChanged(clamped)
            }
        )
    }

    private func handleEditingChanged(_ editing: Bool) {
        if editing {
            dragProgress = progress
            isEditing = true
            onScrubBegan()
        } else {
            let committed = dragProgress
            isEditing = false
            onScrubEnded(committed)
        }
    }
}
