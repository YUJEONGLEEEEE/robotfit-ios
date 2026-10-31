import SwiftUI

struct QuoteView: View {
    @Environment(DiagnosisModel.self) private var model
    let robotID: String

    var body: some View {
        if let result = model.result(for: robotID) {
            content(result)
        } else {
            ContentUnavailableView("로봇 정보를 찾을 수 없어요", systemImage: "questionmark.circle")
        }
    }

    private struct Offer: Identifiable {
        let id: String
        let rows: [(String, String)]
        let monthly: Double?
        let monthlyNote: String
    }

    private func offers(_ result: RobotResult) -> [Offer] {
        let robot = result.robot
        let electricity = result.electricityMonthlyKrw ?? 0
        let install = robot.installCostKrw.map(Format.priceWon) ?? "확인 필요"
        let maintenance: String = {
            guard let m = robot.maintenance else { return "확인 필요" }
            if m.monthlyKrw == 0 { return m.freeMonths > 0 ? "무상 \(m.freeMonths)개월" : "무상" }
            return "월 \(Format.manWon(m.monthlyKrw))"
        }()
        var list: [Offer] = []
        if let price = robot.purchasePriceKrw {
            let best = result.best
            list.append(Offer(
                id: "구입",
                rows: [
                    ("구입가", Format.priceWon(price) + (robot.priceIncludesVat == false ? " (부가세 별도)" : "")),
                    ("설치비", install),
                    ("유지보수", maintenance),
                ],
                monthly: best?.robotMonthlyKrw,
                monthlyNote: best.map { "\($0.subsidy.short) 자부담 기준, \(Int(Assumptions.robotCostMonths))개월 나눔·전기료 포함" } ?? ""
            ))
        }
        if let rental = robot.rental {
            list.append(Offer(
                id: "렌탈",
                rows: [
                    ("월 렌탈료", "\(Format.manWon(rental.monthlyKrw)) × \(rental.months)개월"),
                    ("설치비", install),
                    ("유지보수", maintenance),
                ],
                monthly: rental.monthlyKrw + electricity,
                monthlyNote: "\(rental.type) 렌탈료에 전기료 포함"
            ))
        }
        return list
    }

    private func content(_ result: RobotResult) -> some View {
        let robot = result.robot
        let store = model.store
        let kitchen = model.kitchen
        let list = offers(result)

        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    SmallTag(text: robot.displayName)
                    Headline(
                        title: list.count > 1 ? "구매 조건 \(list.count)가지를 비교해요" : "이 로봇의 구매 조건을 확인해요",
                        sub: "가격·설치비·유지보수를 한눈에 비교해요."
                    )
                    .padding(.horizontal, -4)
                }
                .padding(.horizontal, 4)

                Card {
                    HStack(spacing: 12) {
                        IconTile(systemName: "doc.text.fill", tint: .blue)
                        Text("요청서 내용")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Palette.ink)
                    }
                    .padding(.bottom, 8)
                    row("주방", "\(Format.number(kitchen.widthM))×\(Format.number(kitchen.depthM))m", estimated: model.aiEstimated.contains(.kitchen))
                    Divider()
                    row("튀김 라인", store.fryLineCm.w > 0 ? "\(Format.number(store.fryLineCm.w))×\(Format.number(store.fryLineCm.d))cm" : "확인 필요", estimated: model.aiEstimated.contains(.fryLine))
                    Divider()
                    row("전원", store.hasThreePhase ? "3상 전원 있음" : "3상 전원 없음", estimated: model.aiEstimated.contains(.threePhase))
                    Divider()
                    row("위치", location, estimated: false)
                }

                Note(text: "판매처별 견적은 공개 자료가 없어 공급사 카탈로그 기준으로 보여 드려요.")
                    .padding(.bottom, 4)

                if list.isEmpty {
                    Card {
                        Text("공개된 가격 정보가 없어 공급사에 직접 문의해야 해요.")
                            .font(.system(size: 15))
                            .foregroundStyle(Palette.sub)
                    }
                }

                ForEach(list) { offer in
                    Card {
                        HStack {
                            Text(robot.supplier ?? "공급사")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(Palette.ink)
                            Spacer()
                            SmallTag(text: offer.id)
                        }
                        .padding(.bottom, 8)
                        ForEach(Array(offer.rows.enumerated()), id: \.offset) { _, item in
                            row(item.0, item.1, estimated: false)
                            Divider()
                        }
                        HStack(alignment: .firstTextBaseline) {
                            Text("한 달에 내는 돈")
                                .font(.system(size: 15))
                                .foregroundStyle(Palette.sub)
                            Spacer()
                            if offer.monthly != nil { AssumedTag(text: "추정값") }
                            Text(offer.monthly.map { "약 \(Format.manWon($0))" } ?? "확인 필요")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Palette.ink)
                        }
                        .padding(.vertical, 10)
                        if !offer.monthlyNote.isEmpty {
                            Text(offer.monthlyNote)
                                .font(.system(size: 12))
                                .foregroundStyle(Palette.sub)
                        }
                        let sent = model.hasRequested(robot.id, option: offer.id)
                        Button {
                            withAnimation(.snappy) { model.requestQuote(robot, option: offer.id) }
                        } label: {
                            Text(sent ? "요청 보냄(시연)" : "요청 보내기(시연)")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(sent ? Palette.faint : Palette.ink)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .overlay(Capsule().stroke(Palette.line, lineWidth: 1))
                        }
                        .disabled(sent)
                        .padding(.top, 14)
                    }
                }

                DisclosureCard(title: "견적 조건 안내") {
                    ForEach(guides, id: \.self) { text in
                        Text("· " + text)
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.sub)
                            .padding(.vertical, 3)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .screenChrome("판매처별 견적 확인하기")
        .safeAreaInset(edge: .bottom) {
            FooterButtons {
                PrimaryButton(title: "견적 기록 보기") { model.showQuotes() }
            }
        }
    }

    private var guides: [String] {
        [
            "가격·설치비·유지보수는 공급사 카탈로그 공개 자료 기준이에요.",
            "한 달에 내는 돈은 자부담을 \(Int(Assumptions.robotCostMonths))개월로 나누고 전기료를 더한 추정값이에요.",
            "지원사업 금액은 다음 공고 기준 예상치라 선정 여부에 따라 달라져요.",
            "요청 보내기는 시연용이라 실제로 발송되지 않아요.",
        ]
    }

    private var location: String {
        if let address = model.savedStores.last(where: { $0.name == model.store.name })?.address, !address.isEmpty {
            return address
        }
        guard model.edited.contains(.region) else { return "확인 필요" }
        return model.store.region == .gyeongbuk ? "경북" : "경북 외 지역"
    }

    private func row(_ label: String, _ value: String, estimated: Bool) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(Palette.sub)
            Spacer(minLength: 12)
            if estimated { AssumedTag(text: "AI 추정") }
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 10)
    }
}

struct SmallTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Palette.sub)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Palette.line, in: RoundedRectangle(cornerRadius: 6))
    }
}
