import SwiftUI
import WebKit

struct PostcodeSheet: View {
    let onPick: (PickedLocation) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var failed = false

    var body: some View {
        NavigationStack {
            Group {
                if failed {
                    ContentUnavailableView(
                        "주소 검색을 불러오지 못했어요",
                        systemImage: "wifi.exclamationmark",
                        description: Text("잠시 뒤 다시 시도해 주세요.")
                    )
                } else {
                    PostcodeWebView { location in
                        onPick(location)
                        dismiss()
                    } onFail: {
                        failed = true
                    }
                    .ignoresSafeArea(edges: .bottom)
                }
            }
            .navigationTitle("가게 주소 찾기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }
}

private struct PostcodeWebView: UIViewRepresentable {
    let onPick: (PickedLocation) -> Void
    let onFail: () -> Void

    private static let html = """
    <!doctype html>
    <html lang="ko">
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
    <style>html, body, #wrap { margin: 0; width: 100%; height: 100%; }</style>
    </head>
    <body>
    <div id="wrap"></div>
    <script src="https://t1.daumcdn.net/mapjsapi/bundle/postcode/prod/postcode.v2.js"
            onerror="window.webkit.messageHandlers.postcode.postMessage({ failed: true })"></script>
    <script>
      new daum.Postcode({
        width: '100%',
        height: '100%',
        oncomplete: function (data) {
          window.webkit.messageHandlers.postcode.postMessage({
            sido: data.sido,
            sigungu: data.sigungu,
            address: data.roadAddress || data.jibunAddress
          });
        }
      }).embed(document.getElementById('wrap'));
    </script>
    </body>
    </html>
    """

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onFail: onFail)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(context.coordinator, name: "postcode")
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.loadHTMLString(Self.html, baseURL: URL(string: "https://localhost"))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "postcode")
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        let onPick: (PickedLocation) -> Void
        let onFail: () -> Void

        init(onPick: @escaping (PickedLocation) -> Void, onFail: @escaping () -> Void) {
            self.onPick = onPick
            self.onFail = onFail
        }

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any] else { return }
            if body["failed"] != nil {
                onFail()
                return
            }
            let sido = body["sido"] as? String ?? ""
            let sigungu = body["sigungu"] as? String ?? ""
            let address = body["address"] as? String ?? ""
            onPick(PickedLocation(sido: sido, sigungu: sigungu, address: address))
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            onFail()
        }
    }
}
