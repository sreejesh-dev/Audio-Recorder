//
//  FrequencySpectrumAnalyzer.swift
//  audioWaveRecorder
//
//  Created by Sreejesh C on 20/05/26.
//

import AVFAudio
import Accelerate
import Foundation

final class FrequencySpectrumAnalyzer {
    private let fftSize: Int
    private let bandCount: Int
    private let log2n: vDSP_Length
    private let fftSetup: FFTSetup?

    private var window: [Float]
    private var samples: [Float]
    private var realOut: [Float]
    private var imagOut: [Float]
    private var magnitudes: [Float]

    init(fftSize: Int = 1024, bandCount: Int = 64) {
        let power = Int(log2(Double(max(256, fftSize))))
        self.fftSize = 1 << power
        self.bandCount = bandCount
        self.log2n = vDSP_Length(power)
        self.fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))

        self.window = [Float](repeating: 0, count: self.fftSize)
        vDSP_hann_window(&window, vDSP_Length(self.fftSize), Int32(vDSP_HANN_NORM))

        self.samples = [Float](repeating: 0, count: self.fftSize)
        self.realOut = [Float](repeating: 0, count: self.fftSize / 2)
        self.imagOut = [Float](repeating: 0, count: self.fftSize / 2)
        self.magnitudes = [Float](repeating: 0, count: self.fftSize / 2)
    }

    deinit {
        if let fftSetup {
            vDSP_destroy_fftsetup(fftSetup)
        }
    }

    func analyze(buffer: AVAudioPCMBuffer) -> [Float] {
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0, let channels = buffer.floatChannelData else {
            return zeroBands()
        }

        let channelCount = Int(buffer.format.channelCount)
        if channelCount <= 1 {
            return analyze(channelData: channels[0], frameCount: frameCount)
        }

        let mixCount = min(frameCount, fftSize)
        var mono = [Float](repeating: 0, count: mixCount)
        let scale = Float(1) / Float(channelCount)
        mono.withUnsafeMutableBufferPointer { monoPtr in
            guard let base = monoPtr.baseAddress else { return }
            vDSP_vsmul(channels[0], 1, [scale], base, 1, vDSP_Length(mixCount))
            if channelCount > 1 {
                for channel in 1..<channelCount {
                    vDSP_vsma(
                        channels[channel],
                        1,
                        [scale],
                        base,
                        1,
                        base,
                        1,
                        vDSP_Length(mixCount)
                    )
                }
            }
        }
        return mono.withUnsafeBufferPointer { pointer in
            analyze(channelData: pointer.baseAddress!, frameCount: mixCount)
        }
    }

    func analyze(channelData: UnsafePointer<Float>, frameCount: Int) -> [Float] {
        guard frameCount > 0, let fftSetup else { return zeroBands() }

        let count = min(frameCount, fftSize)
        samples.withUnsafeMutableBufferPointer { dst in
            vDSP_vclr(dst.baseAddress!, 1, vDSP_Length(fftSize))
            vDSP_vmul(channelData, 1, window, 1, dst.baseAddress!, 1, vDSP_Length(count))
        }

        for index in 0..<(fftSize / 2) {
            realOut[index] = samples[index * 2]
            imagOut[index] = samples[index * 2 + 1]
        }

        var split = DSPSplitComplex(realp: &realOut, imagp: &imagOut)
        vDSP_fft_zrip(fftSetup, &split, 1, log2n, FFTDirection(FFT_FORWARD))

        let scale = Float(1) / Float(fftSize)
        magnitudes[0] = 0
        for index in 1..<(fftSize / 2) {
            let re = realOut[index] * scale
            let im = imagOut[index] * scale
            magnitudes[index] = re * re + im * im
        }

        return bucketMagnitudes()
    }

    private func bucketMagnitudes() -> [Float] {
        let binCount = fftSize / 2
        var bands = [Float](repeating: 0, count: bandCount)
        let minBin = 2
        let maxBin = max(minBin + 1, binCount - 1)

        for band in 0..<bandCount {
            let startT = Float(band) / Float(bandCount)
            let endT = Float(band + 1) / Float(bandCount)
            let startBin = minBin + Int(pow(Float(maxBin - minBin), startT))
            let endBin = min(maxBin, minBin + Int(pow(Float(maxBin - minBin), endT)))
            guard endBin > startBin else { continue }

            var sum: Float = 0
            for bin in startBin..<endBin {
                sum += magnitudes[bin]
            }
            let average = sum / Float(endBin - startBin)
            let db = 10 * log10f(max(average, 1e-12))
            let normalized = (db + 55) / 55
            bands[band] = min(max(normalized, 0), 1)
        }

        return bands
    }

    private func zeroBands() -> [Float] {
        [Float](repeating: 0, count: bandCount)
    }
}
