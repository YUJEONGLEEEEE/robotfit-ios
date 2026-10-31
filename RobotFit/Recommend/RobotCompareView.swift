import SwiftUI

struct RobotCompareView: View {
    @Environment(DiagnosisModel.self) private var model
    let robotIDs: [String]

    @State private var baseID: String?
    @State private var tick = 0

    var body: some View {
        let all = RobotPresentation.all(model: model)
        let robots = robotIDs.compactMap { id in all.first { $0.robot.id == id } }

        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if robots.count == 2 {
                    Headline(
                        title: "두 로봇을 나란히 비교해요",
                        sub: "사장님 주방 \(Format.number(model.kitchen.widthM))×\(Format.number(model.kitchen.depthM))m에 각각 실제 크기로 놓아 봤어요."
                    )
                    SideBySide(robots: robots, tick: tick)
                } else {
                    Headline(title: "고른 로봇 \(robots.count)대를 비교해요", sub: "로봇을 누르면 그 로봇을 기준으로 차이를 보여줘요.")
                    BaseComparison(robots: robots, baseID: $baseID, tick: tick)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .screenChrome("로봇 비교")
        .safeAreaInset(edge: .bottom) {
            if robots.count == 2 {
                FooterButtons {
                    HStack(spacing: 8) {
                        ForEach(robots, id: \.robot.id) { robot in
                            PrimaryButton(title: "\(robot.robot.displayName) 상세") {
                                model.path.append(.robot(robot.robot.id))
                            }
                        }
                    }
                }
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(1400))
                tick += 1
            }
        }
    }
}

private struct SideBySide: View {
    @Environment(DiagnosisModel.self) private var model
    let robots: [RobotPresentation]
    let tick: Int

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ForEach(robots, id: \.robot.id) { robot in
                    VStack(spacing: 0) {
                        Kitchen3DView(
                            kitchen: model.kitchen,
                            fryLine: model.store.fryLineCm,
                            robots: robot.placed.map { [$0] } ?? [],
                            steps: robot.steps,
                            stepIndex: robot.steps.isEmpty ? 0 : tick % robot.steps.count,
                            showsMarker: robot.placed == nil
                        )
                        .frame(height: 150)
                        Text(robot.robot.displayName)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Palette.ink)
                            .padding(.vertical, 10)
                    }
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }

            section("요약") {
                pair { robot in
                    VStack(spacing: 2) {
                        Text(robot.robot.throughputPerHour.map { Format.number($0) } ?? "—")
                            .font(.system(size: 30, weight: .bold))
                        + Text("마리").font(.system(size: 16, weight: .bold))
                        Text("시간당 튀기는 양")
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.sub)
                        VerdictBadge(verdict: robot.result.verdict, text: robot.result.verdict.label)
                            .padding(.top, 6)
                    }
                }
                VStack(spacing: 2) {
                    Text("두 로봇 모두 줄어드는 인건비")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.sub)
                    Text(robots.first?.laborText ?? "")
                        .font(.system(size: 26, weight: .bold))
                    HStack(spacing: 6) {
                        Text("저녁 알바 하루 \(Format.number(model.store.reducedStaffHoursPerDay))시간, 주 6일 몫")
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.sub)
                        AssumedTag(text: "추정값")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Palette.canvas, in: RoundedRectangle(cornerRadius: 12))
                .padding(.top, 12)
            }

            section("설치 자리", caption: "예상 설치 위치 \(Format.number(model.store.fryLineCm.w))×\(Format.number(model.store.fryLineCm.d))cm 기준이에요") {
                pair { robot in
                    VStack(spacing: 10) {
                        Text(robot.robot.sizeCm.map { "\(Format.number($0.w))×\(Format.number($0.d))" } ?? "크기 미공개")
                            .font(.system(size: 20, weight: .bold))
                        fact(robot.fitLong, "들어가나")
                        fact(robot.frontWidth.map(Format.cm) ?? "—", "앞쪽 남는 폭")
                        fact(robot.robot.sizeCm.map { Format.cm($0.h) } ?? "—", "높이 (주방 \(Format.number(model.kitchen.heightM))m)")
                    }
                }
            }

            section("이렇게 일해요") {
                pair { robot in
                    VStack(alignment: .leading, spacing: 6) {
                        if robot.steps.isEmpty {
                            Text("자료가 아직 없어요")
                                .font(.system(size: 13))
                                .foregroundStyle(Palette.sub)
                        }
                        ForEach(Array(robot.steps.enumerated()), id: \.offset) { index, step in
                            let active = index == tick % max(robot.steps.count, 1)
                            Text("\(index + 1). \(step)")
                                .font(.system(size: 13, weight: active ? .bold : .regular))
                                .foregroundStyle(active ? Palette.action : Palette.ink)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            section("비용") {
                pair { robot in
                    VStack(spacing: 10) {
                        Text(robot.monthlyValue)
                            .font(.system(size: 22, weight: .bold))
                        fact(robot.robot.purchasePriceKrw.map(Format.priceWon) ?? "미공개", "구입가")
                        fact(robot.installFeeText, "설치비")
                        fact(robot.careText, "유지보수")
                        fact(robot.paybackText, "회수 기간")
                    }
                }
            }
        }
    }

    private func section<Content: View>(_ title: String, caption: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        Card(padding: 12) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .padding(.horizontal, 8)
                .padding(.bottom, 10)
            Divider()
            if let caption {
                Text(caption)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.sub)
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
            }
            content()
                .padding(.top, 12)
        }
        .foregroundStyle(Palette.ink)
    }

    private func pair<Content: View>(@ViewBuilder content: @escaping (RobotPresentation) -> Content) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(robots.enumerated()), id: \.offset) { index, robot in
                content(robot)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 6)
                if index == 0 {
                    Divider()
                }
            }
        }
    }

    private func fact(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .multilineTextAlignment(.center)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Palette.sub)
        }
    }
}

