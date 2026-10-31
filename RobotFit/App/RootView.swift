import SwiftUI

struct RootView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(DiagnosisModel.self) private var diagnosis

    var body: some View {
        Group {
            if auth.isSignedIn {
                @Bindable var diagnosis = diagnosis
                TabView(selection: $diagnosis.selectedTab) {
                    DiagnosisTab()
                        .tabItem { Label("홈", image: "TabHome") }
                        .tag(AppTab.diagnosis)
                    QuoteHistoryView()
                        .tabItem { Label("견적 기록", image: "TabQuotes") }
                        .tag(AppTab.quotes)
                    MyView()
                        .tabItem { Label("마이페이지", image: "TabMy") }
                        .tag(AppTab.my)
                }
            } else {
                LoginView()
            }
        }
        .overlay(alignment: .bottom) {
            if let toast = diagnosis.toast {
                Text(toast)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Palette.ink.opacity(0.9), in: Capsule())
                    .padding(.bottom, 110)
                    .transition(.opacity)
            }
        }
        .animation(.snappy, value: diagnosis.toast)
        .task { await auth.verify() }
    }
}
