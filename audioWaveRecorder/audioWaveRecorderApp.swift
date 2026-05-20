//
//  audioWaveRecorderApp.swift
//  audioWaveRecorder
//
<<<<<<< HEAD
//  Created by Sreejesh C on 18/05/26.
=======
//  Created by Sreejesh C on 20/05/26.
>>>>>>> main
//

import SwiftUI

@main
struct audioWaveRecorderApp: App {
<<<<<<< HEAD
    var body: some Scene {
        WindowGroup {
            ContentView()
=======
    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            HomeView(viewModel: container.makeHomeViewModel())
                .environmentObject(container)
                .environmentObject(container.playbackSession)
>>>>>>> main
        }
    }
}
