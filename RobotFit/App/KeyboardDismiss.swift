import SwiftUI
import UIKit

@objc(KeyboardDismissDelegate)
final class KeyboardDismissDelegate: NSObject, UIGestureRecognizerDelegate {
    static let shared = KeyboardDismissDelegate()

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var view = touch.view
        while let current = view {
            if current is UITextField || current is UITextView { return false }
            view = current.superview
        }
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
    }
}

private struct KeyboardDismissInstaller: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        DispatchQueue.main.async {
            guard let window = view.window,
                  !(window.gestureRecognizers ?? []).contains(where: { $0.name == "keyboardDismiss" }) else { return }
            let tap = UITapGestureRecognizer(target: window, action: #selector(UIView.endEditing(_:)))
            tap.name = "keyboardDismiss"
            tap.cancelsTouchesInView = false
            tap.delegate = KeyboardDismissDelegate.shared
            window.addGestureRecognizer(tap)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

extension View {
    func dismissesKeyboardOnTap() -> some View {
        background(KeyboardDismissInstaller())
    }
}
