import SwiftUI

struct StoreInfoView: View {
    @Environment(DiagnosisModel.self) private var model

    @State private var weekday = ""
    @State private var busyDay = ""
    @State private var peak = ""
    @State private var name = ""
    @State private var weeklyHours = ""
    @State private var loaded = false

    private let required: [EditedField] = [.weekday]

    var body: some View {
        let missing = required.filter { !model.edited.contains($0) }

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Steps(current: 3)
                    .padding(.top, 4)
                Headline(
                    title: "산정을 위해 매출을 입력해주세요",
                    sub: "판매량과 인력 정보로 로봇이 줄여 줄 시간과 비용을 계산해요."
                )
                .padding(.top, 28)

                header("평균 판매량", caption: "로봇 도입 효과를 비교하기 위해 입력된 수치예요.", required: true)
                field("평일 하루", required: true) {
                    FieldBox(text: $weekday, unit: "개", keyboard: .numberPad)
                }
                field("금·토 하루", hint: model.edited.contains(.weekday) && busyDay.isEmpty ? "비우면 평일과 같게 계산해요" : nil) {
                    FieldBox(text: $busyDay, unit: "개", keyboard: .numberPad)
                }
                field("피크 타임 1시간", hint: model.edited.contains(.weekday) && peak.isEmpty ? "비우면 시간당 \(Format.number(model.store.peakPerHour))개로 추정해요" : nil) {
                    FieldBox(text: $peak, unit: "개", keyboard: .numberPad)
                }

                header("가게 이름")
                FieldBox(text: $name, placeholder: "가게를 입력해주세요", unit: "상호", keyboard: .default)

                header("가게 위치")
                Menu {
                    Button("경북") { setRegion(.gyeongbuk) }
                    Button("경북 외 지역") { setRegion(.other) }
                } label: {
                    HStack {
                        Text(regionText ?? "지역을 입력해주세요")
                            .font(.system(size: 16))
                            .foregroundStyle(regionText == nil ? Palette.faint : Palette.ink)
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
                Text("선택하지 않으면 전국 기준으로 계산하고 경북 바우처는 빼고 계산해요.")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.sub)
                    .padding(.horizontal, 4)
                    .padding(.top, 8)

                header("인력 감소 시간", caption: "로봇을 들이면 줄일 알바 근무 시간이에요. 지금 튀김 담당 알바가 주에 몇 시간 일하는지 떠올려 보세요.")
                FieldBox(text: $weeklyHours, placeholder: "주당 시간을 입력해주세요", unit: "주방 알바", keyboard: .decimalPad)
                if suggestedWeekly > 0, Double(weeklyHours) != suggestedWeekly {
                    Button {
                        weeklyHours = Self.text(suggestedWeekly)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                            Text("판매량 기준 추천: 주 \(Format.number(suggestedWeekly))시간")
                            Spacer()
                            Text("적용")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Palette.ink, in: Capsule())
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Palette.action.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.top, 8)
                }
                Text(staffNote)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.sub)
                    .padding(.horizontal, 4)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .screenChrome("우리 가게 진단")
        .safeAreaInset(edge: .bottom) {
            FooterButtons {
                if !missing.isEmpty {
                    Text("\(missing.map(\.label).joined(separator: ", "))을 입력하면 진단할 수 있어요")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.sub)
                }
                PrimaryButton(title: "진단하기", enabled: model.isReady) {
                    model.path.append(.diagnosing)
                }
            }
        }
        .onAppear(perform: load)
        .onChange(of: weekday) { _, value in applySales(weekday: value) }
        .onChange(of: busyDay) { _, _ in applySales(weekday: weekday) }
        .onChange(of: peak) { _, _ in applySales(weekday: weekday) }
        .onChange(of: name) { _, value in
            let trimmed = value.trimmingCharacters(in: .whitespaces)
            model.store.name = trimmed.isEmpty ? StoreProfile.blank.name : trimmed
        }
        .onChange(of: weeklyHours) { _, value in
            if let hours = Double(value.trimmingCharacters(in: .whitespaces)), hours >= 0 {
                model.store.reducedStaffHoursPerDay = hours / 6
                model.confirm(.reducedStaff)
            } else {
                model.edited.remove(.reducedStaff)
                model.applySuggestedStaff()
            }
        }
    }

    private var regionText: String? {
        guard model.edited.contains(.region) else { return nil }
        return model.store.region == .gyeongbuk ? "경북" : "경북 외 지역"
    }

    private var suggestedWeekly: Double {
        model.suggestedStaffHoursPerDay * 6
    }

    private static func text(_ value: Double) -> String {
        Format.number(value).replacingOccurrences(of: ",", with: "")
    }

    private var staffNote: String {
        guard let hours = Double(weeklyHours), model.edited.contains(.reducedStaff) else {
            if suggestedWeekly > 0 {
                return "비워 두면 판매량 기준 추천값(주 \(Format.number(suggestedWeekly))시간)으로 계산해요."
            }
            return "비워 두면 평일 판매량을 넣은 뒤 판매량 기준 추천값으로 계산해요."
        }
        if hours == 0 { return "줄어드는 근무가 없으면 로봇 비용을 회수할 수 없어요." }
        if hours >= 15 { return "주 15시간이 넘어서 주휴수당이 포함된 단가(시간당 \(Format.won(Assumptions.hourlyLaborKrw)))로 계산해요." }
        return "시간당 \(Format.won(Assumptions.hourlyLaborKrw))으로 계산해요."
    }

    private func setRegion(_ region: StoreProfile.Region) {
        model.store.region = region
        model.confirm(.region)
    }

    private func applySales(weekday text: String) {
        let busy = Double(busyDay.trimmingCharacters(in: .whitespaces))
        let peakValue = Double(peak.trimmingCharacters(in: .whitespaces))
        if let busy, busy > 0 {
            model.store.sales.busyDay = busy
            model.confirm(.busyDay)
        } else {
            model.edited.remove(.busyDay)
        }
        if let peakValue, peakValue > 0 {
            model.store.peakPerHour = peakValue
            model.confirm(.peak)
        } else {
            model.edited.remove(.peak)
        }
        if let value = Double(text.trimmingCharacters(in: .whitespaces)), value > 0 {
            model.setWeekday(value)
        } else {
            model.edited.remove(.weekday)
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        let store = model.store
        let edited = model.edited
        func text(_ value: Double) -> String { Format.number(value).replacingOccurrences(of: ",", with: "") }
        weekday = edited.contains(.weekday) ? text(store.sales.weekday) : ""
        busyDay = edited.contains(.busyDay) ? text(store.sales.busyDay) : ""
        peak = edited.contains(.peak) ? text(store.peakPerHour) : ""
        name = store.name == StoreProfile.blank.name ? "" : store.name
        weeklyHours = edited.contains(.reducedStaff) ? text(store.reducedStaffHoursPerDay * 6) : ""
    }

    private func header(_ title: String, caption: String? = nil, required: Bool = false) -> some View {
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
            if required {
                Text("필수")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.bad)
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 28)
        .padding(.bottom, 10)
    }

    private func field<Content: View>(_ label: String, required: Bool = false, hint: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                if required {
                    Text("*").foregroundStyle(Palette.bad)
                }
            }
            content()
            if let hint {
                Text(hint)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.sub)
            }
        }
        .padding(.bottom, 10)
    }
}
