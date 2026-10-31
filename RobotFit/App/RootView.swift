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
                        .tabItem { Label("진단", systemImage: "stethoscope") }
                        .tag(AppTab.diagnosis)
                    CommunityView()
                        .tabItem { Label("커뮤니티", systemImage: "bubble.left.and.bubble.right") }
                        .tag(AppTab.community)
                    MyView()
                        .tabItem { Label("마이", systemImage: "person") }
                        .tag(AppTab.my)
                }
            } else {
                LoginView()
            }
        }
        .task { await auth.verify() }
    }
}
