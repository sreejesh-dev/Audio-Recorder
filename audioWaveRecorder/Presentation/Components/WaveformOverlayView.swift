//
//  WaveformOverlayView.swift
//  audioWaveRecorder
//
//  Created by Sreejesh C on 20/05/26.
//

import SwiftUI
import Combine

struct WaveformOverlayView: View, Equatable {
    let frequencyBands: [Float]
    let isFrozen: Bool
    var progress: CGFloat = 1
    var usesContentInsets: Bool = true

    @State private var displayBands: [Float] = [Float](
        repeating: 0,
        count: WaveformSmoothing.spectrumBandCount
    )
    @State private var frozenSamples: [Float] = WaveformSmoothing.idleWaveSamples(
        count: WaveformSmoothing.spectrumWavePointCount
    )

    static func == (lhs: WaveformOverlayView, rhs: WaveformOverlayView) -> Bool {
        lhs.isFrozen == rhs.isFrozen
            && lhs.progress == rhs.progress
            && lhs.usesContentInsets == rhs.usesContentInsets
            && bandsAreSimilar(lhs.frequencyBands, rhs.frequencyBands)
    }

    var body: some View {
        Group {
            if isFrozen {
                waveformLayer(samples: frozenSamples)
            } else {
                TimelineView(.animation(minimumInterval: 1 / 30, paused: false)) { timeline in
                    let phase = CGFloat(
                        timeline.date.timeIntervalSinceReferenceDate
                            .truncatingRemainder(dividingBy: 10)
                    )
                    let samples = WaveformSmoothing.spectrumWaveSamples(
                        bands: displayBands,
                        phase: phase
                    )
                    waveformLayer(samples: samples)
                }
            }
        }
        .allowsHitTesting(false)
        .animation(nil, value: isFrozen)
        .onAppear(perform: syncBandsFromInput)
        .onChange(of: frequencyBands) { _, _ in
            applyIncomingBands()
        }
        .onChange(of: isFrozen) { _, frozen in
            if frozen {
                syncBandsFromInput()
            }
        }
        .onReceive(liveTick) { _ in
            guard !isFrozen else { return }
            displayBands = WaveformSmoothing.followSpectrumBands(
                current: displayBands,
                target: normalizedBands(frequencyBands)
            )
        }
    }

    private var liveTick: Publishers.Autoconnect<Timer.TimerPublisher> {
        Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()
    }

    private func applyIncomingBands() {
        if isFrozen {
            syncBandsFromInput()
        } else {
            displayBands = WaveformSmoothing.followSpectrumBands(
                current: displayBands,
                target: normalizedBands(frequencyBands)
            )
        }
    }

    private func syncBandsFromInput() {
        let target = normalizedBands(frequencyBands)
        let samples = WaveformSmoothing.spectrumWaveSamples(bands: target, phase: 0)

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            displayBands = target
            frozenSamples = samples
        }
    }

    private func waveformLayer(samples: [Float]) -> some View {
        FilledWaveformView(
            samples: samples,
            progress: progress,
            activeColor: AppTheme.waveformBlue,
            fillColor: AppTheme.waveformFill,
            baselineRatio: 0.98,
            waveHeightScale: WaveformSmoothing.spectrumWaveHeightScale(bands: displayBands),
            smoothSamples: false
        )
        .modifier(WaveformContentInsets(enabled: usesContentInsets))
    }

    private func normalizedBands(_ bands: [Float]) -> [Float] {
        guard !bands.isEmpty else {
            return [Float](repeating: 0, count: WaveformSmoothing.spectrumBandCount)
        }
        return WaveformSmoothing.resample(bands, to: WaveformSmoothing.spectrumBandCount)
    }

    private static func bandsAreSimilar(_ lhs: [Float], _ rhs: [Float]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for index in lhs.indices {
            if Int(lhs[index] * 24) != Int(rhs[index] * 24) {
                return false
            }
        }
        return true
    }
}

private struct WaveformContentInsets: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content
                .padding(.top, 4)
                .padding(.bottom, 2)
        } else {
            content
        }
    }
}
