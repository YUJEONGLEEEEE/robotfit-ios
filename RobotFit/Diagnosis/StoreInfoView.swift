import RoomPlan
import SwiftUI

struct StoreInfoView: View {
    @Environment(DiagnosisModel.self) private var model
    @State private var editing: Section?
    @State private var isScanning = false

    enum Section: String, Identifiable {
        case location
        case kitchen
        case sales
        case staff

        var id: String { rawValue }
    }

    var body: some View {
        let store = model.store
        let kitchen = model.kitchen
        let scanned = model.scannedModelURL != nil
        let weeklyHours = store.reducedStaffHoursPerDay * 6

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Steps(current: 3)
                    .padding(.top, 4)
                Headline(
                    title: "가게 정보를 확인해 주세요",
                    sub: scanned
                        ? "LiDAR 스캔으로 주방 크기를 쟀어요.\n비어 있는 항목을 입력해 주세요."
                        : "AI가 사진에서 읽은 정보를 채워 두었어요.\n비어 있는 항목을 입력해 주세요."
                )
                .padding(.top, 28)

                if !model.isReady {
                    Button("예시 값으로 채우기 (민수네 치킨)") { model.fillExample() }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.good)
                        .padding(.horizontal, 4)
                        .padding(.top, 4)
                }

                sectionHeader("가게 위치", section: .location)
                Card(padding: 0) {
                    InfoRow(label: "시·도", value: value(.region, store.region == .gyeongbuk ? "경북" : "경북 외 지역"), missing: missing(.region), last: true)
                }

                sectionHeader("주방 구조", caption: scanned ? "LiDAR로 스캔한 주방 구조예요." : "AI가 분석한 주방 구조예요.", section: .kitchen)
                Card(padding: 0) {
                    if model.kitchenKnown {
                        Kitchen3DView(kitchen: kitchen, fryLine: store.fryLineCm, scannedModelURL: model.scannedModelURL)
                            .frame(height: 230)
                            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24))
                    } else {
                        kitchenPlaceholder
                    }
                    InfoRow(label: "주방 넓이", value: model.kitchenKnown ? "\(kitchen.pyeong)평" : "스캔 또는 입력", optional: !model.kitchenKnown)
                    InfoRow(label: "주방 가로폭", value: model.kitchenKnown ? "\(Format.number(kitchen.widthM))m" : "—", optional: !model.kitchenKnown)
                    InfoRow(label: "주방 세로폭", value: model.kitchenKnown ? "\(Format.number(kitchen.depthM))m" : "—", optional: !model.kitchenKnown)
                    InfoRow(label: "주방 높이", value: model.kitchenKnown ? "\(Format.number(kitchen.heightM))m" : "—", optional: !model.kitchenKnown)
                    InfoRow(label: "예상 로봇 설치 가능 위치", value: value(.fryLine, "\(Format.number(store.fryLineCm.w))×\(Format.number(store.fryLineCm.d))cm"), missing: missing(.fryLine))
                    InfoRow(label: "3상 전원", value: value(.threePhase, store.hasThreePhase ? "있음" : "없음"), missing: missing(.threePhase))
                    InfoRow(label: "배기 후드", value: value(.hood, store.hasExhaustHood ? "있음" : "없음"), missing: missing(.hood), last: true)
                }

                sectionHeader("평균 판매량", caption: "로봇 도입 효과를 비교하기 위해 입력된 수치예요.", section: .sales)
                Card(padding: 0) {
                    InfoRow(label: "평일 하루", value: value(.weekday, "\(Format.number(store.sales.weekday))마리"), missing: missing(.weekday))
                    InfoRow(
                        label: "금·토 하루",
                        value: model.edited.contains(.weekday) || model.edited.contains(.busyDay) ? "\(Format.number(store.sales.busyDay))마리" : "입력해 주세요",
                        tag: !model.edited.contains(.busyDay) && model.edited.contains(.weekday) ? "평일과 같게" : nil,
                        optional: !model.edited.contains(.busyDay) && !model.edited.contains(.weekday)
                    )
                    InfoRow(
                        label: "피크타임 1시간",
                        value: model.edited.contains(.weekday) || model.edited.contains(.peak) ? "\(Format.number(store.peakPerHour))마리" : "입력해 주세요",
                        tag: !model.edited.contains(.peak) && model.edited.contains(.weekday) ? "추정값" : nil,
                        optional: !model.edited.contains(.peak) && !model.edited.contains(.weekday),
                        last: true
                    )
                }

                sectionHeader("인력 감소 시간", caption: "로봇이 대신할 인력비용을 계산해서 알려줘요", section: .staff)
                Card(padding: 0) {
                    InfoRow(
                        label: "주방 알바",
                        value: value(.reducedStaff, store.reducedStaffHoursPerDay == 0 ? "없음 (혼자 운영)" : "주 \(Format.number(weeklyHours))시간"),
                        missing: missing(.reducedStaff),
                        last: true
                    )
                    if model.edited.contains(.reducedStaff) {
                        Text(staffNote(weeklyHours))
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.sub)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 18)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .screenChrome("우리 가게 진단")
        .safeAreaInset(edge: .bottom) {
            FooterButtons {
                if !model.isReady {
                    Text("\(model.missingFields.map(\.label).joined(separator: ", "))을 입력하면 진단할 수 있어요")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.sub)
                        .multilineTextAlignment(.center)
                }
                PrimaryButton(title: "진단하기", enabled: model.isReady) {
                    model.path.append(.diagnosing)
                }
            }
        }
        .sheet(item: $editing) { section in
            SectionEditor(section: section) {
                editing = nil
                isScanning = true
            }
            .presentationDetents([.medium, .large])
        }
        .fullScreenCover(isPresented: $isScanning) {
            RoomScanScreen { room in
                model.applyScan(room)
                isScanning = false
            } onCancel: {
                isScanning = false
            }
        }
    }

    private var kitchenPlaceholder: some View {
        VStack(spacing: 10) {
            Image(systemName: "cube.transparent")
                .font(.system(size: 32))
                .foregroundStyle(Palette.faint)
            Text("LiDAR로 스캔하거나 크기를 입력하면\n주방을 3D로 보여 드려요")
                .font(.system(size: 13))
                .foregroundStyle(Palette.sub)
                .multilineTextAlignment(.center)
            if RoomCaptureSession.isSupported {
                Button("LiDAR로 주방 스캔하기") { isScanning = true }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.good)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .background(Palette.canvas.opacity(0.6))
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24))
    }

    private func missing(_ field: EditedField) -> Bool {
        !model.edited.contains(field)
    }

    private func value(_ field: EditedField, _ text: String) -> String {
        model.edited.contains(field) ? text : "입력해 주세요"
    }

    private func staffNote(_ weeklyHours: Double) -> String {
        if weeklyHours == 0 { return "줄어드는 근무가 없으면 로봇 비용을 회수할 수 없어요." }
        if weeklyHours >= 15 { return "주 15시간이 넘으면 주휴수당이 포함된 단가(시간당 \(Format.won(Assumptions.hourlyLaborKrw)))로 계산해요." }
        return "시간당 \(Format.won(Assumptions.hourlyLaborKrw))으로 계산해요."
    }

    private func sectionHeader(_ title: String, caption: String? = nil, section: Section) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Palette.ink)
                if let caption {
                    Text(caption)
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.sub)
                }
            }
            Spacer()
            Button("수정") { editing = section }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.good)
        }
        .padding(.horizontal, 20)
        .padding(.top, 32)
        .padding(.bottom, 12)
    }
}

