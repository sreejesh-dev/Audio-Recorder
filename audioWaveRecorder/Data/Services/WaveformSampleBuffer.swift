//
//  WaveformSampleBuffer.swift
//  audioWaveRecorder
//
//  Created by Sreejesh C on 20/05/26.
//

import Foundation
import AVFAudio

final class WaveformSampleBuffer {
    private let capacity: Int
    private var samples: [Float]
    private var writeIndex = 0
    private var count = 0
    private let smoothing: Float = 0.26

    init(capacity: Int = 120) {
        self.capacity = capacity
        self.samples = Array(repeating: 0, count: capacity)
    }

    private var latestLevel: Float = 0

    func append(level: Float) {
        let clamped = min(max(level, 0), 1)
        let previous = count > 0 ? samples[(writeIndex + capacity - 1) % capacity] : 0
        let smoothed = previous * (1 - smoothing) + clamped * smoothing
        latestLevel = smoothed
        samples[writeIndex] = smoothed
        writeIndex = (writeIndex + 1) % capacity
        count = min(count + 1, capacity)
    }

    func latestSmoothedLevel() -> Float {
        latestLevel
    }

    func snapshot() -> [Float] {
        guard count > 0 else { return [] }
        if count < capacity {
            return Array(samples.prefix(count))
        }
        return (0..<capacity).map { samples[(writeIndex + $0) % capacity] }
    }

    func drain() -> [Float] {
        let result = snapshot()
        reset()
        return result
    }

    func reset() {
        samples = Array(repeating: 0, count: capacity)
        writeIndex = 0
        count = 0
    }
}

enum WaveformSampleGenerator {
    static func generate(from url: URL, targetCount: Int = 80) async -> [Float] {
        await Task.detached(priority: .utility) {
            guard let file = try? AVAudioFile(forReading: url) else { return [] }
            let format = file.processingFormat
            let frameCount = AVAudioFrameCount(file.length)
            guard frameCount > 0,
                  let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                return []
            }
            try? file.read(into: buffer)
            guard let channelData = buffer.floatChannelData?[0] else { return [] }
            let totalFrames = Int(buffer.frameLength)
            guard totalFrames > 0 else { return [] }

            let bucketSize = max(1, totalFrames / targetCount)
            var samples: [Float] = []
            samples.reserveCapacity(targetCount)

            var index = 0
            while index < totalFrames {
                let end = min(index + bucketSize, totalFrames)
                var peak: Float = 0
                for frame in index..<end {
                    peak = max(peak, abs(channelData[frame]))
                }
                samples.append(min(peak * 4, 1))
                index = end
            }
            guard samples.count >= 2 else { return samples }
            let smoothed = WaveformSmoothing.smooth(samples, window: 9, passes: 3)
            return smoothed.map { pow(min(max($0, 0), 1), 1.05) }
        }.value
    }
}
