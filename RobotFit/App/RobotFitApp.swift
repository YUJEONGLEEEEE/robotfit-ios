import SwiftUI

@main
struct RobotFitApp: App {
    @State private var auth = AuthStore()
    @State private var diagnosis = DiagnosisModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(diagnosis)
                .dismissesKeyboardOnTap()
        }
    }
}
