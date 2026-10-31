import SwiftUI

struct SizeView: View {
    @Environment(DiagnosisModel.self) private var model

    private let strokes: [Color] = [.primary, .accentColor]

    var body: some View {
        let store = model.store
        let kitchen = model.kitchen
        let robots = Engine.compare(model.evaluation.results).compared.filter { $0.robot.sizeCm != nil }
        let depth = kitchen.depthM * 100
        let line = store.fryLineCm
        let maxDepth = max(line.d, robots.compactMap { $0.robot.sizeCm?.d }.max() ?? 0)
        let realAisle = Int((depth - maxDepth - kitchen.worktableCm).rounded())
        let lineAisle = Int((depth - line.d - kitchen.worktableCm).rounded())

        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Headline(
                    title: robots.count > 1 ? "두 로봇 모두 통로 \(realAisle)cm가 남아요" : "통로 \(realAisle)cm가 남아요",
                    sub: "\(store.name) \(kitchen.pyeong)평 주방(\(Format.number(kitchen.widthM))×\(String(format: "%.1f", kitchen.depthM))m) 평면 위에 로봇을 실제 크기 비율로 놓았어요."
                )
                Card(padding: 16) {
                    FloorPlan(kitchen: kitchen, line: line, robots: robots, strokes: strokes, aisle: realAisle)
                        .aspectRatio(kitchen.widthM / kitchen.depthM, contentMode: .fit)
                    HStack(spacing: 16) {
                        ForEach(Array(robots.enumerated()), id: \.offset) { index, result in
                            HStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 2)
                                    .stroke(strokes[index], style: StrokeStyle(lineWidth: 2, dash: index == 0 ? [] : [4, 3]))
                                    .frame(width: 20, height: 12)
                                Text(result.robot.displayName)
                            }
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 12)
                    Text("\(lineAisle != realAisle ? "튀김 라인만 있을 때 통로는 \(lineAisle)cm예요. " : "")도입 전에 현장 실측이 필요해요.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                }
                ForEach(robots) { result in
                    if let size = result.robot.sizeCm {
                        let marginW = line.w - size.w
                        let marginD = line.d - size.d
                        let fits = marginW >= 0 && marginD >= 0
                        Card {
                            HStack {
                                Text(result.robot.displayName).font(.headline)
                                Spacer()
                                Text("\(Format.number(size.w))×\(Format.number(size.d))cm")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            LineRow(label: "가로 여유", value: Format.cm(marginW))
                            LineRow(label: "깊이 여유", value: marginD >= 0 ? Format.cm(marginD) : "\(Format.cm(-marginD)) 튀어나옴")
                            LineRow(
                                label: "설치 공간",
                                value: !fits ? "들어가지 않음" : marginW < Assumptions.tightMarginCm ? "빠듯" : "넉넉",
                                strong: true
                            )
                        }
                    }
                }
                Note(text: "폭 여유가 \(Int(Assumptions.tightMarginCm))cm 미만이면 '빠듯'으로 표시해요. 배치도는 합성 예시예요.")
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("실제 크기로 보기")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if let first = robots.first {
                FooterButtons {
                    PrimaryButton(title: "\(first.robot.displayName) 자세히 보기") {
                        model.path.append(.detail(first.robot.id))
                    }
                }
            }
        }
    }
}

private struct FloorPlan: View {
    let kitchen: Kitchen
    let line: StoreProfile.Line
    let robots: [RobotResult]
    let strokes: [Color]
    let aisle: Int

    var body: some View {
        Canvas { context, size in
            let widthCm = kitchen.widthM * 100
            let depthCm = kitchen.depthM * 100
            let scale = min(size.width / widthCm, size.height / depthCm)
            func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> CGRect {
                CGRect(x: x * scale, y: y * scale, width: w * scale, height: h * scale)
            }
            let lineX = 20.0
            let room = rect(0, 0, widthCm, depthCm)
            context.fill(Path(roundedRect: room, cornerRadius: 6), with: .color(Color(.systemGray6)))
            context.stroke(Path(roundedRect: room, cornerRadius: 6), with: .color(Color(.systemGray3)), lineWidth: 2)

            let fryLine = rect(lineX, 0, line.w, line.d)
            context.fill(Path(fryLine), with: .color(Color(.systemGray5)))
            context.stroke(Path(fryLine), with: .color(Color(.systemGray2)), lineWidth: 1.5)
            context.draw(Text("튀김 라인 \(Format.number(line.w))×\(Format.number(line.d))").font(.caption2).foregroundStyle(.secondary),
                         at: CGPoint(x: (lineX + line.w + 8) * scale, y: 14), anchor: .leading)

            let worktable = rect(0, depthCm - kitchen.worktableCm, widthCm, kitchen.worktableCm)
            context.fill(Path(worktable), with: .color(Color(.systemGray5)))
            context.draw(Text("맞은편 작업대").font(.caption2).foregroundStyle(.secondary),
                         at: CGPoint(x: worktable.midX, y: worktable.midY))

            for (index, result) in robots.enumerated() {
                guard let s = result.robot.sizeCm else { continue }
                let box = rect(lineX, 0, s.w, s.d)
                if index == 0 {
                    context.fill(Path(box), with: .color(strokes[0].opacity(0.08)))
                }
                context.stroke(Path(box), with: .color(strokes[index]), style: StrokeStyle(lineWidth: 2.5, dash: index == 0 ? [] : [8, 5]))
                let name = result.robot.displayName.replacingOccurrences(of: "튀김로봇 ", with: "")
                context.draw(Text("\(name) \(Format.number(s.w))×\(Format.number(s.d))").font(.caption2.bold()).foregroundStyle(strokes[index]),
                             at: CGPoint(x: box.minX + 6, y: index == 0 ? box.minY + 12 : box.maxY + 12), anchor: .leading)
            }

            let maxDepth = max(line.d, robots.compactMap { $0.robot.sizeCm?.d }.max() ?? 0)
            let arrowX = (widthCm - 60) * scale
            var arrow = Path()
            arrow.move(to: CGPoint(x: arrowX, y: (maxDepth + 6) * scale))
            arrow.addLine(to: CGPoint(x: arrowX, y: (depthCm - kitchen.worktableCm - 6) * scale))
            context.stroke(arrow, with: .color(.primary), lineWidth: 1.5)
            context.draw(Text("통로 약 \(aisle)cm").font(.caption.bold()),
                         at: CGPoint(x: arrowX - 8, y: ((maxDepth + depthCm - kitchen.worktableCm) / 2) * scale), anchor: .trailing)
        }
    }
}
