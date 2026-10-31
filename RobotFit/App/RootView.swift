import SwiftUI

struct RootView: View {
    @Environment(AuthStore.self) private var auth

    var body: some View {
        Group {
            if auth.isSignedIn {
                TabView {
                    DiagnosisTab()
                        .tabItem { Label("진단", systemImage: "stethoscope") }
                    ScanView()
                        .tabItem { Label("주방 스캔", systemImage: "viewfinder") }
                    CommunityView()
                        .tabItem { Label("커뮤니티", systemImage: "bubble.left.and.bubble.right") }
                    MyView()
                        .tabItem { Label("마이", systemImage: "person") }
                }
            } else {
                LoginView()
            }
        }
        .task { await auth.verify() }
    }
}
