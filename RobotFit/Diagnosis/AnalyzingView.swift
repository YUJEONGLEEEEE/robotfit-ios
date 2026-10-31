import SwiftUI

struct AnalyzingView: View {
    @Environment(DiagnosisModel.self) private var model
    @State private var bubbles: [(text: String, live: Bool)] = [("메뉴판 읽는 중", true)]
    @State private var started = false
    @State private var pulse = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Headline(title: "사진을 읽고 있어요", sub: "메뉴판과 주방 사진을 확인하는 중이에요.\n잠시만 기다려 주세요.")
                Image("ChefRobot")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 300)
                    .frame(maxWidth: .infinity)
                    .opacity(pulse ? 1 : 0.6)
                    .animation(.easeInOut(duration: 0.9).repeatForever(), value: pulse)
                ForEach(Array(bubbles.enumerated()), id: \.offset) { _, bubble in
                    HStack(spacing: 12) {
                        RobotMark(size: 22)
                            .frame(width: 40, height: 40)
                            .background(Color(.secondarySystemGroupedBackground), in: Circle())
                        HStack(spacing: 8) {
                            if bubble.live {
                                Circle().fill(.green).frame(width: 8, height: 8)
                            }
                            Text(bubble.text + (bubble.live ? "…" : ""))
                                .font(.subheadline.weight(.medium))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .foregroundStyle(bubble.live ? Color(.systemBackground) : .primary)
                        .background(bubble.live ? Color.primary : Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("AI 분석")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .task {
            guard !started else { return }
            started = true
            pulse = true
            await run()
        }
    }

    private func run() async {
        let analysis = PhotoAnalysis.example
        try? await Task.sleep(for: .milliseconds(1400))
        withAnimation { bubbles = [("메뉴판 읽기 완료", false), ("주방 사진 읽는 중", true)] }
        try? await Task.sleep(for: .milliseconds(1000))
        let lines = summary(analysis)
        for count in 1...lines.count {
            withAnimation { bubbles = lines.prefix(count).map { ($0, false) } }
            try? await Task.sleep(for: .milliseconds(550))
        }
        try? await Task.sleep(for: .milliseconds(500))
        model.applyAnalysis(analysis)
        if !model.path.isEmpty { model.path.removeLast() }
        model.path.append(.result)
    }

    private func summary(_ analysis: PhotoAnalysis) -> [String] {
        let names = analysis.menus.prefix(3).map(\.name).joined(separator: "·")
        var lines = [
            "메뉴 \(analysis.menus.count)개를 찾았어요 (\(names)\(analysis.menus.count > 3 ? " 외" : ""))",
            "주요 공정은 \(analysis.processes.map(\.label).joined(separator: "·"))이에요",
        ]
        if let fryers = analysis.fryerCount { lines.append("튀김기 \(fryers)대를 찾았어요") }
        if let hood = analysis.hasExhaustHood { lines.append("배기 후드가 \(hood ? "있어요" : "안 보여요")") }
        return lines
    }
}