private struct BaseComparison: View {
    @Environment(DiagnosisModel.self) private var model
    let robots: [RobotPresentation]
    @Binding var baseID: String?
    let tick: Int

    private struct Metric {
        let title: String
        let sub: String
        let value: (RobotPresentation) -> Double?
        let format: (Double) -> String
        let higherBetter: Bool
        let mark: Double?
    }

    var body: some View {
        let base = robots.first { $0.robot.id == baseID } ?? robots[0]
        let store = model.store

        VStack(spacing: 12) {
            Card(padding: 0) {
                Kitchen3DView(
                    kitchen: model.kitchen,
                    fryLine: store.fryLineCm,
                    robots: base.placed.map { [$0] } ?? [],
                    steps: base.steps,
                    stepIndex: base.steps.isEmpty ? 0 : tick % base.steps.count,
                    showsMarker: base.placed == nil
                )
                .frame(height: 220)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24))
                HStack(spacing: 6) {
                    ForEach(robots, id: \.robot.id) { robot in
                        let selected = robot.robot.id == base.robot.id
                        Button(robot.robot.displayName) { baseID = robot.robot.id }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(selected ? .white : Palette.sub)
                            .padding(.horizontal, 12)
                            .frame(height: 30)
                            .background(selected ? Palette.ink : Palette.canvas, in: Capsule())
                    }
                }
                .padding(14)
            }

