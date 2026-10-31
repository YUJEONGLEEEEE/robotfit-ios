import SwiftUI

struct AnalyzingView: View {
    @Environment(DiagnosisModel.self) private var model
    @State private var bubbles: [Bubble] = [Bubble(text: "메뉴판 읽는 중", live: true)]
    @State private var started = false
    @State private var bob = false

    struct Bubble: Identifiable, Equatable {
        let id = UUID()
        let text: String
        var live = false
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Headline(title: "AI가 사진을 읽고 있어요", sub: "메뉴판과 주방 사진을 확인하는 중이에요.\n잠시만 기다려 주세요.")
                    .padding(.top, 8)
                Image("ChefRobot")
                    .resizable()
                    .scaledToFit()
                    .blendMode(.multiply)
                    .frame(maxWidth: 260)
                    .frame(maxWidth: .infinity)
                    .offset(y: bob ? -6 : 6)
                    .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: bob)
                    .padding(.vertical, 28)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(bubbles) { bubble in
                        HStack(spacing: 10) {
                            RobotMark(size: 18)
                                .frame(width: 44, height: 44)
                                .background(Color.white, in: Circle())
                            HStack(spacing: 8) {
                                if bubble.live {
                                    Circle()
                                        .fill(Color(red: 0.204, green: 0.78, blue: 0.349))
                                        .frame(width: 8, height: 8)
                                }
                                Text(bubble.live ? "\(bubble.text)~" : bubble.text)
                                    .font(.system(size: 15, weight: .medium))
                            }
                            .foregroundStyle(bubble.live ? .white : Palette.ink)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(bubble.live ? Palette.ink : Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .screenChrome("AI 분석")
        .task {
            guard !started else { return }
            started = true
            bob = true
            await run()
        }
    }

    private func run() async {
        let analysis = PhotoAnalysis.example
        try? await Task.sleep(for: .milliseconds(1400))
        withAnimation {
            bubbles = [Bubble(text: "메뉴판 읽기 완료"), Bubble(text: "주방 사진 읽는 중", live: true)]
        }
        try? await Task.sleep(for: .milliseconds(1000))
        let lines = summary(analysis)
        for count in 1...lines.count {
            withAnimation { bubbles = lines.prefix(count).map { Bubble(text: $0) } }
            try? await Task.sleep(for: .milliseconds(550))
        }
        try? await Task.sleep(for: .milliseconds(500))
        guard model.path.last == .analyzing else { return }
        model.applyAnalysis(analysis)
        model.path.removeLast()
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
