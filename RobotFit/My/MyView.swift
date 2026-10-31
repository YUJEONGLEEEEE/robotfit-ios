import SwiftUI

struct MyView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(CommunityStore.self) private var store
    @State private var isRenaming = false
    @State private var newName = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.accentColor)
                        VStack(alignment: .leading) {
                            Text(auth.displayName)
                                .font(.title3.bold())
                            Text("Apple로 로그인됨")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("이름 변경") {
                            newName = auth.displayName
                            isRenaming = true
                        }
                        .font(.footnote)
                    }
                }

                Section("내가 쓴 후기") {
                    let mine = store.reviews(by: auth.userID)
                    if mine.isEmpty {
                        Text("아직 쓴 후기가 없어요.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(mine) { review in
                        ReviewRow(review: review)
                    }
                }

                Section {
                    Button("로그아웃", role: .destructive) {
                        auth.signOut()
                    }
                }
            }
            .navigationTitle("마이")
            .alert("커뮤니티에 보일 이름", isPresented: $isRenaming) {
                TextField("이름", text: $newName)
                Button("저장") { auth.rename(newName) }
                Button("취소", role: .cancel) {}
            }
        }
    }
}