            Card {
                Text("기준 로봇")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(red: 0.53, green: 0.24, blue: 0.01))
                Text(base.robot.displayName)
                    .font(.system(size: 17, weight: .bold))
                    .padding(.top, 2)
                Text("\(base.fitLine). \(base.capacityChip), \(base.monthlyValue)")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.sub)
                    .padding(.top, 4)
            }

            group("요약", metrics: [
                Metric(title: "시간당 튀기는 양", sub: "많을수록 좋아요. 검은 선은 사장님 가게 피크 1시간 \(Format.number(store.peakPerHour))마리예요.",
                       value: { $0.robot.throughputPerHour }, format: { "\(Format.number($0))마리" }, higherBetter: true, mark: store.peakPerHour),
                Metric(title: "회수 기간", sub: "짧을수록 좋아요", value: { $0.result.best?.paybackMonths }, format: { "약 \(Int($0.rounded()))개월" }, higherBetter: false, mark: nil),
            ], base: base, labor: true)

            group("설치 자리", metrics: [
                Metric(title: "가로 여유", sub: "예상 설치 위치 \(Format.number(store.fryLineCm.w))cm 기준, 남을수록 좋아요", value: { $0.marginW }, format: Format.cm, higherBetter: true, mark: nil),
                Metric(title: "깊이 여유", sub: "예상 설치 위치 \(Format.number(store.fryLineCm.d))cm 기준, 남을수록 좋아요", value: { $0.marginD }, format: Format.cm, higherBetter: true, mark: nil),
                Metric(title: "앞쪽 남는 폭", sub: "넓을수록 지나다니기 편해요", value: { $0.frontWidth }, format: Format.cm, higherBetter: true, mark: nil),
            ], base: base, labor: false)

            group("비용", metrics: [
                Metric(title: "월 비용", sub: "가장 유리한 지원사업 기준, 낮을수록 좋아요", value: { $0.result.best?.robotMonthlyKrw }, format: { Format.priceWon($0) }, higherBetter: false, mark: nil),
                Metric(title: "구입가", sub: "낮을수록 좋아요", value: { $0.robot.purchasePriceKrw }, format: { Format.priceWon($0) }, higherBetter: false, mark: nil),
            ], base: base, labor: false)

            Card {
                Text("이렇게 일해요")
                    .font(.system(size: 15, weight: .bold))
                    .padding(.bottom, 10)
                ForEach(robots, id: \.robot.id) { robot in
                    HStack(alignment: .top) {
                        Text(robot.robot.displayName)
                            .font(.system(size: 13, weight: robot.robot.id == base.robot.id ? .bold : .medium))
                            .frame(width: 96, alignment: .leading)
                        Text(robot.steps.isEmpty ? "자료가 아직 없어요" : robot.steps.joined(separator: " → "))
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.sub)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .foregroundStyle(Palette.ink)
    }

    private func group(_ title: String, metrics: [Metric], base: RobotPresentation, labor: Bool) -> some View {
        Card {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .padding(.bottom, 10)
            Divider()
            ForEach(Array(metrics.enumerated()), id: \.offset) { _, metric in
                chart(metric, base: base)
                    .padding(.top, 14)
            }
            if labor {
                VStack(spacing: 2) {
                    Text("어떤 로봇이든 줄어드는 인건비")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.sub)
                    Text(base.laborText)
                        .font(.system(size: 26, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Palette.canvas, in: RoundedRectangle(cornerRadius: 12))
                .padding(.top, 14)
            }
        }
    }

    private func chart(_ metric: Metric, base: RobotPresentation) -> some View {
        let values = robots.map { metric.value($0) }
        let maxValue = max(values.compactMap { $0.map(abs) }.max() ?? 1, metric.mark ?? 0, 1)
        let baseValue = metric.value(base)

        return VStack(alignment: .leading, spacing: 8) {
            Text(metric.title)
                .font(.system(size: 14, weight: .semibold))
            Text(metric.sub)
                .font(.system(size: 12))
                .foregroundStyle(Palette.sub)
            ForEach(robots, id: \.robot.id) { robot in
                let value = metric.value(robot)
                let isBase = robot.robot.id == base.robot.id
                Button {
                    baseID = robot.robot.id
                } label: {
                    HStack(spacing: 8) {
                        Text(robot.robot.displayName)
                            .font(.system(size: 12, weight: isBase ? .bold : .medium))
                            .foregroundStyle(isBase ? Palette.ink : Palette.sub)
                            .frame(width: 70, alignment: .leading)
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Palette.canvas)
                                Capsule()
                                    .fill(isBase ? Palette.action : Palette.faint)
                                    .frame(width: proxy.size.width * max(0, (value ?? 0)) / maxValue)
                                if let mark = metric.mark {
                                    Rectangle()
                                        .fill(Palette.ink)
                                        .frame(width: 2)
                                        .offset(x: proxy.size.width * mark / maxValue)
                                }
                            }
                        }
                        .frame(height: 12)
                        VStack(alignment: .trailing, spacing: 0) {
                            Text(value.map(metric.format) ?? "미공개")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Palette.ink)
                            Text(diffText(value, baseValue, isBase: isBase, metric: metric))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(isBase ? Color(red: 0.53, green: 0.24, blue: 0.01) : isBetter(value, baseValue, metric: metric) ? Palette.good : Palette.faint)
                        }
                        .frame(width: 78, alignment: .trailing)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func diffText(_ value: Double?, _ base: Double?, isBase: Bool, metric: Metric) -> String {
        if isBase { return "기준" }
        guard let value, let base else { return "" }
        let diff = value - base
        guard diff != 0 else { return "같음" }
        return "\(diff > 0 ? "+" : "−")\(metric.format(abs(diff)))"
    }

    private func isBetter(_ value: Double?, _ base: Double?, metric: Metric) -> Bool {
        guard let value, let base, value != base else { return false }
        return (value > base) == metric.higherBetter
    }
}
