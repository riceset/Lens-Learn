//
//  ContentView.swift
//  LensLearn
//
//  Created by Komeno on 2026/06/27.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        RootView()
            .environmentObject(WordBank())
    }
}

struct ContentViewPreviews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
