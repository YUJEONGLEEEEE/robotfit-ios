import SwiftUI
import UIKit

enum Palette {
    static let good = Color(red: 0.184, green: 0.420, blue: 1.0)
    static let warn = Color(red: 0.902, green: 0.467, blue: 0.0)
    static let bad = Color(red: 0.898, green: 0.216, blue: 0.169)
    static let check = Color.secondary
    static let assumed = Color(red: 0.702, green: 0.494, blue: 0.0)

    static func verdict(_ verdict: Verdict) -> Color {
        switch verdict {
        case .recommend: good
        case .conditional: warn
        case .check: check
        case .notRecommended: bad
        }
    }
}

struct Card<Content: View>: View {
    var padding: CGFloat = 20
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(padding)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct Headline: View {
    let title: String
    var sub: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title2.bold())
            if let sub {
                Text(sub)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
    }
}

struct AssumedTag: View {
    var text = "가정값"

    var body: some View {
        Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(Palette.assumed)
            .background(Palette.assumed.opacity(0.14), in: RoundedRectangle(cornerRadius: 6))
    }
}

struct VerdictBadge: View {
    let verdict: Verdict
    let text: String
    var large = false

    var body: some View {
        Text(text)
            .font(large ? .subheadline.bold() : .caption.bold())
            .padding(.horizontal, large ? 12 : 8)
            .padding(.vertical, large ? 8 : 4)
            .foregroundStyle(Palette.verdict(verdict))
            .background(Palette.verdict(verdict).opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct Steps: View {
    let current: Int
    private let labels = ["주방 사진", "메뉴판", "가게 정보"]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                let done = index + 1 <= current
                VStack(alignment: .leading, spacing: 6) {
                    Capsule()
                        .fill(done ? Color.primary : Color(.systemGray5))
                        .frame(height: 4)
                    Text("\(index + 1) \(label)")
                        .font(.caption.weight(done ? .semibold : .regular))
                        .foregroundStyle(done ? .primary : .secondary)
                }
            }
        }
        .padding(.horizontal, 4)
    }
}

struct LineRow: View {
    let label: String
    let value: String
    var strong = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .fontWeight(strong ? .bold : .semibold)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
        .padding(.vertical, 8)
    }
}

struct Formula: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            .padding(.bottom, 6)
    }
}

struct IconTile: View {
    let systemName: String
    var tint: Color = .accentColor

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 36, height: 36)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct PrimaryButton: View {
    let title: String
    var style: Style = .primary
    let action: () -> Void

    enum Style {
        case primary
        case secondary
        case ghost
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 52)
        }
        .foregroundStyle(style == .primary ? Color(.systemBackground) : .primary)
        .background {
            switch style {
            case .primary: RoundedRectangle(cornerRadius: 16).fill(Color.primary)
            case .secondary: RoundedRectangle(cornerRadius: 16).fill(Color(.systemGray5))
            case .ghost: Color.clear
            }
        }
    }
}

struct FooterButtons<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 8) {
            content
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(.bar)
    }
}

struct DisclosureCard<Content: View>: View {
    let title: String
    var systemImage: String?
    var tint: Color = .accentColor
    var assumed = false
    @State var expanded = false
    @ViewBuilder let content: Content

    var body: some View {
        Card {
            Button {
                withAnimation(.snappy) { expanded.toggle() }
            } label: {
                HStack(spacing: 10) {
                    if let systemImage {
                        IconTile(systemName: systemImage, tint: tint)
                    }
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if assumed { AssumedTag() }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
            }
            .buttonStyle(.plain)
            if expanded {
                VStack(alignment: .leading, spacing: 0) {
                    content
                }
                .padding(.top, 12)
            }
        }
    }
}

struct Note: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            .padding(.top, 4)
    }
}
