import SwiftUI

struct AlertAction: Identifiable {
    enum Style {
        case action
        case muted
        case outline
    }

    var id: String { title }
    let title: String
    var style: Style = .action
    let handler: () -> Void
}

private struct AlertCard: View {
    let title: String
    let message: String
    let actions: [AlertAction]
    let close: (@escaping () -> Void) -> Void

    @State private var shown = false

    var body: some View {
        ZStack {
            Color(red: 18 / 255, green: 18 / 255, blue: 18 / 255)
                .opacity(shown ? 0.48 : 0)
                .ignoresSafeArea()
            if shown {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(Palette.ink)
                        Text(message)
                            .font(.system(size: 15))
                            .foregroundStyle(Palette.sub)
                            .lineSpacing(4)
                    }
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    HStack(spacing: 8) {
                        ForEach(actions) { action in
                            Button {
                                close(action.handler)
                            } label: {
                                Text(action.title)
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(foreground(action.style))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                    .frame(maxWidth: .infinity, minHeight: 56)
                                    .background(background(action.style), in: Capsule())
                                    .overlay {
                                        if action.style == .outline {
                                            Capsule().stroke(Color(white: 0.79), lineWidth: 1)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.top, 32)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .frame(maxWidth: 312)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255).opacity(0.14), radius: 10, y: 12)
                .padding(.horizontal, 44)
                .transition(.scale(scale: 0.94).combined(with: .opacity))
            }
        }
        .onAppear {
            withAnimation(.snappy(duration: 0.2)) { shown = true }
        }
    }

    private func foreground(_ style: AlertAction.Style) -> Color {
        style == .action ? .white : Palette.ink
    }

    private func background(_ style: AlertAction.Style) -> Color {
        switch style {
        case .action: Color(red: 225 / 255, green: 77 / 255, blue: 0)
        case .muted: Palette.canvas
        case .outline: .white
        }
    }
}

private struct AlertPresenter: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let message: String
    let actions: [AlertAction]

    func body(content: Content) -> some View {
        content.fullScreenCover(isPresented: $isPresented) {
            AlertCard(title: title, message: message, actions: actions) { handler in
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { isPresented = false }
                DispatchQueue.main.async(execute: handler)
            }
            .presentationBackground(.clear)
        }
        .transaction { transaction in
            if transaction.animation == nil || isPresented {
                transaction.disablesAnimations = true
            }
        }
    }
}

struct ToastView: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Palette.good, in: Circle())
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(red: 43 / 255, green: 43 / 255, blue: 43 / 255), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
        .allowsHitTesting(false)
    }
}

extension View {
    func alertCard(_ title: String, isPresented: Binding<Bool>, message: String, actions: [AlertAction]) -> some View {
        modifier(AlertPresenter(isPresented: isPresented, title: title, message: message, actions: actions))
    }
}
