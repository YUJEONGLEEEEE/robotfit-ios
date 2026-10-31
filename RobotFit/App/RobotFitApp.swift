import SwiftUI

@main
struct RobotFitApp: App {
    @State private var auth = AuthStore()
    @State private var community = CommunityStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(community)
        }
    }
}
