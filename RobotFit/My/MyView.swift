import SwiftUI

struct MyView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(CommunityStore.self) private var community
    @Environment(DiagnosisModel.self) private var diagnosis
    @State private var isRenaming = false
    @State private var newName = ""
    @State private var editingStore: SavedStore?
    @State private var isAddingStore = false

    var body: some View {
        let store = diagnosis.store
        let top = diagnosis.comparison.compared.first

        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        Text(String(auth.displayName.prefix(1)))
                            .font(.title3.bold())
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 48, height: 48)
                            .background(Color.accentColor.opacity(0.15), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(auth.displayName) 사장님")
                                .font(.headline)
                            Text("가게 \(1 + diagnosis.savedStores.count)곳 운영 중 · Apple로 로그인됨")
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

                Section {
                    Button {
                        diagnosis.selectedTab = .diagnosis
                        diagnosis.path = [.result]
                    } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                IconTile(systemName: "storefront")
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(store.name).font(.headline).foregroundStyle(.primary)
                                    Text(store.region == .gyeongbuk ? "경북 포항" : "경북 외 지역")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                            }
                            if let top {
                                Divider()
                                HStack {
                                    VerdictBadge(verdict: top.verdict, text: top.badgeText)
                                    Spacer()
                                    if let best = top.best {
                                        Text(Format.aboutMonths(best.paybackMonths))
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                    }
                                }
                                Text("\(top.robot.displayName) 기준 회수 기간")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    ForEach(diagnosis.savedStores) { saved in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                IconTile(systemName: "storefront")
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(saved.name).font(.headline)
                                        Text(saved.isComplete ? "진단 전" : "작성 중")
                                            .font(.caption2.bold())
                                            .foregroundStyle(saved.isComplete ? Color.accentColor : .secondary)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(saved.isComplete ? Color.accentColor.opacity(0.15) : Color(.systemGray5), in: RoundedRectangle(cornerRadius: 6))
                                    }
                                    Text(saved.regionLabel)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            if saved.isComplete {
                                PrimaryButton(title: "진단해 보기") {
                                    diagnosis.diagnose(saved)
                                    diagnosis.selectedTab = .diagnosis
                                }
                            } else {
                                PrimaryButton(title: "이어서 등록하기", style: .secondary) {
                                    editingStore = saved
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .swipeActions {
                            Button("삭제", role: .destructive) {
                                diagnosis.savedStores.removeAll { $0.id == saved.id }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("내 가게")
                        Spacer()
                        Button("+ 가게 추가") { isAddingStore = true }
                            .font(.subheadline.weight(.semibold))
                            .textCase(nil)
                    }
                }

                Section {
                    NavigationLink {
                        PendingView(title: "판정 기준")
                    } label: {
                        Label { Text("판정 기준") } icon: { IconTile(systemName: "checkmark.shield", tint: Palette.good) }
                    }
                    NavigationLink {
                        PendingView(title: "출처·라이선스")
                    } label: {
                        Label { Text("출처·라이선스") } icon: { IconTile(systemName: "doc.text", tint: .secondary) }
                    }
                    NavigationLink {
                        PendingView(title: "성과 리포트")
                    } label: {
                        Label {
                            HStack(spacing: 6) {
                                Text("성과 리포트")
                                Text("샘플")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 6))
                            }
                        } icon: {
                            IconTile(systemName: "chart.bar", tint: Palette.warn)
                        }
                    }
                }

                Section("내가 쓴 후기") {
                    let mine = community.reviews(by: auth.userID)
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
            .navigationTitle("마이페이지")
            .alert("커뮤니티에 보일 이름", isPresented: $isRenaming) {
                TextField("이름", text: $newName)
                Button("저장") { auth.rename(newName) }
                Button("취소", role: .cancel) {}
            }
            .sheet(isPresented: $isAddingStore) {
                NavigationStack {
                    StoreRegisterView(existing: nil)
                        .toolbar { closeButton { isAddingStore = false } }
                }
            }
            .sheet(item: $editingStore) { saved in
                NavigationStack {
                    StoreRegisterView(existing: saved)
                        .toolbar { closeButton { editingStore = nil } }
                }
            }
        }
    }

    private func closeButton(_ action: @escaping () -> Void) -> some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("닫기", action: action)
        }
    }
}

struct PendingView: View {
    let title: String

    var body: some View {
        ScrollView {
            Headline(title: "곧 열려요", sub: "이 화면은 준비 중이에요.")
                .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
