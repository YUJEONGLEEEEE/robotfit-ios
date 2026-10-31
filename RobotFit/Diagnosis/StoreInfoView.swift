import RoomPlan
import SwiftUI

struct StoreInfoView: View {
    @Environment(DiagnosisModel.self) private var model
    @State private var editor: NumberEditor?
    @State private var isScanning = false

    struct NumberEditor: Identifiable {
        let id = UUID()
        let field: EditedField
        let title: String
        let unit: String
        let inputs: [(label: String, value: Double)]
        let apply: ([Double]) -> Void
    }

    var body: some View {
        @Bindable var model = model
        let store = model.store
        let kitchen = model.kitchen
        let weeklyHours = store.reducedStaffHoursPerDay * 6

        List {
            Section {
                Steps(current: 3)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                Headline(title: "가게 정보를 확인해 주세요", sub: "대략적인 값도 괜찮아요. 틀린 값은 눌러서 고쳐 주세요.")
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 0, trailing: 0))
            }

            Section("가게 위치") {
                Picker("시·도", selection: $model.store.region) {
                    Text("경북 포항").tag(StoreProfile.Region.gyeongbuk)
                    Text("경북 외 지역").tag(StoreProfile.Region.other)
                }
            }

            Section {
                row("주방", "\(kitchen.pyeong)평 (\(Format.number(kitchen.widthM))×\(String(format: "%.1f", kitchen.depthM))m)", field: .kitchen) {
                    editor = NumberEditor(field: .kitchen, title: "주방 크기", unit: "m", inputs: [("가로", kitchen.widthM), ("세로", kitchen.depthM)]) { values in
                        model.kitchen.widthM = values[0]
                        model.kitchen.depthM = values[1]
                    }
                }
                if RoomCaptureSession.isSupported {
                    Button {
                        isScanning = true
                    } label: {
                        Label("LiDAR로 주방 크기 재기", systemImage: "viewfinder")
                            .font(.subheadline.weight(.semibold))
                    }
                }
                row("튀김 라인", "\(Format.number(store.fryLineCm.w))×\(Format.number(store.fryLineCm.d))cm", field: .fryLine) {
                    editor = NumberEditor(field: .fryLine, title: "튀김 라인 크기", unit: "cm", inputs: [("가로 (벽 따라)", store.fryLineCm.w), ("깊이", store.fryLineCm.d)]) { values in
                        model.store.fryLineCm = .init(w: values[0], d: values[1])
                    }
                }
                Picker("3상 전원", selection: $model.store.hasThreePhase) {
                    Text("있음").tag(true)
                    Text("없음").tag(false)
                }
                Picker("배기 후드", selection: $model.store.hasExhaustHood) {
                    Text("있음").tag(true)
                    Text("없음").tag(false)
                }
            } header: {
                Text("매장·주방")
            } footer: {
                Text("직접 재면 추천이 정확해져요")
            }

            Section("판매량") {
                row("평일 하루 (주 \(Int(store.sales.weekdayCount))일)", "\(Format.number(store.sales.weekday))마리", field: .weekday) {
                    editor = NumberEditor(field: .weekday, title: "평일 하루 판매량", unit: "마리", inputs: [("평일 하루", store.sales.weekday)]) { values in
                        model.store.sales.weekday = values[0]
                    }
                }
                row("금·토 하루 (주 \(Int(store.sales.busyDayCount))일)", "\(Format.number(store.sales.busyDay))마리", field: .busyDay) {
                    editor = NumberEditor(field: .busyDay, title: "금·토 하루 판매량", unit: "마리", inputs: [("금·토 하루", store.sales.busyDay)]) { values in
                        model.store.sales.busyDay = values[0]
                    }
                }
                row("저녁 피크 1시간", "\(Format.number(store.peakPerHour))마리", field: .peak) {
                    editor = NumberEditor(field: .peak, title: "저녁 피크 1시간 주문", unit: "마리", inputs: [("피크 1시간", store.peakPerHour)]) { values in
                        model.store.peakPerHour = max(1, values[0])
                    }
                }
                row("혼자 튀길 수 있는 양", "시간당 \(Format.number(store.soloLimitPerHour))마리", field: .soloLimit) {
                    editor = NumberEditor(field: .soloLimit, title: "사장님 혼자 1시간에 튀길 수 있는 양", unit: "마리", inputs: [("1시간", store.soloLimitPerHour)]) { values in
                        model.store.soloLimitPerHour = values[0]
                    }
                }
            }

