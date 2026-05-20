//
//  WaveformSmoothing.swift
//  audioWaveRecorder
//
//  Created by Sreejesh C on 20/05/26.
//

import Foundation
import SwiftUI

enum WaveformSmoothing {
    static let silenceThreshold: Float = 0.045

    static let minimumFlowAmplitude: Float = 0.2

    static func followEnvelope(current: Float, target: Float, attack: Float = 0.28, release: Float = 0.14) -> Float {
        let voice = target < silenceThreshold ? 0 : visualLevel(from: target)
        let effectiveTarget = max(voice, minimumFlowAmplitude)
        let factor = effectiveTarget > current ? attack : release
        return current + (effectiveTarget - current) * factor
    }

    static func liveAmplitude(from level: Float) -> Float {
        let voice = level >= silenceThreshold ? visualLevel(from: level) : 0
        return max(voice, minimumFlowAmplitude)
    }

    static func isSilent(level: Float) -> Bool {
        level < silenceThreshold
    }

    static func visualLevel(from level: Float) -> Float {
        guard level >= silenceThreshold else { return 0 }
        let clamped = min(max(level, 0), 1)
        let quietCurve = pow(clamped, 0.42)
        let loudBoost = clamped * clamped * 0.42
        return min(max(quietCurve * 0.72 + loudBoost + 0.1, 0.1), 1)
    }

    static func liveWaveHeightScale(for level: Float) -> CGFloat {
        let amplitude = liveAmplitude(from: level)
        return 0.3 + CGFloat(amplitude) * 0.32
    }

    static func peakLevel(in history: [Float]) -> Float {
        history.max() ?? 0
    }

    static func smooth(_ samples: [Float], window: Int = 5, passes: Int = 2) -> [Float] {
        guard samples.count > 2 else { return samples }
        var result = samples
        let radius = max(1, window / 2)

        for _ in 0..<passes {
            var pass = result
            for index in result.indices {
                var sum: Float = 0
                var count: Float = 0
                for offset in -radius...radius {
                    let neighbor = index + offset
                    guard neighbor >= 0, neighbor < result.count else { continue }
                    sum += result[neighbor]
                    count += 1
                }
                pass[index] = sum / count
            }
            result = pass
        }
        return result
    }

    static func idleWaveSamples(count: Int = 96) -> [Float] {
        Array(repeating: 0.02, count: count)
    }

    static let spectrumBandCount = 64
    static let spectrumWavePointCount = 96

    static func spectrumWaveSamples(
        bands: [Float],
        phase: CGFloat = 0,
        count: Int = spectrumWavePointCount
    ) -> [Float] {
        let resampled = resample(bands.isEmpty ? idleWaveSamples(count: spectrumBandCount) : bands, to: count)
        let smoothed = smooth(resampled, window: 7, passes: 2)
        let energy = smoothed.reduce(0, +) / Float(max(smoothed.count, 1))
        let flowFloor: Float = energy > 0.04 ? 0.03 : minimumFlowAmplitude * 0.35
        let p = Float(phase)

        return smoothed.enumerated().map { index, band in
            let x = Float(index) / Float(max(count - 1, 1))
            let ripple = 1 + 0.06 * sin((x * 2.4 + p * 0.35) * .pi * 2)
            let shaped = max(band * ripple, flowFloor)
            return min(max(shaped, 0.02), 1)
        }
    }

    static func normalizedSpectrumBands(_ bands: [Float]) -> [Float] {
        guard !bands.isEmpty else { return bands }
        let peak = bands.max() ?? 0
        guard peak > 0.02 else {
            return bands.map { _ in minimumFlowAmplitude * 0.35 }
        }
        let targetPeak: Float = 0.72
        let gain = targetPeak / peak
        return bands.map { min(max($0 * gain, minimumFlowAmplitude * 0.35), 1) }
    }

    static func spectrumWaveHeightScale(bands: [Float]) -> CGFloat {
        let peak = bands.max() ?? 0
        let amplitude = max(visualLevel(from: peak), minimumFlowAmplitude * 0.5)
        return 0.28 + CGFloat(amplitude) * 0.38
    }

    static func followSpectrumBands(current: [Float], target: [Float]) -> [Float] {
        let count = max(current.count, target.count, spectrumBandCount)
        var result = [Float](repeating: 0, count: count)
        for index in 0..<count {
            let currentValue = index < current.count ? current[index] : 0
            let targetValue = index < target.count ? target[index] : 0
            result[index] = followEnvelope(current: currentValue, target: targetValue)
        }
        return result
    }

    static func liveWaveSamples(
        level: Float,
        phase: CGFloat,
        count: Int = 96
    ) -> [Float] {
        let amplitude = liveAmplitude(from: level)
        let baseHeight: Float = 0.04
        let p = Float(phase)

        return (0..<count).map { index in
            let x = Float(index) / Float(max(count - 1, 1))

            let wave1 = sin((x * 2.2 + p * 0.5) * .pi * 2)
            let wave2 = sin((x * 3.8 - p * 0.4) * .pi * 2) * 0.55
            let wave3 = sin((x * 1.1 + p * 0.2) * .pi * 2) * 0.35
            let wave4 = sin((x * 5.5 + p * 0.15) * .pi * 2) * 0.2

            let combined = (wave1 + wave2 + wave3 + wave4) / 2.1
            let normalized = (combined + 1) * 0.5
            let loudnessGain = 0.8 + amplitude * 0.42
            return baseHeight + normalized * amplitude * loudnessGain
        }
    }

