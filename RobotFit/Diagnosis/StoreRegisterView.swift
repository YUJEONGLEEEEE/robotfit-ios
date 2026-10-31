import MapKit
import SwiftUI

struct StoreRegisterView: View {
    @Environment(DiagnosisModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    let existing: SavedStore?
    var onDiagnose: () -> Void = {}

    @State private var name = ""
    @State private var location: PickedLocation?
    @State private var weekday = ""
    @State private var busyDay = ""
    @State private var peak = ""
    @State private var isAskingListed = false
    @State private var isSearchingPlace = false
    @State private var isSearchingAddress = false
    @State private var isConfirming = false
    @State private var isIncomplete = false

    private var hasName: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }
    private var noSales: Bool { number(weekday) == nil }
    private var blocked: Bool { !hasName || (existing != nil && noSales) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Headline(title: "가게 정보를 등록해 주세요", sub: "대략적인 값도 괜찮아요.\n등록한 정보는 언제든 고칠 수 있어요.")

                header("가게 이름")
                FieldBox(text: $name, placeholder: "가게 이름을 입력해주세요", unit: "상호", keyboard: .default)
                Button {
                    isAskingListed = true
                } label: {
                    Label("지도에서 가게 찾기", systemImage: "magnifyingglass")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.blue)
                }
                .padding(.horizontal, 4)
                .padding(.top, 10)

                header("가게 위치")
                Button {
                    isSearchingAddress = true
                } label: {
                    HStack {
                        Text(location?.label ?? "주소를 검색해주세요")
                            .font(.system(size: 16))
                            .foregroundStyle(location == nil ? Palette.faint : Palette.ink)
                        Spacer()
                        Text("시·도")
                            .font(.system(size: 15))
                            .foregroundStyle(Palette.sub)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.line, lineWidth: 1))
                }
                Text(location?.address ?? "아직 문을 열기 전이라면 비워 두세요")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.sub)
                    .padding(.horizontal, 4)
                    .padding(.top, 8)

                header("평균 판매량")
                salesField("평일 하루", text: $weekday, helper: "진단하려면 꼭 필요해요")
                salesField("금·토 하루", text: $busyDay, helper: "비워 두면 평일과 같게 계산해요")
                salesField("피크 타임 1시간", text: $peak, helper: "비워 두면 평일 판매량으로 추정해요")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .screenChrome("내 가게 등록")
        .safeAreaInset(edge: .bottom) {
            FooterButtons {
                if !hasName {
                    Text("가게 이름을 넣으면 등록할 수 있어요.")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.sub)
                } else if blocked {
                    Text("평일 하루 판매량을 넣으면 진단할 수 있어요.")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.sub)
                }
                PrimaryButton(title: "등록하기", enabled: !blocked) {
                    if noSales { isIncomplete = true } else { isConfirming = true }
                }
            }
        }
        .onAppear(perform: load)
        .alert("지도에 등록된 가게인가요?", isPresented: $isAskingListed) {
            Button("아니오", role: .cancel) {}
            Button("예") { isSearchingPlace = true }
        } message: {
            Text("지도에 있는 가게라면\n이름으로 찾아 위치까지 한 번에 넣어요.")
        }
        .alert("아직 입력하지 않은 정보가 있어요", isPresented: $isIncomplete) {
            Button("취소", role: .cancel) {}
            Button("확인") { saveOnly() }
        } message: {
            Text("\(location == nil ? "가게 위치와 평일 하루 판매량을" : "평일 하루 판매량을") 입력하지 않았어요.\n그래도 저장할까요?")
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
        .sheet(isPresented: $isSearchingPlace) {
            PlaceSearchSheet(title: "가게 찾기", prompt: "가게 이름과 동네 (예: 민수네 치킨 포항)", restaurantsOnly: true) { item in
                name = item.name ?? name
                location = PickedLocation(item)
            } onManual: {}
        }
        .sheet(isPresented: $isSearchingAddress) {
            PostcodeSheet { picked in
                location = picked
            }
        }
    }

    private func header(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 4)
            .padding(.top, 28)
            .padding(.bottom, 10)
    }

    private func salesField(_ label: String, text: Binding<String>, helper: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 4)
            FieldBox(text: text, placeholder: "0", unit: "개", keyboard: .numberPad)
                .onChange(of: text.wrappedValue) { _, value in
                    let digits = String(value.filter(\.isNumber).prefix(4))
                    if digits != value { text.wrappedValue = digits }
                }
            Text(helper)
                .font(.system(size: 12))
                .foregroundStyle(Palette.sub)
                .padding(.horizontal, 4)
        }
        .padding(.bottom, 12)
    }

    private func number(_ text: String) -> Double? {
        guard let value = Double(text), value > 0 else { return nil }
        return value
    }

    private func load() {
        guard let existing, name.isEmpty else { return }
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
        dismiss()
    }
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

    init(_ item: MKMapItem) {
        let placemark = item.placemark
        self.init(
            sido: placemark.administrativeArea ?? "",
            sigungu: placemark.locality ?? placemark.subAdministrativeArea ?? "",
            address: placemark.title ?? ""
        )
    }
}

private struct PlaceSearchSheet: View {
    let title: String
    let prompt: String
    let restaurantsOnly: Bool
    let onPick: (MKMapItem) -> Void
    let onManual: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var items: [MKMapItem]?
    @State private var state = SearchState.idle

    enum SearchState {
        case idle
        case loading
        case failed
    }

    var body: some View {
        NavigationStack {
            List {
                switch state {
                case .loading:
                    Text("찾는 중이에요…").foregroundStyle(.secondary)
                case .failed:
                    manualRow("지금은 검색을 쓸 수 없어요.")
                case .idle:
                    if let items, items.isEmpty {
                        manualRow("검색 결과가 없어요. 동네 이름을 같이 넣어 보세요.")
                    }
                    ForEach(items ?? [], id: \.self) { item in
                        Button {
                            onPick(item)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                IconTile(systemName: restaurantsOnly ? "storefront" : "mappin")
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name ?? "").font(.headline).foregroundStyle(.primary)
                                    Text(item.placemark.title ?? "")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: prompt)
            .onSubmit(of: .search) { Task { await search() } }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }

    private func manualRow(_ message: String) -> some View {
        VStack(spacing: 12) {
            Text(message).foregroundStyle(.secondary)
            if restaurantsOnly {
                Button("직접 입력하기") {
                    onManual()
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    private func search() async {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard text.count >= 2 else { return }
        state = .loading
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = text
        request.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 36.3, longitude: 127.8),
            span: MKCoordinateSpan(latitudeDelta: 6, longitudeDelta: 6)
        )
        if restaurantsOnly {
            request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.restaurant, .cafe, .bakery, .foodMarket])
            request.resultTypes = .pointOfInterest
        } else {
            request.resultTypes = [.address, .pointOfInterest]
        }
        do {
            items = try await MKLocalSearch(request: request).start().mapItems
            state = .idle
        } catch {
            items = []
            state = (error as? MKError)?.code == .placemarkNotFound ? .idle : .failed
        }
    }
}
