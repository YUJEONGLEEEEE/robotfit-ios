import RoomPlan
import SwiftUI

struct KitchenConfirmView: View {
    @Environment(DiagnosisModel.self) private var model

    private let fields: [EditedField] = [.fryLine, .threePhase, .hood]

    var body: some View {
        let store = model.store
        let kitchen = model.kitchen
        let missing = fields.filter { !model.edited.contains($0) }

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Steps(current: 3)
                    .padding(.top, 4)
                Headline(
                    title: "이 정보가 맞는지 확인해주세요",
                    sub: model.scannedModelURL != nil
                        ? "LiDAR 스캔으로 주방 크기를 쟀어요.\n맞지 않는 내용은 직접 수정해 주세요."
                        : "AI 스캔을 기반으로 주방 사이즈를 추정했어요.\n맞지 않는 내용은 직접 수정해 주세요."
                )
                .padding(.top, 28)

                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("주방 구조")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Palette.ink)
                        Text(caption)
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.sub)
                    }
                    Spacer()
                    Button("수정") { model.path.append(.kitchenEdit) }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.good)
                }
                .padding(.horizontal, 20)
                .padding(.top, 32)
                .padding(.bottom, 12)

                Card(padding: 0) {
                    if model.kitchenKnown {
                        Kitchen3DView(kitchen: kitchen, fryLine: store.fryLineCm, layout: model.analysis.layout, scannedModelURL: model.scannedModelURL)
                            .frame(height: 260)
                            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24))
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: "cube.transparent")
                                .font(.system(size: 32))
                                .foregroundStyle(Palette.faint)
                            Text("수정에서 크기를 입력하면\n주방을 3D로 보여 드려요")
                                .font(.system(size: 13))
                                .foregroundStyle(Palette.sub)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                    }
                    KitchenRow(label: "주방 넓이", value: model.kitchenKnown ? "\(kitchen.pyeong)평" : nil, tag: tag(.kitchen))
                    KitchenRow(label: "주방 가로폭", value: model.kitchenKnown ? "\(Format.number(kitchen.widthM))m" : nil, tag: tag(.kitchen))
                    KitchenRow(label: "주방 세로폭", value: model.kitchenKnown ? "\(Format.number(kitchen.depthM))m" : nil, tag: tag(.kitchen))
                    KitchenRow(label: "주방 높이", value: model.kitchenKnown ? "\(Format.number(kitchen.heightM))m" : nil, tag: tag(.kitchen))
                    KitchenRow(
                        label: "예상 로봇 설치 가능 위치",
                        value: model.edited.contains(.fryLine) ? "\(Format.number(store.fryLineCm.w))×\(Format.number(store.fryLineCm.d))cm" : nil,
                        tag: tag(.fryLine),
                        required: true
                    )
                    KitchenRow(label: "3상 전원", value: model.edited.contains(.threePhase) ? (store.hasThreePhase ? "있음" : "없음") : nil, tag: tag(.threePhase), required: true)
                    KitchenRow(label: "배기 후드", value: model.edited.contains(.hood) ? (store.hasExhaustHood ? "있음" : "없음") : nil, tag: tag(.hood), required: true, last: true)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .screenChrome("우리 가게 진단")
        .safeAreaInset(edge: .bottom) {
            FooterButtons {
                if !missing.isEmpty {
                    Text("\(missing.map(\.label).joined(separator: ", "))을 수정에서 입력해 주세요")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.sub)
                }
                PrimaryButton(title: "다음", enabled: missing.isEmpty) {
                    model.path.append(.storeInfo)
                }
            }
        }
    }

    private var caption: String {
        if model.scannedModelURL != nil { return "LiDAR로 스캔한 주방 구조예요." }
        if model.aiEstimated.contains(.kitchen) { return "AI가 분석한 주방 구조예요." }
        return model.kitchenKnown ? "입력한 크기로 그린 주방 구조예요." : "주방 크기를 아직 모르고 있어요."
    }

    private func tag(_ field: EditedField) -> String? {
        model.aiEstimated.contains(field) ? "AI 추정" : nil
    }
}

private struct KitchenRow: View {
    let label: String
    let value: String?
    var tag: String?
    var required = false
    var last = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(label)
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.sub)
                Spacer()
                if let tag, value != nil { AssumedTag(text: tag) }
                Text(value ?? (required ? "입력해 주세요" : "—"))
                    .font(.system(size: 16, weight: value == nil ? .medium : .semibold))
                    .foregroundStyle(value == nil ? (required ? Palette.action : Palette.faint) : Palette.ink)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            if !last {
                Divider().padding(.horizontal, 20)
            }
        }
    }
}

