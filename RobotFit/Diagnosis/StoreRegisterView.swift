import SwiftUI

struct StoreRegisterView: View {
    @Environment(DiagnosisModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    let existing: SavedStore?
    var onDiagnose: () -> Void = {}

    @State private var name = ""
    @State private var typing = false
    @State private var location: PickedLocation?
    @State private var weekday = ""
    @State private var busyDay = ""
    @State private var peak = ""
    @State private var isAskingListed = false
    @State private var isSearchingPlace = false
    @State private var isSearchingAddress = false
    @State private var isConfirming = false
    @State private var isIncomplete = false
    @State private var loaded = false
    @FocusState private var focus: Field?

    enum Field: Hashable {
        case name
        case weekday
        case busyDay
        case peak
    }

    private var hasName: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }
    private var noLocation: Bool { location == nil }
    private var noSales: Bool { [weekday, busyDay, peak].contains { number($0) == nil } }

    private var missingText: String {
        if noLocation && noSales { return "가게 위치와 평균 판매량을" }
        return noLocation ? "가게 위치를" : "평균 판매량을"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Headline(title: "가게 정보를 등록해 주세요", sub: "대략적인 값도 괜찮아요.\n등록한 정보는 언제든 고칠 수 있어요.")

                header("가게 이름")
                nameField

                header("가게 위치", hint: "선택 · 아직 문을 열기 전이라면 비워 두세요")
                Button {
                    isSearchingAddress = true
                } label: {
                    box {
                        Text(location?.label ?? "입력해주세요")
                            .font(.system(size: 16, weight: location == nil ? .regular : .semibold))
                            .foregroundStyle(location == nil ? Palette.faint : Palette.ink)
                        Spacer()
                        Text("시·도")
                            .font(.system(size: 15))
                            .foregroundStyle(Palette.sub)
                    }
                }
                if let address = location?.address {
                    Label(address, systemImage: "mappin.and.ellipse")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.sub)
                        .padding(.horizontal, 4)
                        .padding(.top, 8)
                }

                header("평균 판매량", hint: "로봇의 생산능력을 비교해서 알려드려요")
                salesField("평일 하루", text: $weekday, field: .weekday, next: .busyDay)
                salesField("금·토 하루", text: $busyDay, field: .busyDay, next: .peak)
                salesField("피크타임 1시간", text: $peak, field: .peak, next: nil)

                if !hasName {
                    Text("상호를 넣으면 저장하거나 진단할 수 있어요.")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.faint)
                        .padding(.horizontal, 4)
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .screenChrome("내 가게 등록")
        .safeAreaInset(edge: .bottom) {
            FooterButtons {
                PrimaryButton(title: "진단하기", enabled: hasName) {
                    focus = nil
                    if noLocation || noSales { isIncomplete = true } else { isConfirming = true }
                }
            }
        }
        .onAppear(perform: load)
        .alert("지도에 등록된 가게인가요?", isPresented: $isAskingListed) {
            Button("아니오", role: .cancel) { startManual() }
            Button("예") { isSearchingPlace = true }
        } message: {
            Text("카카오맵에 있는 가게라면\n이름으로 찾아 위치까지 한 번에 넣어요.")
        }
        .alert("아직 입력하지 않은 정보가 있어요", isPresented: $isIncomplete) {
            Button("취소", role: .cancel) {}
            Button("확인") { saveOnly() }
        } message: {
            Text("\(missingText) 입력하지 않았어요.\n그래도 저장할까요?")
        }
        .alert("가게를 등록했어요", isPresented: $isConfirming) {
            Button("저장만 하기") { saveOnly() }
            Button("진단하기") {
                let saved = toSaved()
                model.save(saved)
                model.diagnose(saved)
                onDiagnose()
                dismiss()
            }
        } message: {
            Text("바로 진단을 시작할까요?\n저장하면 가게 정보만 등록돼요.")
        }
        .fullScreenCover(isPresented: $isSearchingPlace) {
            PlaceSearchSheet { place in
                name = place.name
                location = PickedLocation(place)
            } onManual: {
                startManual()
            }
        }
        .sheet(isPresented: $isSearchingAddress) {
            PostcodeSheet { picked in
                location = picked
            }
        }
    }

    private var nameField: some View {
        Group {
            if typing {
                box {
                    TextField("입력해주세요", text: $name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        .focused($focus, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focus = .weekday }
                        .onChange(of: name) { _, value in
                            if value.count > 30 { name = String(value.prefix(30)) }
                        }
                        .onChange(of: focus) { _, value in
                            if value != .name { typing = false }
                        }
                    Text("상호")
                        .font(.system(size: 15))
                        .foregroundStyle(Palette.sub)
                }
            } else {
                Button {
                    focus = nil
                    isAskingListed = true
                } label: {
                    box {
                        Text(hasName ? name : "입력해주세요")
                            .font(.system(size: 16, weight: hasName ? .semibold : .regular))
                            .foregroundStyle(hasName ? Palette.ink : Palette.faint)
                        Spacer()
                        Text("상호")
                            .font(.system(size: 15))
                            .foregroundStyle(Palette.sub)
                    }
                }
            }
        }
    }

    private func box<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack {
            content()
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.line, lineWidth: 1))
    }

    private func header(_ title: String, hint: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Palette.ink)
            if let hint {
                Text(hint)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.sub)
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 28)
        .padding(.bottom, 10)
    }

    private func salesField(_ label: String, text: Binding<String>, field: Field, next: Field?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 4)
            box {
                TextField("입력해주세요", text: text)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .keyboardType(.numberPad)
                    .focused($focus, equals: field)
                    .onChange(of: text.wrappedValue) { _, value in
                        let digits = String(value.filter(\.isNumber).prefix(4))
                        if digits != value { text.wrappedValue = digits }
                    }
                Text("마리")
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.sub)
            }
        }
        .padding(.bottom, 12)
        .toolbar {
            if focus == field {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(next == nil ? "완료" : "다음") { focus = next }
                }
            }
        }
    }

    private func startManual() {
        typing = true
        DispatchQueue.main.async { focus = .name }
    }

    private func number(_ text: String) -> Double? {
        guard let value = Double(text), value > 0 else { return nil }
        return value
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let existing else { return }
        name = existing.name
        if let address = existing.address {
            location = PickedLocation(isGyeongbuk: existing.isGyeongbuk, label: existing.regionLabel, address: address)
        }
        weekday = existing.weekday.map { String(Int($0)) } ?? ""
        busyDay = existing.busyDay.map { String(Int($0)) } ?? ""
        peak = existing.peak.map { String(Int($0)) } ?? ""
    }

    private func toSaved() -> SavedStore {
        SavedStore(
            id: existing?.id ?? UUID().uuidString,
            name: name.trimmingCharacters(in: .whitespaces),
            isGyeongbuk: location?.isGyeongbuk ?? false,
            regionLabel: location?.label ?? "위치 미정",
            address: location?.address,
            weekday: number(weekday),
            busyDay: number(busyDay),
            peak: number(peak)
        )
    }

    private func saveOnly() {
        model.save(toSaved())
        model.showToast("가게 정보를 저장했어요")
        model.selectedTab = .my
        dismiss()
    }
}

