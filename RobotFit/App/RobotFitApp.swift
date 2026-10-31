import SwiftUI

@main
struct RobotFitApp: App {
    @State private var auth = AuthStore()
    @State private var community = CommunityStore()
    @State private var diagnosis = DiagnosisModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(community)
                .environment(diagnosis)
                .dismissesKeyboardOnTap()
        }
    }
}