struct KitchenEditView: View {
    @Environment(DiagnosisModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var width = ""
    @State private var depth = ""
    @State private var height = ""
    @State private var lineW = ""
    @State private var lineD = ""
    @State private var threePhase: Bool?
    @State private var hood: Bool?
    @State private var isScanning = false
    @State private var loaded = false

    var body: some View {
        let store = model.store

        ScrollView {
            Card(padding: 0) {
                Kitchen3DView(kitchen: model.displayKitchen, fryLine: store.fryLineCm, layout: model.analysis.layout, scannedModelURL: model.scannedModelURL)
                    .frame(height: 240)
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24))
                VStack(alignment: .leading, spacing: 0) {
                    InputField(label: "주방 넓이", text: .constant(pyeongText), unit: "평", disabled: true)
                    InputField(label: "주방 가로폭", text: $width, unit: "m")
                    InputField(label: "주방 세로폭", text: $depth, unit: "m")
                    InputField(label: "주방 높이", text: $height, unit: "m")
                    VStack(alignment: .leading, spacing: 8) {
                        Text("로봇 설치 가능 범위")
                            .font(.system(size: 14))
                            .foregroundStyle(Palette.ink)
                        HStack(spacing: 8) {
                            FieldBox(text: $lineW, placeholder: "가로")
                            Text("×").foregroundStyle(Palette.sub)
                            FieldBox(text: $lineD, placeholder: "깊이")
                            Text("cm").foregroundStyle(Palette.sub)
                        }
                    }
                    .padding(.vertical, 12)
                    ChoiceField(label: "3상 전기", selection: $threePhase)
                    ChoiceField(label: "배기 후드", selection: $hood)
                    if RoomCaptureSession.isSupported {
                        Button {
                            isScanning = true
                        } label: {
                            Label("LiDAR로 주방 다시 재기", systemImage: "viewfinder")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Palette.good)
                        }
                        .padding(.vertical, 12)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .screenChrome("주방 구조")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("확인") {
                    save()
                    dismiss()
                }
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Palette.ink)
                .disabled(!isValid)
            }
        }
        .onAppear(perform: load)
        .fullScreenCover(isPresented: $isScanning) {
            RoomScanScreen { room in
                model.applyScan(room)
                isScanning = false
                loaded = false
                load()
            } onCancel: {
                isScanning = false
            }
        }
    }

    private var pyeongText: String {
        guard let w = Double(width), let d = Double(depth), w > 0, d > 0 else { return "" }
        return String(Int((w * d / 3.3058).rounded()))
    }

    private var isValid: Bool {
        [width, depth, height, lineW, lineD].allSatisfy { text in
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty || (Double(trimmed) ?? -1) >= 0
        }
    }

    private func text(_ value: Double) -> String {
        Format.number(value).replacingOccurrences(of: ",", with: "")
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        let kitchen = model.kitchen
        let store = model.store
        let edited = model.edited
        width = edited.contains(.kitchen) ? text(kitchen.widthM) : ""
        depth = edited.contains(.kitchen) ? text(kitchen.depthM) : ""
        height = edited.contains(.kitchen) ? text(kitchen.heightM) : ""
        lineW = edited.contains(.fryLine) ? text(store.fryLineCm.w) : ""
        lineD = edited.contains(.fryLine) ? text(store.fryLineCm.d) : ""
        threePhase = edited.contains(.threePhase) ? store.hasThreePhase : nil
        hood = edited.contains(.hood) ? store.hasExhaustHood : nil
    }

    private func save() {
        if let w = Double(width), let d = Double(depth), w > 0, d > 0 {
            let h = Double(height) ?? model.kitchen.heightM
            let changed = w != model.kitchen.widthM || d != model.kitchen.depthM || h != model.kitchen.heightM
            if changed || !model.edited.contains(.kitchen) {
                model.kitchen.widthM = w
                model.kitchen.depthM = d
                model.kitchen.heightM = h
                model.scannedModelURL = nil
                model.confirm(.kitchen)
            }
        }
        if let w = Double(lineW), let d = Double(lineD), w > 0, d > 0,
           w != model.store.fryLineCm.w || d != model.store.fryLineCm.d || !model.edited.contains(.fryLine) {
            model.store.fryLineCm = .init(w: w, d: d)
            model.confirm(.fryLine)
        }
        if let threePhase, threePhase != model.store.hasThreePhase || !model.edited.contains(.threePhase) {
            model.store.hasThreePhase = threePhase
            model.confirm(.threePhase)
        }
        if let hood, hood != model.store.hasExhaustHood || !model.edited.contains(.hood) {
            model.store.hasExhaustHood = hood
            model.confirm(.hood)
        }
    }
}

struct FieldBox: View {
    @Binding var text: String
    var placeholder = "입력해주세요"
    var unit: String?
    var keyboard: UIKeyboardType = .decimalPad
    var disabled = false
    @FocusState private var focused: Bool

    var body: some View {
        HStack {
            TextField(placeholder, text: $text)
                .keyboardType(keyboard)
                .focused($focused)
                .disabled(disabled)
                .font(.system(size: 16))
                .foregroundStyle(disabled ? Palette.sub : Palette.ink)
            if let unit {
                Text(unit)
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.sub)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(disabled ? Palette.canvas : Color.white, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(focused ? Palette.ink : Palette.line, lineWidth: focused ? 1.5 : 1))
    }
}

private struct InputField: View {
    let label: String
    @Binding var text: String
    let unit: String
    var disabled = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(Palette.ink)
            FieldBox(text: $text, unit: unit, disabled: disabled)
        }
        .padding(.vertical, 12)
    }
}

private struct ChoiceField: View {
    let label: String
    @Binding var selection: Bool?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(Palette.ink)
            Menu {
                Button("있음") { selection = true }
                Button("없음") { selection = false }
            } label: {
                HStack {
                    Text(selection.map { $0 ? "있음" : "없음" } ?? "선택해주세요")
                        .font(.system(size: 16))
                        .foregroundStyle(selection == nil ? Palette.faint : Palette.ink)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.faint)
                }
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.line, lineWidth: 1))
            }
        }
        .padding(.vertical, 12)
    }
}
