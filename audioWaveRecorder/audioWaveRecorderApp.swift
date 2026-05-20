//
//  audioWaveRecorderApp.swift
//  audioWaveRecorder
//
//  Created by Sreejesh C on 20/05/26.
//

import SwiftUI

@main
struct audioWaveRecorderApp: App {
    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            HomeView(viewModel: container.makeHomeViewModel())
                .environmentObject(container)
                .environmentObject(container.playbackSession)
        }
    }
}
