import SwiftUI
import WebKit

struct ChartView: UIViewRepresentable {

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {

        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.userContentController.add(context.coordinator, name: "jsHandler")

        // lightweight-charts 注入
        if let jsURL = Bundle.main.url(forResource: "lightweight-charts", withExtension: "js"),
           let js = try? String(contentsOf: jsURL, encoding: .utf8) {

            let libScript = WKUserScript(
                source: js,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
            config.userContentController.addUserScript(libScript)
        }

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.backgroundColor = .black
        webView.isOpaque = false

        webView.loadHTMLString(html, baseURL: nil)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    // ===============================
    // Coordinator
    // ===============================
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript(ChartView.chartJS)
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            print("JS:", message.body)
        }
    }

    // ===============================
    // HTML
    // ===============================
    private let html = """
    <!DOCTYPE html>
    <html>
    <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
            html, body {
                margin: 0;
                width: 100%;
                height: 100%;
                background: #111;
            }
            #chart {
                width: 100%;
                height: 100%;
            }
        </style>
    </head>
    <body>
        <div id="chart"></div>
    </body>
    </html>
    """

    // ===============================
    // JS（最重要）
    // ===============================
    static let chartJS = """
    (function() {

        window.webkit.messageHandlers.jsHandler.postMessage("JS start");

        if (typeof LightweightCharts === "undefined") {
            window.webkit.messageHandlers.jsHandler.postMessage("❌ LightweightCharts undefined");
            return;
        }

        try {

            const container = document.getElementById("chart");
            const w = container.clientWidth;
            const h = container.clientHeight;

            window.webkit.messageHandlers.jsHandler.postMessage(
                "container size: " + w + "x" + h
            );

            // ★ 視覚確認用（これが見えればDOM描画は生きている）
            container.style.border = "2px solid red";

            const chart = LightweightCharts.createChart(container, {
                width: w,
                height: h,
                layout: {
                    background: { color: "#111" },
                    textColor: "#DDD"
                }
            });

            window.webkit.messageHandlers.jsHandler.postMessage("chart created");

            const series = chart.addSeries(LightweightCharts.CandlestickSeries);
            window.webkit.messageHandlers.jsHandler.postMessage("series added");

            series.setData([
                { time: "2024-01-01", open: 140.2, high: 140.8, low: 139.9, close: 140.5 },
                { time: "2024-01-02", open: 140.5, high: 141.0, low: 140.2, close: 140.9 },
                { time: "2024-01-03", open: 140.9, high: 141.2, low: 140.4, close: 140.6 }
            ]);

            window.webkit.messageHandlers.jsHandler.postMessage("data set");

            chart.timeScale().fitContent();
            window.webkit.messageHandlers.jsHandler.postMessage("Chart rendered");

        } catch (e) {
            window.webkit.messageHandlers.jsHandler.postMessage(
                "❌ JS Error: " + e.message
            );
        }

    })();
    """
}