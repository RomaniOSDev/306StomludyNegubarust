//
//  WebDocumentSurfaceView.swift
//

import SwiftUI
import WebKit

struct WebDocumentSurfaceView: View {
    let url: URL
    var onFailure: () -> Void

    @State private var webView: WKWebView?
    @State private var canGoBack = false
    @State private var isLoading = true

    private let chromeTint = Color(red: 0.20, green: 0.16, blue: 0.42)

    var body: some View {
        ZStack {
            Color(red: 0.97, green: 0.96, blue: 0.99).ignoresSafeArea()

            VStack(spacing: 0) {
                WebDocumentHostRepresentable(
                    url: url,
                    webView: $webView,
                    canGoBack: $canGoBack,
                    isLoading: $isLoading,
                    onFailure: onFailure
                )

                Divider()
                    .overlay(Color.black.opacity(0.08))

                HStack(spacing: 36) {
                    Button {
                        webView?.goBack()
                    } label: {
                        Image(systemName: "arrow.backward")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(canGoBack ? chromeTint : Color.gray.opacity(0.4))
                            .frame(width: 44, height: 44)
                    }
                    .disabled(!(canGoBack))

                    Button {
                        webView?.reload()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(chromeTint)
                            .frame(width: 44, height: 44)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(.ultraThinMaterial)
            }

            if isLoading {
                ZStack {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: chromeTint))
                        .scaleEffect(1.8)
                }
            }
        }
        .persistentSystemOverlays(.hidden)
    }
}

// MARK: - UIViewRepresentable

struct WebDocumentHostRepresentable: UIViewRepresentable {
    let url: URL
    @Binding var webView: WKWebView?
    @Binding var canGoBack: Bool
    @Binding var isLoading: Bool
    var onFailure: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        view.scrollView.contentInsetAdjustmentBehavior = .never
        view.backgroundColor = UIColor(white: 0.98, alpha: 1)
        view.isOpaque = false
        view.allowsBackForwardNavigationGestures = true
        context.coordinator.attach(webView: view)
        view.load(URLRequest(url: url))
        DispatchQueue.main.async {
            webView = view
        }
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.parent = self
        canGoBack = uiView.canGoBack
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: WebDocumentHostRepresentable
        private weak var attachedWebView: WKWebView?
        private var failureCalled = false

        init(parent: WebDocumentHostRepresentable) {
            self.parent = parent
        }

        func attach(webView: WKWebView) {
            attachedWebView = webView
        }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            if let httpResponse = navigationResponse.response as? HTTPURLResponse {
                print("[LaunchFlow] Server response code: \(httpResponse.statusCode)")
                if LaunchSessionStore.shared.savedLastURL == nil && !failureCalled {
                    if (400...599).contains(httpResponse.statusCode) {
                        failureCalled = true
                        LaunchSessionStore.shared.hasShownNativeShell = true
                        decisionHandler(.cancel)
                        DispatchQueue.main.async { self.parent.onFailure() }
                        return
                    }
                }
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url,
               ["mailto", "tel", "sms"].contains(url.scheme) {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                }
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.canGoBack = webView.canGoBack
            parent.isLoading = false
            if LaunchSessionStore.shared.savedLastURL == nil, let current = webView.url {
                LaunchSessionStore.shared.savedLastURL = current
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            triggerFailureIfNeeded()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            if LaunchSessionStore.shared.savedLastURL == nil {
                triggerFailureIfNeeded()
            }
        }

        private func triggerFailureIfNeeded() {
            guard LaunchSessionStore.shared.savedLastURL == nil, !failureCalled else { return }
            failureCalled = true
            LaunchSessionStore.shared.hasShownNativeShell = true
            DispatchQueue.main.async { self.parent.onFailure() }
        }
    }
}