struct Place: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let category: String
    let address: String
    let regionAddress: String
}

struct PickedLocation: Equatable {
    let isGyeongbuk: Bool
    let label: String
    let address: String

    init(isGyeongbuk: Bool, label: String, address: String) {
        self.isGyeongbuk = isGyeongbuk
        self.label = label
        self.address = address
    }

    init(sido: String, sigungu: String, address: String) {
        let city = (sigungu.split(separator: " ").first.map(String.init) ?? "")
            .replacingOccurrences(of: "(시|군|구)$", with: "", options: .regularExpression)
        let shortSido = sido == "경상북도" ? "경북" : sido
        isGyeongbuk = sido == "경상북도" || sido == "경북"
        label = [shortSido, city].filter { !$0.isEmpty }.joined(separator: " ")
        self.address = address
    }

    init(_ place: Place) {
        let parts = place.regionAddress.split(separator: " ").map(String.init)
        self.init(
            sido: parts.first ?? "",
            sigungu: parts.count > 1 ? parts[1] : "",
            address: place.address
        )
    }
}

private struct PlaceSearchSheet: View {
    let onPick: (Place) -> Void
    let onManual: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var places: [Place]?
    @State private var state = SearchState.idle
    @FocusState private var focused: Bool

    enum SearchState {
        case idle
        case loading
        case failed
    }

    private struct Response: Decodable {
        let ok: Bool
        let places: [Place]?
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    TextField("가게 이름과 동네 (예: 민수네 치킨 포항)", text: $query)
                        .font(.system(size: 16))
                        .focused($focused)
                        .submitLabel(.search)
                        .onSubmit { Task { await search() } }
                    Button("검색") { Task { await search() } }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.action)
                }
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(Palette.canvas, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 16)
                Text("카카오맵에 등록된 음식점에서 찾아요.")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.faint)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                ScrollView {
                    VStack(spacing: 0) {
                        switch state {
                        case .loading:
                            message("찾는 중이에요…", manual: false)
                        case .failed:
                            message("지금은 검색을 쓸 수 없어요.", manual: true)
                        case .idle:
                            if let places, places.isEmpty {
                                message("검색 결과가 없어요. 동네 이름을 같이 넣어 보세요.", manual: true)
                            }
                            ForEach(places ?? []) { place in
                                Button {
                                    onPick(place)
                                    dismiss()
                                } label: {
                                    HStack(spacing: 12) {
                                        IconTile(systemName: "storefront.fill", tint: Palette.action)
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                                Text(place.name)
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundStyle(Palette.ink)
                                                Text(place.category)
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(Palette.faint)
                                            }
                                            Text(place.address)
                                                .font(.system(size: 13))
                                                .foregroundStyle(Palette.sub)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right").foregroundStyle(Palette.faint)
                                    }
                                    .padding(.vertical, 14)
                                }
                                Divider()
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                .scrollDismissesKeyboard(.immediately)
            }
            .background(Color.white.ignoresSafeArea())
            .navigationTitle("가게 찾기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark").foregroundStyle(Palette.ink)
                    }
                    .accessibilityLabel("닫기")
                }
            }
            .onAppear { focused = true }
        }
    }

    private func message(_ text: String, manual: Bool) -> some View {
        VStack(spacing: 16) {
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(Palette.sub)
                .multilineTextAlignment(.center)
            if manual {
                PrimaryButton(title: "직접 입력하기", style: .secondary) {
                    dismiss()
                    onManual()
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private func search() async {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard text.count >= 2 else { return }
        focused = false
        state = .loading
        var components = URLComponents(string: "https://robotfit.pages.dev/api/places")!
        components.queryItems = [URLQueryItem(name: "q", value: text)]
        do {
            let (data, response) = try await URLSession.shared.data(from: components.url!)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            let decoded = try JSONDecoder().decode(Response.self, from: data)
            guard decoded.ok, let found = decoded.places else { throw URLError(.cannotParseResponse) }
            places = found
            state = .idle
        } catch {
            places = nil
            state = .failed
        }
    }
}
