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

        webView.loadHTMLString(
            html,
            baseURL: URL(string: "https://harukitech.site")
        )
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
    (function () {

        window.webkit.messageHandlers.jsHandler.postMessage("JS start");

        if (typeof LightweightCharts === "undefined") {
            window.webkit.messageHandlers.jsHandler.postMessage("❌ LightweightCharts undefined");
            return;
        }

        const container = document.getElementById("chart");
        const w = container.clientWidth;
        const h = container.clientHeight;

        const chart = LightweightCharts.createChart(container, {
            width: w,
            height: h,
            layout: {
                background: { color: "#111" },
                textColor: "#DDD"
            }
        });

        const series = chart.addSeries(LightweightCharts.CandlestickSeries);

        fetch("https://harukitech.site/candles?limit=200")
            .then(res => res.json())
            .then(data => {

                const candles = data.map(d => ({
                    time: Math.floor(new Date(d.time).getTime() / 1000),
                    open: d.open,
                    high: d.high,
                    low: d.low,
                    close: d.close
                }));

                series.setData(candles);
                chart.timeScale().fitContent();

                window.webkit.messageHandlers.jsHandler.postMessage("Chart rendered");
            })
            .catch(err => {
                window.webkit.messageHandlers.jsHandler.postMessage("❌ fetch error: " + err);
            });

    })();
    """
}
