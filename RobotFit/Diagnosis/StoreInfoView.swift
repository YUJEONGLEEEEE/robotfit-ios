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
                        ? "LiDAR 스캔으로 주방 크기를 쟀어요.\n맞지 않는 내용은 직접 수정해 주세요."
                        : "AI 스캔을 기반으로 주방 사이즈를 추정했어요.\n맞지 않는 내용은 직접 수정해 주세요."
                )
                .padding(.top, 28)

                sectionHeader("가게 위치", section: .location)
                Card(padding: 0) {
                    InfoRow(label: "시·도", value: store.region == .gyeongbuk ? "경북 포항" : "경북 외 지역", last: true)
                }

                sectionHeader("주방 구조", caption: scanned ? "LiDAR로 스캔한 주방 구조예요." : "AI가 분석한 주방 구조예요.", section: .kitchen)
                Card(padding: 0) {
                    Kitchen3DView(kitchen: kitchen, fryLine: store.fryLineCm, scannedModelURL: model.scannedModelURL)
                        .frame(height: 230)
                        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24))
                    InfoRow(label: "주방 넓이", value: "\(kitchen.pyeong)평", assumed: model.isAssumed(.kitchen))
                    InfoRow(label: "주방 가로폭", value: "\(Format.number(kitchen.widthM))m")
                    InfoRow(label: "주방 세로폭", value: "\(Format.number(kitchen.depthM))m")
                    InfoRow(label: "주방 높이", value: "\(Format.number(kitchen.heightM))m")
                    InfoRow(label: "예상 로봇 설치 가능 위치", value: "\(Format.number(store.fryLineCm.w))×\(Format.number(store.fryLineCm.d))cm", assumed: model.isAssumed(.fryLine))
                    InfoRow(label: "3상 전원", value: store.hasThreePhase ? "있음" : "없음", last: true)
                }

                sectionHeader("평균 판매량", caption: "로봇 도입 효과를 비교하기 위해 입력된 수치예요.", section: .sales)
                Card(padding: 0) {
                    InfoRow(label: "평일 하루", value: "\(Format.number(store.sales.weekday))마리", assumed: model.isAssumed(.weekday))
                    InfoRow(label: "금·토 하루", value: "\(Format.number(store.sales.busyDay))마리", assumed: model.isAssumed(.busyDay))
                    InfoRow(label: "피크타임 1시간", value: "\(Format.number(store.peakPerHour))마리", assumed: model.isAssumed(.peak), last: true)
                }

                sectionHeader("인력 감소 시간", caption: "로봇이 대신할 인력비용을 계산해서 알려줘요", section: .staff)
                Card(padding: 0) {
                    InfoRow(
                        label: "주방 알바",
                        value: store.reducedStaffHoursPerDay == 0 ? "없음 (혼자 운영)" : "주 \(Format.number(weeklyHours))시간",
                        assumed: model.isAssumed(.reducedStaff),
                        last: true
                    )
                    Text(staffNote(weeklyHours))
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.sub)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 18)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .screenChrome("우리 가게 진단")
        .safeAreaInset(edge: .bottom) {
            FooterButtons {
                PrimaryButton(title: "진단하기") {
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
    var assumed = false
    var last = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(label)
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.sub)
                Spacer()
                if assumed { AssumedTag(text: "추정값") }
                Text(value)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.ink)
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
    @State private var region = StoreProfile.Region.gyeongbuk
    @State private var threePhase = true
    @State private var hood = true
    @State private var cleaner = StoreProfile.Cleaner.owner

    var body: some View {
        NavigationStack {
            Form {
                switch section {
                case .location:
                    Picker("시·도", selection: $region) {
                        Text("경북 포항").tag(StoreProfile.Region.gyeongbuk)
                        Text("경북 외 지역").tag(StoreProfile.Region.other)
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
                    SwiftUI.Section("직접 입력") {
                        field("주방 가로폭", "widthM", unit: "m")
                        field("주방 세로폭", "depthM", unit: "m")
                        field("주방 높이", "heightM", unit: "m")
                        field("설치 가능 위치 가로", "lineW", unit: "cm")
                        field("설치 가능 위치 깊이", "lineD", unit: "cm")
                        Toggle("3상 전원", isOn: $threePhase)
                        Toggle("배기 후드", isOn: $hood)
                    }
                case .sales:
                    field("평일 하루", "weekday", unit: "마리")
                    field("금·토 하루", "busyDay", unit: "마리")
                    field("피크타임 1시간", "peak", unit: "마리")
                    field("혼자 튀길 수 있는 양 (1시간)", "solo", unit: "마리")
                case .staff:
                    field("로봇이 줄여 줄 알바 (하루, 없으면 0)", "staff", unit: "시간")
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
        values.values.allSatisfy { (Double($0) ?? -1) >= 0 }
    }

    private func field(_ label: String, _ key: String, unit: String) -> some View {
        HStack {
            Text(label)
            TextField("0", text: Binding(get: { values[key] ?? "" }, set: { values[key] = $0 }))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
            Text(unit).foregroundStyle(.secondary)
        }
    }

    private func text(_ value: Double) -> String {
        Format.number(value).replacingOccurrences(of: ",", with: "")
    }

    private func load() {
        let store = model.store
        let kitchen = model.kitchen
        region = store.region
        threePhase = store.hasThreePhase
        hood = store.hasExhaustHood
        cleaner = store.cleaningBy
        switch section {
        case .location: break
        case .kitchen:
            values = ["widthM": text(kitchen.widthM), "depthM": text(kitchen.depthM), "heightM": text(kitchen.heightM),
                      "lineW": text(store.fryLineCm.w), "lineD": text(store.fryLineCm.d)]
        case .sales:
            values = ["weekday": text(store.sales.weekday), "busyDay": text(store.sales.busyDay),
                      "peak": text(store.peakPerHour), "solo": text(store.soloLimitPerHour)]
        case .staff:
            values = ["staff": text(store.reducedStaffHoursPerDay)]
        }
    }

    private func value(_ key: String) -> Double {
        Double(values[key] ?? "") ?? 0
    }

    private func save() {
        switch section {
        case .location:
            model.store.region = region
            model.edited.insert(.region)
        case .kitchen:
            if value("widthM") != model.kitchen.widthM || value("depthM") != model.kitchen.depthM || value("heightM") != model.kitchen.heightM {
                model.kitchen.widthM = value("widthM")
                model.kitchen.depthM = value("depthM")
                model.kitchen.heightM = value("heightM")
                model.scannedModelURL = nil
                model.edited.insert(.kitchen)
            }
            if value("lineW") != model.store.fryLineCm.w || value("lineD") != model.store.fryLineCm.d {
                model.store.fryLineCm = .init(w: value("lineW"), d: value("lineD"))
                model.edited.insert(.fryLine)
            }
            model.store.hasThreePhase = threePhase
            model.store.hasExhaustHood = hood
        case .sales:
            model.store.sales.weekday = value("weekday")
            model.store.sales.busyDay = value("busyDay")
            model.store.peakPerHour = max(1, value("peak"))
            model.store.soloLimitPerHour = value("solo")
            model.edited.formUnion([.weekday, .busyDay, .peak, .soloLimit])
        case .staff:
            model.store.reducedStaffHoursPerDay = value("staff")
            model.store.cleaningBy = cleaner
            model.edited.insert(.reducedStaff)
        }
    }
}
