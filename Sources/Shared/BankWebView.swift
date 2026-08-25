import SwiftUI
import UIKit
import WebKit

/// The whole app: a full-screen WKWebView on the live bank website, so iOS shows
/// exactly what the site shows and picks up every change without a new release.
///
/// One implementation, two banks. `BankSite` supplies the URL and the user-agent
/// suffix; nothing else differs, and keeping it that way means a fix to the
/// payment popup lands on both apps at once.
///
/// The parts that are not just "load a URL":
///
///  - **PayPal opens its checkout in a popup.** The obvious handling — load the
///    popup's URL into the same web view and return nil — is wrong twice over:
///    it throws away the page the customer was on, and it breaks `window.opener`,
///    which is the channel PayPal uses to hand the result back. So a REAL second
///    WKWebView is created and presented, which is what keeps the opener link
///    alive. The Android app had exactly this bug and the deposit button looked
///    dead. See `createWebViewWith` below.
///  - **The identity check opens the camera from inside the page.** Without
///    `requestMediaCapturePermissionFor` the face scan silently fails on iOS 15+.
///  - **A dropped connection** otherwise shows a Safari error page inside what is
///    meant to look like a bank. It shows our own page instead.
struct BankSite {
    let url: URL
    let userAgentSuffix: String
    let offlineTitle: String
    let offlineBody: String
    let offlineButton: String
    let offlineNote: String
    let tint: Color
}

struct BankWebView: UIViewRepresentable {

    let site: BankSite

    func makeCoordinator() -> Coordinator { Coordinator(site: site) }