    static func resample(_ samples: [Float], to count: Int) -> [Float] {
        guard !samples.isEmpty, count > 1 else { return samples }
        if samples.count == count { return samples }

        return (0..<count).map { index in
            let position = Float(index) / Float(count - 1) * Float(samples.count - 1)
            let lower = Int(floor(position))
            let upper = min(lower + 1, samples.count - 1)
            let fraction = position - Float(lower)
            return samples[lower] * (1 - fraction) + samples[upper] * fraction
        }
    }

    static func playbackBandsFromWaveform(
        samples: [Float],
        currentTime: TimeInterval,
        duration: TimeInterval,
        bandCount: Int = spectrumBandCount,
        windowRadius: Int = 12
    ) -> [Float] {
        guard duration > 0, samples.count >= 2 else {
            return [Float](repeating: 0, count: bandCount)
        }

        let center = (currentTime / duration) * Double(samples.count - 1)
        var window: [Float] = []
        for offset in -windowRadius...windowRadius {
            let idx = center + Double(offset)
            let clamped = min(max(idx, 0), Double(samples.count - 1))
            let lower = Int(floor(clamped))
            let upper = min(lower + 1, samples.count - 1)
            let frac = Float(clamped - Double(lower))
            let value = samples[lower] * (1 - frac) + samples[upper] * frac
            window.append(value)
        }

        var bands = resample(window, to: bandCount)
        for index in bands.indices {
            let position = Float(index) / Float(max(bandCount - 1, 1))
            let tilt = 0.85 + 0.3 * position
            let shaped = min(max(bands[index] * tilt, 0), 1)
            bands[index] = max(visualLevel(from: shaped), minimumFlowAmplitude * 0.35)
        }
        return normalizedSpectrumBands(bands)
    }

    static func playbackDriveLevel(
        samples: [Float],
        currentTime: TimeInterval,
        duration: TimeInterval,
        neighborRadius: Int = 5
    ) -> Float {
        guard duration > 0, samples.count >= 2 else { return 0 }
        let n = samples.count
        let center = (currentTime / duration) * Double(n - 1)

        var weightedSum: Float = 0
        var weightTotal: Float = 0
        for offset in -neighborRadius...neighborRadius {
            let idx = center + Double(offset)
            let clamped = min(max(idx, 0), Double(n - 1))
            let lower = Int(floor(clamped))
            let upper = min(lower + 1, n - 1)
            let frac = Float(clamped - Double(lower))
            let value = samples[lower] * (1 - frac) + samples[upper] * frac
            let w = 1 / (1 + Float(abs(offset)))
            weightedSum += value * w
            weightTotal += w
        }
        return weightedSum / max(weightTotal, 0.0001)
    }
}

enum WaveformPathBuilder {
    static func wavePoints(
        samples: [Float],
        size: CGSize,
        baselineRatio: CGFloat = 0.55,
        waveHeightScale: CGFloat = 0.42
    ) -> [CGPoint] {
        let baselineY = size.height * baselineRatio
        let count = samples.count
        guard count > 0 else { return [] }

        let stepX = size.width / CGFloat(max(count - 1, 1))
        return samples.enumerated().map { index, sample in
            let amplitude = CGFloat(min(max(sample, 0), 1))
            let waveHeight = amplitude * size.height * waveHeightScale
            return CGPoint(
                x: CGFloat(index) * stepX,
                y: baselineY - waveHeight
            )
        }
    }

    static func filledWavePath(
        points: [CGPoint],
        size: CGSize,
        baselineRatio: CGFloat = 0.55
    ) -> Path {
        var path = Path()
        guard !points.isEmpty else { return path }

        let baselineY = size.height * baselineRatio
        path.move(to: CGPoint(x: 0, y: baselineY))
        addSmoothCurve(to: &path, points: points)
        path.addLine(to: CGPoint(x: size.width, y: baselineY))
        path.addLine(to: CGPoint(x: 0, y: baselineY))
        path.closeSubpath()
        return path
    }

    static func strokeWavePath(points: [CGPoint]) -> Path {
        var path = Path()
        guard !points.isEmpty else { return path }
        addSmoothCurve(to: &path, points: points)
        return path
    }

    private static func addSmoothCurve(to path: inout Path, points: [CGPoint]) {
        guard let first = points.first else { return }
        path.move(to: first)
        guard points.count > 1 else { return }

        if points.count == 2 {
            path.addLine(to: points[1])
            return
        }

        for index in 0..<(points.count - 1) {
            let previous = index > 0 ? points[index - 1] : points[index]
            let current = points[index]
            let next = points[index + 1]
            let following = index + 2 < points.count ? points[index + 2] : next

            let control1 = CGPoint(
                x: current.x + (next.x - previous.x) / 6,
                y: current.y + (next.y - previous.y) / 6
            )
            let control2 = CGPoint(
                x: next.x - (following.x - current.x) / 6,
                y: next.y - (following.y - current.y) / 6
            )
            path.addCurve(to: next, control1: control1, control2: control2)
        }
    }
}

