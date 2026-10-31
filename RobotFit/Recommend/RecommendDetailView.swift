import SwiftUI

struct RecommendDetailView: View {
    @Environment(DiagnosisModel.self) private var model
    let robotID: String

    @State private var showsBreakEven = false

    var body: some View {
        if let robot = RobotPresentation.all(model: model).first(where: { $0.robot.id == robotID }) {
            content(robot)
        } else {
            ContentUnavailableView("로봇 정보를 찾을 수 없어요", systemImage: "questionmark.circle")
        }
    }

    private func content(_ robot: RobotPresentation) -> some View {
        let result = robot.result
        let diag = model.evaluation.diag
        let color = Palette.verdict(result.verdict)

        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        Image(systemName: icon(result.verdict))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(color, in: Circle())
                        Text(result.badgeText)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(color)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.3), lineWidth: 1))
                    Text(headline(robot))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .padding(.top, 18)
                    VStack(alignment: .leading, spacing: 4) {
                        if let best = result.best, best.subsidy != .none {
                            Text("지원사업 적용 시 예상치(다음 공고 기준)")
                        }
                        if result.costIsMinimum {
                            Text("공개된 비용만으로 계산해 실제 회수 기간은 더 길 수 있어요")
                        }
                        Text("카탈로그 공개 자료 기준")
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.sub)
                    .padding(.top, 14)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(22)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(color.opacity(0.5), lineWidth: 2))

                if let best = result.best, best.paybackMonths != nil {
                    Card {
                        Button {
                            withAnimation(.snappy) { showsBreakEven.toggle() }
                        } label: {
                            HStack {
                                Text("손익 분기 판매량")
                                    .font(.system(size: 15))
                                    .foregroundStyle(Palette.ink)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .foregroundStyle(Palette.faint)
                                    .rotationEffect(.degrees(showsBreakEven ? 180 : 0))
                            }
                        }
                        .buttonStyle(.plain)
                        if showsBreakEven {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("하루 이만큼 팔면 로봇 월 비용(\(best.subsidy.short) 기준)을 아낀 손작업으로 메워요. 지금 하루 평균은 \(Int(diag.averageDailySales.rounded()))개예요.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Palette.sub)
                                    .padding(.vertical, 8)
                                ForEach(Assumptions.replacementRates.reversed(), id: \.self) { rate in
                                    LineRow(
                                        label: "로봇이 손작업의 \(Int(rate * 100))%를 대신하면",
                                        value: "하루 \(Engine.breakEvenPerDay(best, diag: diag, replacementRate: rate))개",
                                        strong: rate == 0.6
                                    )
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                }

                if !result.subsidies.isEmpty {
                    Card {
                        Text("구매 방법별 투자 비용 회수 기간")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Palette.ink)
                            .padding(.bottom, 8)
                        ForEach(Array(result.subsidies.enumerated()), id: \.offset) { index, sub in
                            let shown: Verdict = result.costIsMinimum && sub.verdict != .notRecommended ? .check : sub.verdict
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(sub.subsidy.short)
                                        .font(.system(size: 13))
                                        .foregroundStyle(Palette.sub)
                                    Text(Format.aboutMonths(sub.paybackMonths) + (result.costIsMinimum && sub.paybackMonths != nil ? " 이상" : ""))
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(Palette.ink)
                                }
                                Spacer()
                                if sub.subsidy == result.best?.subsidy {
                                    VerdictBadge(verdict: shown, text: shown.label)
                                }
                            }
                            .padding(.vertical, 10)
                            if index < result.subsidies.count - 1 {
                                Divider()
                            }
                        }
                    }
                }

                Card {
                    HStack(spacing: 10) {
                        IconTile(systemName: "clock.fill", tint: Palette.warn)
                        Text("로봇 도입 후 아끼는 시간")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Palette.ink)
                    }
                    .padding(.bottom, 8)
                    LineRow(label: "수작업 절감", value: "하루 \(duration(diag.handMinutesPerDay)) → \(duration(diag.handMinutesWithRobot))", strong: true)
                    Divider()
                    LineRow(label: "하루 순 절약", value: "약 \(duration(diag.netMinutesSaved))", strong: true)
                    HStack(spacing: 6) {
                        AssumedTag(text: "추정값")
                        Text("아낀 시간을 인건비(금액)로 환산하진 않았어요")
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.sub)
                    }
                    .padding(.top, 10)
                }

                Card(padding: 8) {
                    link("계산 근거 보기", icon: "doc.text.fill", tint: Palette.good) { model.path.append(.basis(robotID)) }
                    Divider().padding(.horizontal, 12)
                    link("비추천하는 경우 보기", icon: "exclamationmark.triangle.fill", tint: Palette.bad) { model.path.append(.notRecommended(robotID)) }
                }

                Note(text: "판정 기준은 공급기업 이용료와 무관해요.")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .screenChrome(robot.robot.displayName)
        .safeAreaInset(edge: .bottom) {
            FooterButtons {
                PrimaryButton(title: "견적 비교 보기") { model.path.append(.quote(robotID)) }
            }
        }
    }

    private func headline(_ robot: RobotPresentation) -> String {
        let result = robot.result
        switch result.verdict {
        case .notRecommended: return result.reason
        case .check: return "\(result.reason)라 도입 전 확인이 필요해요"
        default:
            guard let best = result.best, let months = best.paybackMonths else { return result.verdict.label }
            let when = best.subsidy == .none ? "지원 없이도" : "\(best.subsidy.short)에 선정되면"
            return "\(when) 약 \(Int(months.rounded()))개월 만에 투자금을 회수해요"
        }
    }

    private func icon(_ verdict: Verdict) -> String {
        switch verdict {
        case .recommend: "checkmark"
        case .conditional: "exclamationmark"
        case .check: "questionmark"
        case .notRecommended: "xmark"
        }
    }

    private func duration(_ minutes: Double) -> String {
        let total = max(0, Int(minutes.rounded()))
        let hours = total / 60
        let rest = total % 60
        if hours == 0 { return "\(rest)분" }
        return rest == 0 ? "\(hours)시간" : "\(hours)시간 \(rest)분"
    }

    private func link(_ title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                IconTile(systemName: icon, tint: tint)
                Text(title)
                    .font(.system(size: 16))
                    .foregroundStyle(Palette.ink)
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Palette.faint)
            }
            .padding(12)
        }
    }
}