    func makeUIView(context: Context) -> WKWebView {
        let webView = Self.makeWebView(site: site, coordinator: context.coordinator)
        context.coordinator.webView = webView

        let refresh = UIRefreshControl()
        refresh.addTarget(context.coordinator,
                          action: #selector(Coordinator.reload(_:)),
                          for: .valueChanged)
        webView.scrollView.refreshControl = refresh

        webView.load(URLRequest(url: site.url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    /// One place for the configuration.
    ///
    /// When WebKit hands us a configuration (the popup case) we adjust it and
    /// hand it straight back. We must NOT replace its `websiteDataStore`: that
    /// store is the shared cookie jar, and swapping it would sign the popup in
    /// as a different browser — the customer would arrive at PayPal logged out
    /// of the bank that opened it.
    ///
    /// The user agent is set through `applicationNameForUserAgent`, which is
    /// the public way to append to the real agent string. Reading "userAgent"
    /// off the web view by key path also works and is what most sample code
    /// does, but it is key-value coding against a private property.
    static func makeWebView(site: BankSite,
                            coordinator: Coordinator,
                            configuration: WKWebViewConfiguration? = nil) -> WKWebView {
        let ours = configuration == nil
        let config = configuration ?? WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.applicationNameForUserAgent = site.userAgentSuffix
        if ours {
            config.websiteDataStore = .default()   // keeps the login session
        }

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        webView.navigationDelegate = coordinator
        webView.uiDelegate = coordinator
        return webView
    }

    // MARK: -

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {

        let site: BankSite
        weak var webView: WKWebView?
        private var popupWebView: WKWebView?
        private weak var popupController: UIViewController?

        init(site: BankSite) { self.site = site }

        // ---------------------------------------------------------- payments

        /// PayPal checkout, and on Dessalines the debit/credit card form too,
        /// both arrive here as `window.open`.
        ///
        /// The returned web view must be built from the CONFIGURATION iOS hands
        /// us — not a fresh one — or the opener relationship is lost and the
        /// customer is left on a PayPal page that can never talk back to the
        /// deposit page.
        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {

            closePopup(animated: false)

            let popup = BankWebView.makeWebView(site: site,
                                                coordinator: self,
                                                configuration: configuration)
            popupWebView = popup

            let controller = UIViewController()
            controller.view = popup
            controller.modalPresentationStyle = .pageSheet
            popupController = controller

            topViewController()?.present(controller, animated: true)

            // Deliberately NOT loading the request here. When targetFrame is nil
            // WebKit loads it into the returned view itself; doing it by hand as
            // well opens the checkout twice.
            return popup
        }

        /// PayPal calls window.close() when the buyer finishes or cancels.
        func webViewDidClose(_ webView: WKWebView) {
            if webView === popupWebView { closePopup(animated: true) }
        }

        private func closePopup(animated: Bool) {
            popupWebView?.stopLoading()
            popupWebView = nil
            popupController?.dismiss(animated: animated)
            popupController = nil
        }

        private func topViewController() -> UIViewController? {
            let scene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }
            var top = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
            while let presented = top?.presentedViewController { top = presented }
            return top
        }

        // ------------------------------------------------------------ camera

        /// The identity check opens the camera from inside the page.
        @available(iOS 15.0, *)
        func webView(_ webView: WKWebView,
                     requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                     initiatedByFrame frame: WKFrameInfo,
                     type: WKMediaCaptureType,
                     decisionHandler: @escaping (WKPermissionDecision) -> Void) {
            decisionHandler(.prompt)
        }

        // ------------------------------------------------------------- pages

        /// Keep the bank and the payment redirects inside the app; hand tel:,
        /// mailto: and the wallet schemes to the system.
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url,
               let scheme = url.scheme?.lowercased(),
               scheme != "http", scheme != "https", scheme != "about" {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.scrollView.refreshControl?.endRefreshing()
        }

        func webView(_ webView: WKWebView,
                     didFail navigation: WKNavigation!,
                     withError error: Error) {
            showOffline(in: webView, error: error)
        }

        func webView(_ webView: WKWebView,
                     didFailProvisionalNavigation navigation: WKNavigation!,
                     withError error: Error) {
            showOffline(in: webView, error: error)
        }

        /// Only a genuine connection failure becomes the offline screen. A
        /// cancelled navigation is what every ordinary tap looks like mid-flight,
        /// and replacing the page then would throw a customer out of a transfer
        /// they were halfway through confirming.
        private func showOffline(in webView: WKWebView, error: Error) {
            webView.scrollView.refreshControl?.endRefreshing()
            let ns = error as NSError
            guard ns.domain == NSURLErrorDomain, ns.code != NSURLErrorCancelled else { return }
            if webView === popupWebView { return }
            webView.loadHTMLString(offlineHTML(), baseURL: site.url)
        }

        private func offlineHTML() -> String {
            """
            <!DOCTYPE html><html><head><meta charset="utf-8">
            <meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
            <style>
              html,body{margin:0;height:100%}
              body{background:#0f1115;color:#fff;display:flex;align-items:center;
                   justify-content:center;padding:24px;box-sizing:border-box;
                   font-family:-apple-system,system-ui,sans-serif}
              .card{background:rgba(255,255,255,.05);border:1px solid rgba(255,255,255,.10);
                    border-radius:18px;padding:32px 26px;max-width:340px;width:100%;text-align:center}
              h1{font-size:1.15rem;margin:0 0 10px}
              p{font-size:.95rem;line-height:1.55;color:#9aa;margin:0 0 22px}
              a{display:block;background:#e63946;color:#fff;text-decoration:none;padding:14px 18px;
                border-radius:12px;font-weight:700}
              .n{margin:18px 0 0;font-size:.8rem;color:#667}
            </style></head><body><div class="card">
            <h1>\(site.offlineTitle)</h1><p>\(site.offlineBody)</p>
            <a href="\(site.url.absoluteString)">\(site.offlineButton)</a>
            <p class="n">\(site.offlineNote)</p>
            </div></body></html>
            """
        }

        @objc func reload(_ sender: UIRefreshControl) {
            guard let webView else { sender.endRefreshing(); return }
            if webView.url == nil || webView.url?.scheme == nil {
                webView.load(URLRequest(url: site.url))
            } else {
                webView.reload()
            }
        }
    }
}

/// The screen itself. `ignoresSafeArea(.keyboard)` is deliberate: without it the
/// whole page jumps when the PIN keypad opens.
struct BankScreen: View {
    let site: BankSite

    var body: some View {
        BankWebView(site: site)
            .ignoresSafeArea(edges: .bottom)
            .ignoresSafeArea(.keyboard)
            .tint(site.tint)
    }
}