private struct InfoRow: View {
    let label: String
    let value: String
    var missing = false
    var tag: String?
    var optional = false
    var last = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(label)
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.sub)
                Spacer()
                if let tag { AssumedTag(text: tag) }
                Text(value)
                    .font(.system(size: 16, weight: missing || optional ? .medium : .semibold))
                    .foregroundStyle(missing ? Palette.action : optional ? Palette.faint : Palette.ink)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            if !last {
                Divider().padding(.horizontal, 20)
            }
        }
    }
}

private struct SectionEditor: View {
    @Environment(DiagnosisModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let section: StoreInfoView.Section
    let onScan: () -> Void

    @State private var values: [String: String] = [:]
    @State private var region: StoreProfile.Region?
    @State private var threePhase: Bool?
    @State private var hood: Bool?
    @State private var cleaner = StoreProfile.Cleaner.owner

    var body: some View {
        NavigationStack {
            Form {
                switch section {
                case .location:
                    Picker("시·도", selection: $region) {
                        Text("경북").tag(StoreProfile.Region?.some(.gyeongbuk))
                        Text("경북 외 지역").tag(StoreProfile.Region?.some(.other))
                    }
                    .pickerStyle(.inline)
                case .kitchen:
                    if RoomCaptureSession.isSupported {
                        SwiftUI.Section {
                            Button {
                                dismiss()
                                onScan()
                            } label: {
                                Label("LiDAR로 주방 스캔하기", systemImage: "viewfinder")
                                    .font(.headline)
                            }
                        } footer: {
                            Text("휴대폰으로 주방을 천천히 비추면 가로·세로·높이를 재고 3D로 보여 드려요.")
                        }
                    }
                    SwiftUI.Section("주방 크기 (선택)") {
                        field("주방 가로폭", "widthM", unit: "m")
                        field("주방 세로폭", "depthM", unit: "m")
                        field("주방 높이", "heightM", unit: "m")
                    }
                    SwiftUI.Section("설치 가능 위치 (필수)") {
                        field("가로", "lineW", unit: "cm")
                        field("깊이", "lineD", unit: "cm")
                    }
                    SwiftUI.Section("설비 (필수)") {
                        choice("3상 전원", $threePhase)
                        choice("배기 후드", $hood)
                    }
                case .sales:
                    SwiftUI.Section {
                        field("평일 하루 (필수)", "weekday", unit: "마리")
                        field("금·토 하루", "busyDay", unit: "마리")
                        field("피크타임 1시간", "peak", unit: "마리")
                    } footer: {
                        Text("금·토를 비우면 평일과 같게, 피크타임을 비우면 평일 판매량으로 추정해요.")
                    }
                    SwiftUI.Section {
                        field("혼자 튀길 수 있는 양 (1시간)", "solo", unit: "마리")
                    } footer: {
                        Text("비우면 시간당 \(Format.number(StoreProfile.blank.soloLimitPerHour))마리로 계산해요 (가정값).")
                    }
                case .staff:
                    SwiftUI.Section {
                        field("로봇이 줄여 줄 알바 (하루)", "staff", unit: "시간")
                    } footer: {
                        Text("알바 없이 혼자 운영하면 0을 입력해 주세요.")
                    }
                    Picker("로봇 세척 담당", selection: $cleaner) {
                        Text("사장님").tag(StoreProfile.Cleaner.owner)
                        Text("직원 (유급)").tag(StoreProfile.Cleaner.staff)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        save()
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear(perform: load)
        }
    }

    private var title: String {
        switch section {
        case .location: "가게 위치"
        case .kitchen: "주방 구조"
        case .sales: "평균 판매량"
        case .staff: "인력 감소 시간"
        }
    }

    private var isValid: Bool {
        values.values.allSatisfy { text in
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty || (Double(trimmed) ?? -1) >= 0
        }
    }

    private func field(_ label: String, _ key: String, unit: String) -> some View {
        HStack {
            Text(label)
            TextField("입력", text: Binding(get: { values[key] ?? "" }, set: { values[key] = $0 }))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
            Text(unit).foregroundStyle(.secondary)
        }
    }

    private func choice(_ label: String, _ selection: Binding<Bool?>) -> some View {
        Picker(label, selection: selection) {
            Text("선택").tag(Bool?.none)
            Text("있음").tag(Bool?.some(true))
            Text("없음").tag(Bool?.some(false))
        }
    }

    private func text(_ value: Double) -> String {
        Format.number(value).replacingOccurrences(of: ",", with: "")
    }

    private func load() {
        let store = model.store
        let kitchen = model.kitchen
        let edited = model.edited
        region = edited.contains(.region) ? store.region : nil
        threePhase = edited.contains(.threePhase) ? store.hasThreePhase : nil
        hood = edited.contains(.hood) ? store.hasExhaustHood : nil
        cleaner = store.cleaningBy
        func known(_ field: EditedField, _ value: Double) -> String { edited.contains(field) ? text(value) : "" }
        switch section {
        case .location: break
        case .kitchen:
            values = [
                "widthM": known(.kitchen, kitchen.widthM), "depthM": known(.kitchen, kitchen.depthM), "heightM": known(.kitchen, kitchen.heightM),
                "lineW": known(.fryLine, store.fryLineCm.w), "lineD": known(.fryLine, store.fryLineCm.d),
            ]
        case .sales:
            values = [
                "weekday": known(.weekday, store.sales.weekday), "busyDay": known(.busyDay, store.sales.busyDay),
                "peak": known(.peak, store.peakPerHour), "solo": known(.soloLimit, store.soloLimitPerHour),
            ]
        case .staff:
            values = ["staff": known(.reducedStaff, store.reducedStaffHoursPerDay)]
        }
    }

    private func number(_ key: String) -> Double? {
        Double((values[key] ?? "").trimmingCharacters(in: .whitespaces))
    }

    private func save() {
        switch section {
        case .location:
            if let region {
                model.store.region = region
                model.edited.insert(.region)
            }
        case .kitchen:
            if let w = number("widthM"), let d = number("depthM"), w > 0, d > 0 {
                model.kitchen.widthM = w
                model.kitchen.depthM = d
                model.kitchen.heightM = number("heightM") ?? model.kitchen.heightM
                model.scannedModelURL = nil
                model.edited.insert(.kitchen)
            }
            if let w = number("lineW"), let d = number("lineD"), w > 0, d > 0 {
                model.store.fryLineCm = .init(w: w, d: d)
                model.edited.insert(.fryLine)
            }
            if let threePhase {
                model.store.hasThreePhase = threePhase
                model.edited.insert(.threePhase)
            }
            if let hood {
                model.store.hasExhaustHood = hood
                model.edited.insert(.hood)
            }
        case .sales:
            if let busy = number("busyDay") {
                model.store.sales.busyDay = busy
                model.edited.insert(.busyDay)
            } else {
                model.edited.remove(.busyDay)
            }
            if let peak = number("peak"), peak > 0 {
                model.store.peakPerHour = peak
                model.edited.insert(.peak)
            } else {
                model.edited.remove(.peak)
            }
            if let solo = number("solo"), solo > 0 {
                model.store.soloLimitPerHour = solo
                model.edited.insert(.soloLimit)
            }
            if let weekday = number("weekday") {
                model.setWeekday(weekday)
            }
        case .staff:
            if let staff = number("staff") {
                model.store.reducedStaffHoursPerDay = staff
                model.edited.insert(.reducedStaff)
            }
            model.store.cleaningBy = cleaner
        }
    }
}
