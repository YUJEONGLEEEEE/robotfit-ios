import SwiftUI

struct RecommendView: View {
    @Environment(DiagnosisModel.self) private var model

    static let maxCompare = 3

    @State private var expanded: String?
    @State private var focus: String?
    @State private var selecting = false
    @State private var picked: [String] = []
    @State private var isFull = false
    @State private var dragOffset: CGFloat = 0
    @State private var tick = 0
    @State private var toast: String?

    var body: some View {
        let robots = RobotPresentation.all(model: model)
        let focused = robots.first { $0.robot.id == (focus ?? robots.first?.robot.id) }

        GeometryReader { geo in
            let halfTop = geo.size.height * 0.42
            let top = max(0, (isFull ? 0 : halfTop) + dragOffset)

            ZStack(alignment: .top) {
                Kitchen3DView(
                    kitchen: model.displayKitchen,
                    fryLine: model.store.fryLineCm,
                    robots: focused?.placed.map { [$0] } ?? [],
                    steps: focused?.steps ?? [],
                    stepIndex: focused.map { $0.steps.isEmpty ? 0 : tick % $0.steps.count } ?? 0,
                    showsMarker: focused?.placed == nil
                )
                .frame(height: halfTop + 24)
                .overlay(alignment: .topLeading) {
                    if !model.kitchenKnown {
                        Text("주방 크기 미입력 · 설치 위치 기준 공간")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Palette.sub)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.white.opacity(0.9), in: Capsule())
                            .padding(12)
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    if let focused {
                        stepCaption(focused)
                            .padding(.leading, 16)
                            .padding(.bottom, 40)
                    }
                }

                sheet(robots)
                    .frame(height: geo.size.height - top + 20)
                    .offset(y: top)
            }
        }
        .background(Palette.canvas.ignoresSafeArea())
        .screenChrome("로봇 추천")
        .safeAreaInset(edge: .bottom) {
            if selecting {
                FooterButtons {
                    HStack(spacing: 12) {
                        Text(pickText)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                        Spacer()
                        Button {
                            openCompare()
                        } label: {
                            Text("비교하기")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 24)
                                .frame(height: 48)
                                .background(picked.count >= 2 ? Palette.action : Palette.disabled, in: Capsule())
                        }
                        .disabled(picked.count < 2)
                    }
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Palette.ink.opacity(0.9), in: Capsule())
                    .padding(.bottom, 96)
                    .transition(.opacity)
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(1200))
                tick += 1
            }
        }
    }

    private var pickText: String {
        let robots = RobotPresentation.all(model: model)
        let names = picked.compactMap { id in robots.first { $0.robot.id == id }?.robot.displayName }
        switch names.count {
        case 0: return "비교할 로봇을 골라 주세요"
        case 1: return "\(names[0]) · 1대 더 골라 주세요"
        default: return "\(names[0]) 외 \(names.count - 1)개"
        }
    }

    private func stepCaption(_ robot: RobotPresentation) -> some View {
        let steps = robot.steps
        let index = steps.isEmpty ? 0 : tick % steps.count
        return VStack(alignment: .leading, spacing: 2) {
            Text(steps.isEmpty ? robot.robot.displayName : "\(robot.robot.displayName) 일하는 순서 \(index + 1)/\(steps.count)")
                .font(.system(size: 11))
                .foregroundStyle(Palette.sub)
            Text(steps.isEmpty ? "움직임 자료가 아직 없어요" : steps[index])
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Palette.ink)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 12))
    }

    private func sheet(_ robots: [RobotPresentation]) -> some View {
        VStack(spacing: 0) {
            ZStack {
                Capsule()
                    .fill(Palette.disabled)
                    .frame(width: 40, height: 5)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 8)
                HStack {
                    Text("총 \(robots.count)개 추천 결과")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Palette.ink)
                    Spacer()
                    Button {
                        withAnimation(.snappy) {
                            selecting.toggle()
                            picked = selecting ? [focus ?? robots.first?.robot.id].compactMap { $0 } : []
                        }
                    } label: {
                        Label(selecting ? "비교 끝내기" : "비교하기", systemImage: "chart.bar.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .frame(height: 40)
                            .background(Palette.action, in: Capsule())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
            }
            .frame(height: 68)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { dragOffset = $0.translation.height }
                    .onEnded { value in
                        withAnimation(.snappy) {
                            if value.translation.height < -60 { isFull = true }
                            if value.translation.height > 60 { isFull = false }
                            dragOffset = 0
                        }
                    }
            )
            .onTapGesture {
                withAnimation(.snappy) { isFull.toggle() }
            }

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(robots, id: \.robot.id) { robot in
                        card(robot)
                    }
                    Text("월 비용은 가장 유리한 지원사업을 적용한 자부담을 36개월로 나누고 전기료를 더한 예상치예요. 처리량·가격이 공개되지 않은 로봇은 '확인 필요'로 표시해요.")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.sub)
                        .padding(.horizontal, 8)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
        .background(Palette.canvas, in: UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24))
        .shadow(color: .black.opacity(0.08), radius: 12, y: -2)
    }

    private func card(_ robot: RobotPresentation) -> some View {
        let id = robot.robot.id
        let isOpen = expanded == id && !selecting
        let isPicked = picked.contains(id)

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                tap(id)
            } label: {
                HStack(alignment: .top, spacing: 16) {
                    imagePlaceholder(robot, picked: isPicked)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(robot.maker)
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.sub)
                        Text(robot.robot.displayName)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Palette.ink)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(robot.monthlyValue)
                                .font(.system(size: 19, weight: .bold))
                                .foregroundStyle(Palette.ink)
                            if robot.result.best != nil {
                                Text("36개월")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Palette.faint)
                            }
                        }
                        .padding(.top, 2)
                        Text(robot.priceLine)
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.faint)
                        FlowChips(items: [robot.capacityChip] + [robot.subsidyNote].compactMap { $0 })
                            .padding(.top, 8)
                        VerdictBadge(verdict: robot.result.verdict, text: robot.result.badgeText)
                            .padding(.top, 6)
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            if isOpen {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(robot.points, id: \.self) { point in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Circle().fill(Palette.ink).frame(width: 4, height: 4)
                                Text(point)
                                    .font(.system(size: 14))
                                    .foregroundStyle(Palette.ink)
                            }
                        }
                    }
                    HStack(spacing: 8) {
                        tile("줄어드는 인건비", robot.laborText)
                        tile("설치 자리", robot.fitShort)
                    }
                    Button {
                        model.path.append(.robot(id))
                    } label: {
                        HStack(spacing: 4) {
                            Text("\(robot.robot.displayName) 상세 보기")
                            Image(systemName: "chevron.right")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Palette.ink, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.top, 16)
            }
        }
        .padding(20)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isOpen || isPicked ? Palette.ink : .clear, lineWidth: 2)
        )
    }

    private func imagePlaceholder(_ robot: RobotPresentation, picked: Bool) -> some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color(red: 0.99, green: 0.925, blue: 0.86))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Palette.action, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            )
            .overlay {
                Text("이미지")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red: 0.53, green: 0.24, blue: 0.01))
            }
            .overlay(alignment: .topLeading) {
                if robot.isTop {
                    Text("추천 1위")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .frame(height: 22)
                        .background(Palette.action, in: RoundedRectangle(cornerRadius: 6))
                        .padding(6)
                }
            }
            .overlay(alignment: .topTrailing) {
                if selecting {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(picked ? Palette.action : Palette.disabled, in: Circle())
                        .padding(6)
                }
            }
            .frame(width: 104, height: 104)
    }

    private func tile(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Palette.sub)
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Palette.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Palette.canvas, in: RoundedRectangle(cornerRadius: 12))
    }

    private func tap(_ id: String) {
        withAnimation(.snappy) {
            focus = id
            tick = 0
            if selecting {
                if let index = picked.firstIndex(of: id) {
                    picked.remove(at: index)
                } else if picked.count < Self.maxCompare {
                    picked.append(id)
                } else {
                    show("최대 \(Self.maxCompare)대까지 비교할 수 있어요")
                }
            } else {
                expanded = expanded == id ? nil : id
            }
        }
    }

    private func show(_ message: String) {
        toast = message
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { toast = nil }
        }
    }

    private func openCompare() {
        guard picked.count >= 2 else { return }
        model.path.append(.compareRobots(picked))
    }
}

struct FlowChips: View {
    let items: [String]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(Palette.canvas, in: RoundedRectangle(cornerRadius: 6))
            }
        }
    }
}
