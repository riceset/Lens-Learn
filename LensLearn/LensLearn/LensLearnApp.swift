//
//  LensLearnApp.swift
//  LensLearn
//
//  Created by Komeno on 2026/06/27.
//

import SwiftUI

@main
struct LensLearnApp: App {
    @StateObject private var wordBank = WordBank()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(wordBank)
        }
    }
}
