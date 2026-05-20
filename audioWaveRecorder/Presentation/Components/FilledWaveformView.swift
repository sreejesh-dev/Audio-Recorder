//
//  FilledWaveformView.swift
//  audioWaveRecorder
//
//  Created by Sreejesh C on 20/05/26.
//

import SwiftUI

struct FilledWaveformView: View {
    let samples: [Float]
    var progress: CGFloat = 1
    var activeColor: Color = AppTheme.waveformBlue
    var fillColor: Color = AppTheme.waveformFill
    var baselineRatio: CGFloat = 0.55
    var waveHeightScale: CGFloat = 0.42
    var smoothSamples: Bool = true

    var body: some View {
        Canvas { context, size in
            let processed = processedSamples
            guard !processed.isEmpty else { return }

            let points = WaveformPathBuilder.wavePoints(
                samples: processed,
                size: size,
                baselineRatio: baselineRatio,
                waveHeightScale: waveHeightScale
            )
            let playableWidth = size.width * min(max(progress, 0), 1)

            let fillPath = WaveformPathBuilder.filledWavePath(
                points: points,
                size: size,
                baselineRatio: baselineRatio
            )
            let strokePath = WaveformPathBuilder.strokeWavePath(points: points)

            var clipRect = Path()
            clipRect.addRect(CGRect(x: 0, y: 0, width: playableWidth, height: size.height))
            context.clip(to: clipRect)
            context.fill(fillPath, with: .color(fillColor))
            context.stroke(
                strokePath,
                with: .color(activeColor),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
            )
        }
        .drawingGroup()
    }

    private var processedSamples: [Float] {
        guard !samples.isEmpty else { return [] }
        let resampled = WaveformSmoothing.resample(samples, to: 96)
        guard smoothSamples else { return resampled }
        return WaveformSmoothing.smooth(resampled, window: 7, passes: 2)
    }
}
