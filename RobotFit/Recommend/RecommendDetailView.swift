import SwiftUI

struct RecommendDetailView: View {
    @Environment(DiagnosisModel.self) private var model
    let robotID: String

    @State private var stepIndex = 0
    @State private var playing = true

    var body: some View {
        if let robot = RobotPresentation.all(model: model).first(where: { $0.robot.id == robotID }) {
            content(robot)
        } else {
            ContentUnavailableView("로봇 정보를 찾을 수 없어요", systemImage: "questionmark.circle")
        }
    }

    private func content(_ robot: RobotPresentation) -> some View {
        let store = model.store
        let kitchen = model.kitchen
        let best = robot.result.best

        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Card(padding: 0) {
                    Kitchen3DView(
                        kitchen: kitchen,
                        fryLine: store.fryLineCm,
                        robots: robot.placed.map { [$0] } ?? [],
                        steps: robot.steps,
                        stepIndex: stepIndex,
                        showsMarker: robot.placed == nil
                    )
                    .frame(height: 240)
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24))
                    stepBar(robot)
                }

                Card {
                    Text(robot.detailBadge)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Palette.action)
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(robot.robot.displayName)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(Palette.ink)
                            Text(robot.maker)
                                .font(.system(size: 13))
                                .foregroundStyle(Palette.sub)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(robot.monthlyValue)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(Palette.ink)
                            Text(best == nil ? robot.priceLine : "36개월, \(robot.priceLine)")
                                .font(.system(size: 12))
                                .foregroundStyle(Palette.faint)
                        }
                    }
                    .padding(.top, 8)
                    Text(robot.headline)
                        .font(.system(size: 15))
                        .foregroundStyle(Palette.ink)
                        .padding(.top, 12)
                    VerdictBadge(verdict: robot.result.verdict, text: robot.result.badgeText)
                        .padding(.top, 10)
                }

                Card(padding: 0) {
                    keyRow("튀기는 양", "기준: 피크 1시간 \(Format.number(store.peakPerHour))마리", robot.capacityChip)
                    keyRow("줄어드는 인건비", "기준: 저녁 알바 하루 \(Format.number(store.reducedStaffHoursPerDay))시간, 주 6일", robot.laborText)
                    keyRow(
                        "월 비용",
                        best.map { "\($0.name) 자부담 \(Format.priceWon($0.selfPayKrw)) ÷ 36개월 + 전기료" } ?? "구입가 미공개",
                        robot.monthlyValue
                    )
                    keyRow("회수 기간", best.map { "\($0.subsidy.short) 기준" } ?? "가격이 공개되지 않았어요", robot.paybackText, last: true)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("설치 자리")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Palette.ink)
                    Text("\(model.scannedModelURL == nil ? "AI가 잰" : "LiDAR로 잰") 사장님 주방 \(Format.number(kitchen.widthM))×\(Format.number(kitchen.depthM))m 기준이에요")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.sub)
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)

                Card(padding: 0) {
                    keyRow("로봇 크기", "가로 × 깊이 × 높이", robot.sizeText)
                    keyRow("가로 여유", "예상 설치 위치 가로 \(Format.number(store.fryLineCm.w))cm에서 뺀 값", robot.marginW.map(Format.cm) ?? "확인 필요")
                    keyRow("깊이 여유", "예상 설치 위치 깊이 \(Format.number(store.fryLineCm.d))cm에서 뺀 값", robot.marginD.map(Format.cm) ?? "확인 필요")
                    keyRow("앞쪽 남는 폭", "주방 폭 \(Format.number(min(kitchen.widthM, kitchen.depthM) * 100))cm에서 로봇 깊이를 뺀 값", robot.frontWidth.map(Format.cm) ?? "확인 필요", last: true)
                }

                Card(padding: 8) {
                    link("계산 근거 보기", icon: "doc.text", tint: Palette.good) { model.path.append(.basis(robotID)) }
                    Divider()
                    link("비추천되는 경우 보기", icon: "exclamationmark.triangle", tint: Palette.bad) { model.path.append(.notRecommended(robotID)) }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .screenChrome("로봇 상세")
        .safeAreaInset(edge: .bottom) {
            FooterButtons {
                PrimaryButton(title: "이 로봇 견적 받기") { model.path.append(.quote(robotID)) }
            }
        }
        .task(id: playing) {
            guard playing, !robot.steps.isEmpty else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(1400))
                stepIndex = (stepIndex + 1) % robot.steps.count
            }
        }
    }

    private func stepBar(_ robot: RobotPresentation) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(robot.steps.isEmpty ? "일하는 순서" : "\(stepIndex + 1) / \(robot.steps.count) 단계")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.faint)
                Text(robot.steps.isEmpty ? "움직임 자료가 아직 없어요" : robot.steps[min(stepIndex, robot.steps.count - 1)])
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Palette.ink)
            }
            Spacer()
            if !robot.steps.isEmpty {
                Button {
                    playing.toggle()
                } label: {
                    Label(playing ? "멈춤" : "재생", systemImage: playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(Palette.canvas, in: Capsule())
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func keyRow(_ label: String, _ basis: String, _ value: String, last: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                    Text(basis)
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.sub)
                }
                Spacer(minLength: 8)
                Text(value)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            if !last { Divider().padding(.horizontal, 20) }
        }
    }

    private func link(_ title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                IconTile(systemName: icon, tint: tint)
                Text(title).foregroundStyle(Palette.ink)
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Palette.faint)
            }
            .padding(12)
        }
    }
}
