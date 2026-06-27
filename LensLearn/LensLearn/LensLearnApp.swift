//
//  LensLearnApp.swift
//  LensLearn
//
//  Created by Komeno on 2026/06/27.
//

import SwiftData
import SwiftUI

@main
struct LensLearnApp: App {
    private let container: ModelContainer
    @StateObject private var wordBank: WordBank

    init() {
        let container = try! ModelContainer(for: SavedWord.self)
        self.container = container
        _wordBank = StateObject(wrappedValue: WordBank(context: container.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(wordBank)
                .modelContainer(container)
        }
    }
}