            Section {
                row(
                    "저녁 알바",
                    store.reducedStaffHoursPerDay == 0 ? "없음 (혼자 운영)" : "하루 \(Format.number(store.reducedStaffHoursPerDay))시간 · 주 6일",
                    field: .reducedStaff
                ) {
                    editor = NumberEditor(field: .reducedStaff, title: "로봇이 있으면 줄일 수 있는 알바 시간", unit: "시간/일", inputs: [("하루 (없으면 0)", store.reducedStaffHoursPerDay)]) { values in
                        model.store.reducedStaffHoursPerDay = values[0]
                    }
                }
            } header: {
                Text("로봇이 줄여 줄 근무")
            } footer: {
                if weeklyHours >= 15 {
                    Text("주 \(Format.number(weeklyHours))시간이라 주휴수당이 포함된 시간당 \(Format.won(Assumptions.hourlyLaborKrw))으로 계산해요.")
                } else if weeklyHours == 0 {
                    Text("줄어드는 근무가 없으면 로봇 비용을 회수할 수 없어요.")
                } else {
                    Text("시간당 \(Format.won(Assumptions.hourlyLaborKrw))으로 계산해요.")
                }
            }

            Section {
                Picker("세척 담당", selection: $model.store.cleaningBy) {
                    Text("사장님").tag(StoreProfile.Cleaner.owner)
                    Text("직원 (유급)").tag(StoreProfile.Cleaner.staff)
                }
            } header: {
                Text("로봇 세척")
            } footer: {
                Text("로봇 세척은 하루 \(Int(Assumptions.cleaningMinutesPerDay))분으로 계산해요.")
            }
        }
        .navigationTitle("우리 가게 진단")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            FooterButtons {
                PrimaryButton(title: "진단하기") {
                    model.path.append(.analyzing)
                }
            }
        }
        .sheet(item: $editor) { editor in
            NumberEditorSheet(editor: editor) { values in
                editor.apply(values)
                model.edited.insert(editor.field)
            }
            .presentationDetents([.medium])
        }
        .fullScreenCover(isPresented: $isScanning) {
            RoomScanScreen { room in
                model.applyScan(KitchenMeasurement(room: room))
                isScanning = false
            } onCancel: {
                isScanning = false
            }
        }
    }

    private func row(_ label: String, _ value: String, field: EditedField, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(label)
                    .foregroundStyle(.secondary)
                Spacer()
                if model.isAssumed(field) { AssumedTag() }
                Text(value)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

private struct NumberEditorSheet: View {
    let editor: StoreInfoView.NumberEditor
    let onSave: ([Double]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var texts: [String]

    init(editor: StoreInfoView.NumberEditor, onSave: @escaping ([Double]) -> Void) {
        self.editor = editor
        self.onSave = onSave
        _texts = State(initialValue: editor.inputs.map { Format.number($0.value).replacingOccurrences(of: ",", with: "") })
    }

    private var values: [Double?] {
        texts.map { Double($0.trimmingCharacters(in: .whitespaces)) }
    }

    private var isValid: Bool {
        values.allSatisfy { ($0 ?? -1) >= 0 }
    }

    var body: some View {
        NavigationStack {
            Form {
                ForEach(Array(editor.inputs.enumerated()), id: \.offset) { index, input in
                    HStack {
                        Text(input.label)
                        TextField("0", text: $texts[index])
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text(editor.unit)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(editor.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        onSave(values.map { $0 ?? 0 })
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
}
