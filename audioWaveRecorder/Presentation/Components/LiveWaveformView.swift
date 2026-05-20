//
//  LiveWaveformView.swift
//  audioWaveRecorder
//
//  Created by Sreejesh C on 20/05/26.
//

import SwiftUI

struct LiveWaveformView: View {
    let level: Float
    let isPaused: Bool
    var progress: CGFloat = 1

    @State private var smoothedLevel: Float = WaveformSmoothing.minimumFlowAmplitude
    @State private var frozenSamples: [Float] = WaveformSmoothing.idleWaveSamples()

    var body: some View {
        Group {
            if isPaused {
                waveformView(samples: frozenSamples, meterLevel: smoothedLevel)
            } else {
                TimelineView(.animation(minimumInterval: 1 / 60)) { timeline in
                    let phase = CGFloat(
                        timeline.date.timeIntervalSinceReferenceDate
                            .truncatingRemainder(dividingBy: 10)
                    )
                    let samples = WaveformSmoothing.liveWaveSamples(
                        level: smoothedLevel,
                        phase: phase
                    )
                    waveformView(samples: samples, meterLevel: smoothedLevel)
                        .onAppear { frozenSamples = samples }
                        .onChange(of: samples) { _, newValue in
                            frozenSamples = newValue
                        }
                }
            }
        }
        .onAppear {
            smoothedLevel = WaveformSmoothing.liveAmplitude(from: level)
        }
        .onChange(of: level) { _, newLevel in
            if isPaused {
                let target = WaveformSmoothing.liveAmplitude(from: newLevel)
                smoothedLevel = target
                frozenSamples = WaveformSmoothing.liveWaveSamples(level: target, phase: 0)
            }
        }
        .onReceive(Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()) { _ in
            guard !isPaused else { return }
            smoothedLevel = WaveformSmoothing.followEnvelope(
                current: smoothedLevel,
                target: level
            )
        }
    }

    private func waveformView(samples: [Float], meterLevel: Float) -> some View {
        FilledWaveformView(
            samples: samples,
            progress: progress,
            activeColor: AppTheme.waveformBlue,
            fillColor: AppTheme.waveformFill,
            baselineRatio: 0.98,
            waveHeightScale: WaveformSmoothing.liveWaveHeightScale(for: meterLevel),
            smoothSamples: false
        )
        .padding(.top, 4)
        .padding(.bottom, 2)
    }
}
