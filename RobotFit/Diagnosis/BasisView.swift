import SwiftUI

struct BasisView: View {
    @Environment(DiagnosisModel.self) private var model
    let robotID: String

    var body: some View {
        if let result = model.result(for: robotID) {
            content(result)
        } else {
            ContentUnavailableView("로봇 정보를 찾을 수 없어요", systemImage: "questionmark.circle")
        }
    }

    private func content(_ result: RobotResult) -> some View {
        let store = model.store
        let diag = model.evaluation.diag
        let robot = result.robot
        let best = result.best
        let weeklyHours = store.reducedStaffHoursPerDay * 6
        let electricity = result.electricityMonthlyKrw ?? 0
        let netSaving = diag.removedStaffMonthlyKrw - electricity - diag.cleaningStaffMonthlyKrw
        let wage = Format.won(Assumptions.hourlyLaborKrw)
        let days = Int(Assumptions.businessDaysPerMonth)

        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Headline(
                    title: "비용과 혜택, 이렇게 계산했어요",
                    sub: "\(store.name)에 \(robot.displayName)를 도입했을 때의 기준이에요.\n로봇 청소는 \(store.cleaningBy == .owner ? "사장님이 직접 하시는" : "직원이 하는") 조건으로 계산했어요.\n정확한 자료가 없는 값은 추정값으로 표시했어요."
                )

                DisclosureCard(title: "줄어드는 인건비", systemImage: "person.2", tint: Palette.bad, expanded: true) {
                    Formula(text: "저녁 알바 하루 \(Format.number(store.reducedStaffHoursPerDay))시간 × 주 6일 = 주 \(Format.number(weeklyHours))시간" + (model.isAssumed(.reducedStaff) ? "\n입력하지 않아 판매량 기준 추정값으로 계산했어요." : "") + (weeklyHours >= 15 ? "\n주 15시간 이상이라 주휴수당이 붙어요." : ""))
                    Formula(text: "시간당 단가 (가정값)\n최저임금 월 환산 2,156,880원 ÷ 174시간 × 1.2 = \(wage)\n174시간은 주휴 포함 월 소정근로시간, 1.2는 4대보험·퇴직금 몫이에요.")
                    LineRow(label: "\(Format.number(store.reducedStaffHoursPerDay))시간 × \(wage) × \(days)일", value: "월 \(Format.manWon(diag.removedStaffMonthlyKrw))", strong: true)
                    if diag.cleaningStaffMonthlyKrw > 0 {
                        LineRow(label: "직원 세척 하루 \(Int(Assumptions.cleaningMinutesPerDay))분", value: "월 −\(Format.manWon(diag.cleaningStaffMonthlyKrw))")
                    }
                }

                DisclosureCard(title: "전기료", systemImage: "bolt.fill", tint: Palette.warn) {
                    if let power = robot.power {
                        Formula(text: "\(Format.number(power.kw))kW × 하루 \(Int(Assumptions.robotHoursPerDay))시간 × kWh당 \(Int(Assumptions.electricityKrwPerKwh))원 × \(days)일" + (power.note.map { "\n\($0)" } ?? ""))
                        LineRow(label: "월 전기료", value: Format.manWon(electricity), strong: true)
                    } else {
                        Formula(text: "전력 정보가 공개되지 않아 0원으로 두었어요. 실제 비용은 더 들어요.")
                    }
                }

                DisclosureCard(title: "초기 자부담", systemImage: "wonsign.circle", tint: Palette.good) {
                    if let price = robot.purchasePriceKrw {
                        Formula(text: "구입가 \(Format.priceWon(price))\(robot.priceIncludesVat == false ? " (부가세 별도)" : "") − 지원금\n지원금 = 부가세 뺀 구입가 × 70%, 사업별 한도까지")
                        ForEach(result.subsidies) { sub in
                            LineRow(
                                label: sub.capKrw > 0 ? "\(sub.name) (한도 \(Format.priceWon(sub.capKrw)))" : sub.name,
                                value: Format.priceWon(sub.selfPayKrw),
                                strong: sub.subsidy == best?.subsidy
                            )
                        }
                    } else {
                        Formula(text: "구입가가 공개되지 않아 계산할 수 없어요.")
                    }
                }

                DisclosureCard(title: "회수 기간", systemImage: "calendar", tint: Palette.good) {
                    Formula(text: "자부담 ÷ 매달 아끼는 돈\n매달 아끼는 돈 = 인건비 \(Format.manWon(diag.removedStaffMonthlyKrw)) − 전기료 \(Format.manWon(electricity))" + (diag.cleaningStaffMonthlyKrw > 0 ? " − 세척 \(Format.manWon(diag.cleaningStaffMonthlyKrw))" : "") + " = \(Format.manWon(netSaving))")
                    ForEach(result.subsidies) { sub in
                        LineRow(label: "\(sub.name) · 첫해 현금 \(Format.signedManWon(sub.firstYearCashKrw))", value: Format.aboutMonths(sub.paybackMonths), strong: sub.subsidy == best?.subsidy)
                    }
                    Text("24개월 이하 추천, 36개월 이하 조건부 추천, 넘으면 비추천이에요.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                }

                if let best {
                    DisclosureCard(title: "로봇 월 비용", systemImage: "creditcard") {
                        Formula(text: "자부담 ÷ \(Int(Assumptions.robotCostMonths))개월(무상 A/S 기간) + 전기료")
                        ForEach(result.subsidies) { sub in
                            LineRow(label: sub.name, value: "월 \(Format.manWon(sub.robotMonthlyKrw))")
                        }
                        Text("\(best.name) 기준 월 비용은 알바 하루 약 \(String(format: "%.1f", Engine.robotAsStaffHours(best)))시간 몫이에요.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                    }
                }

                if let best {
                    DisclosureCard(title: "손익 분기 판매량", systemImage: "chart.bar.fill", tint: Palette.action) {
                        Formula(text: "로봇 월 비용(\(best.subsidy.short) 기준) ÷ (아낀 손작업 1개당 인건비 × \(days)일)\n아낀 손작업 1개당 인건비 = \(Int(Assumptions.handMinutesPerItem))분 × 대신하는 비율 × 시급 ÷ 60")
                        ForEach(Assumptions.replacementRates.reversed(), id: \.self) { rate in
                            LineRow(
                                label: "로봇이 손작업의 \(Int(rate * 100))%를 대신하면",
                                value: "하루 \(Engine.breakEvenPerDay(best, diag: diag, replacementRate: rate))개",
                                strong: rate == 0.6
                            )
                        }
                    }
                }

                DisclosureCard(title: "업주 시간 절감 효과", systemImage: "clock", tint: Palette.warn, assumed: true) {
                    Formula(text: "하루 평균 \(Int(diag.averageDailySales.rounded()))마리 = (평일 \(Format.number(store.sales.weekday))×\(Int(store.sales.weekdayCount))일 + 금토 \(Format.number(store.sales.busyDay))×\(Int(store.sales.busyDayCount))일) ÷ \(Int(store.sales.weekdayCount + store.sales.busyDayCount))일")
                    LineRow(label: "손작업 1마리 \(Int(Assumptions.handMinutesPerItem))분", value: "하루 \(Int(diag.handMinutesPerDay.rounded()))분")
                    LineRow(label: "로봇과 함께 1마리 \(Int(Assumptions.handMinutesWithRobot))분", value: "하루 \(Int(diag.handMinutesWithRobot.rounded()))분")
                    LineRow(label: "로봇 세척", value: "하루 +\(Int(Assumptions.cleaningMinutesPerDay))분")
                    LineRow(label: "하루 순 절약", value: "약 \(Int(diag.netMinutesSaved.rounded()))분", strong: true)
                    Text("시간은 돈으로 바꾸지 않았어요. 회수 기간은 실제로 줄어드는 알바 시간으로만 계산해요.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                }

                DisclosureCard(title: "추정값 목록", assumed: true) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(sources, id: \.self) { line in
                            Text("· \(line)")
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("계산 근거")
        .navigationBarTitleDisplayMode(.inline)
    }

    private let sources = [
        "손작업 1마리 5분, 로봇과 함께 2분: 공정 분해 추정 (실측 아님)",
        "로봇 세척 하루 20분: Miso Flippy 공개 사례 15분 + 여유",
        "월 영업일 26일: 외식업체 경영실태조사 응답 최빈값",
        "전기 kWh당 150원, 하루 10시간 가동",
        "지원금: 2026 경북 식품로봇 바우처 공고(경북ICT융합산업진흥협회), 2026 스마트상점 기술보급사업 공고",
        "로봇 제원·가격: 공급사·판매점 공개 자료 (확인일 2026.10)",
    ]
}
