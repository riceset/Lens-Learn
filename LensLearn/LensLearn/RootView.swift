import SwiftUI

struct RootView: View {
    @EnvironmentObject private var wordBank: WordBank

    var body: some View {
        NavigationStack {
            CaptureView()
                .navigationTitle("Lens & Learn")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        NavigationLink {
                            WordBankView()
                        } label: {
                            Label("Word Bank \(wordBank.saved.count)", systemImage: "bookmark")
                        }
                    }
                }
        }
    }
}

struct RootViewPreviews: PreviewProvider {
    static var previews: some View {
        RootView()
            .environmentObject(WordBank())
    }
}
