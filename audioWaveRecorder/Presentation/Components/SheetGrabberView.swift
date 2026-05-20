//
//  SheetGrabberView.swift
//  audioWaveRecorder
//
//  Created by Sreejesh C on 20/05/26.
//

import SwiftUI

struct SheetGrabberView: View {
    var body: some View {
        Color.clear
            .frame(height: 28)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .top) {
                Capsule()
                    .fill(Color.primary.opacity(0.22))
                    .frame(width: 40, height: 5)
                    .padding(.top, 10)
            }
            .accessibilityLabel("Playback sheet handle")
            .accessibilityAddTraits(.isButton)
    }
}
