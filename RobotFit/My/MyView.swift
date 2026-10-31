import SwiftUI

struct MyView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(DiagnosisModel.self) private var diagnosis
    @State private var showsAccount = false
    @State private var editingStore: SavedStore?
    @State private var isAddingStore = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("마이페이지")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 4)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                    Button {
                        showsAccount = true
                    } label: {
                        Card {
                            HStack(spacing: 16) {
                                Text(String(auth.displayName.prefix(1)))
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(Palette.action)
                                    .frame(width: 56, height: 56)
                                    .background(Palette.action.opacity(0.08), in: Circle())
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(auth.displayName) 사장님")
                                        .font(.system(size: 19, weight: .bold))
                                        .foregroundStyle(Palette.ink)
                                    Text("가게 \(1 + diagnosis.savedStores.count)곳 운영 중")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Palette.sub)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(Palette.faint)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    HStack {
                        Text("내 가게")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Palette.sub)
                        Spacer()
                        Button("+ 가게 추가") { isAddingStore = true }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.blue)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 4)

                    currentStore

                    ForEach(diagnosis.savedStores) { saved in
                        savedStoreCard(saved)
                    }

                    Card(padding: 8) {
                        link("출처·라이선스", icon: "doc.text.fill", tint: .teal) {
                            SourcesView()
                        }
                        Divider().padding(.horizontal, 12)
                        link("성과 리포트", icon: "chart.bar.fill", tint: .purple, tag: "샘플", sub: "도입 후 달라진 점을 한눈에 봐요") {
                            ReportView()
                        }
                    }
                    .padding(.top, 16)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Palette.canvas.ignoresSafeArea())
            .sheet(isPresented: $showsAccount) {
                NavigationStack {
                    AccountView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("닫기") { showsAccount = false }
                            }
                        }
                }
            }
            .navigationDestination(isPresented: $isAddingStore) {
                StoreRegisterView(existing: nil) { diagnosis.selectedTab = .diagnosis }
            }
            .navigationDestination(item: $editingStore) { saved in
                StoreRegisterView(existing: saved) { diagnosis.selectedTab = .diagnosis }
            }
        }
    }

    private var currentStore: some View {
        let store = diagnosis.store
        let top = diagnosis.comparison.compared.first
        let location = diagnosis.savedStores.last(where: { $0.name == store.name && $0.address != nil })?.regionLabel
            ?? (!diagnosis.edited.contains(.region) ? "위치 미정" : store.region == .gyeongbuk ? "경북" : "경북 외 지역")

        return Button {
            if diagnosis.isReady {
                diagnosis.selectedTab = .diagnosis
                diagnosis.path = [.result]
            } else {
                isAddingStore = true
            }
        } label: {
            Card {
                HStack(spacing: 14) {
                    storeIcon
                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.name)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Palette.ink)
                        Text(location)
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.sub)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(Palette.faint)
                }
                Divider().padding(.vertical, 14)
                if diagnosis.isReady, let top {
                    HStack {
                        VerdictBadge(verdict: top.verdict, text: top.badgeText, large: true)
                        Spacer()
                        if let best = top.best {
                            Text(Format.aboutMonths(best.paybackMonths))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Palette.ink)
                        }
                    }
                    Text(caption(top.robot.displayName))
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.sub)
                        .padding(.top, 12)
                } else {
                    Text("아직 진단하지 않았어요")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.sub)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func caption(_ robotName: String) -> String {
        guard let date = diagnosis.diagnosedAt else { return "\(robotName) 기준 회수 기간" }
        let day = date.formatted(.verbatim("\(month: .defaultDigits)월 \(day: .defaultDigits)일", timeZone: .current, calendar: .current))
        return "\(robotName) 기준 회수 기간 · \(day) 진단"
    }

    private func savedStoreCard(_ saved: SavedStore) -> some View {
        Card {
            HStack(spacing: 14) {
                storeIcon
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(saved.name)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Palette.ink)
                        Text(saved.isComplete ? "진단 전" : "작성 중")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(saved.isComplete ? Palette.action : Palette.sub)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(saved.isComplete ? Palette.action.opacity(0.12) : Palette.line, in: RoundedRectangle(cornerRadius: 6))
                    }
                    Text(saved.regionLabel)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.sub)
                }
                Spacer()
                Menu {
                    Button("삭제", role: .destructive) {
                        diagnosis.savedStores.removeAll { $0.id == saved.id }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(Palette.faint)
                        .frame(width: 32, height: 32)
                }
            }
            Group {
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
            .padding(.top, 16)
        }
    }

    private var storeIcon: some View {
        Image(systemName: "storefront.fill")
            .font(.system(size: 18))
            .foregroundStyle(Palette.action)
            .frame(width: 44, height: 44)
            .background(Palette.action.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
    }

    private func link<Destination: View>(_ title: String, icon: String, tint: Color, tag: String? = nil, sub: String? = nil, @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink(destination: destination()) {
            HStack(spacing: 14) {
                IconTile(systemName: icon, tint: tint)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 16))
                            .foregroundStyle(Palette.ink)
                        if let tag { SmallTag(text: tag) }
                    }
                    if let sub {
                        Text(sub)
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.sub)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Palette.faint)
            }
            .padding(12)
        }
        .buttonStyle(.plain)
    }

}

private struct AccountView: View {
    @Environment(AuthStore.self) private var auth
    @State private var isRenaming = false
    @State private var newName = ""

    var body: some View {
        List {
            Section {
                LabeledContent("이름", value: "\(auth.displayName) 사장님")
                LabeledContent("로그인", value: "Apple")
                Button("이름 변경") {
                    newName = auth.displayName
                    isRenaming = true
                }
            }
            Section {
                Button("로그아웃", role: .destructive) {
                    auth.signOut()
                }
            }
        }
        .navigationTitle("내 정보")
        .navigationBarTitleDisplayMode(.inline)
        .alert("커뮤니티에 보일 이름", isPresented: $isRenaming) {
            TextField("이름", text: $newName)
            Button("저장") { auth.rename(newName) }
            Button("취소", role: .cancel) {}
        }
    }
}
