import AuthenticationServices
import SwiftUI

struct LoginView: View {
    @Environment(AuthStore.self) private var auth

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "frying.pan.fill")
                .font(.system(size: 56))
                .foregroundStyle(.orange)
            Text("로봇핏")
                .font(.largeTitle.bold())
            Text("우리 주방에 맞는 조리로봇을 찾고\n먼저 도입한 사장님들과 경험을 나눠요")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName]
            } onCompletion: { result in
                auth.handle(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 52)
        }
        .padding(24)
    }
}
