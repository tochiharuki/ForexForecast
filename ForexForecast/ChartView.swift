import SwiftUI
import WebKit

struct ChartView: UIViewRepresentable {

    @Binding var reloadTrigger: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {

        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.userContentController.add(context.coordinator, name: "jsHandler")

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

        webView.loadHTMLString(html, baseURL: URL(string: "https://harukitech.site"))
        context.coordinator.webView = webView

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if reloadTrigger {
            uiView.reload()
            DispatchQueue.main.async {
                reloadTrigger = false
            }
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {

        var parent: ChartView
        weak var webView: WKWebView?

        init(_ parent: ChartView) {
            self.parent = parent
        }

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
                background: #0D0F14;
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

    static let chartJS = """
    (function () {

        if (typeof LightweightCharts === "undefined") {
            return;
        }

        const container = document.getElementById("chart");

        const chart = LightweightCharts.createChart(container, {
            width: container.clientWidth,
            height: container.clientHeight,
            layout: {
                background: { type: "solid", color: "#0D0F14" },
                textColor: "#C9D1D9"
            },
            grid: {
                vertLines: { color: "#1F2937" },
                horzLines: { color: "#1F2937" }
            },
        });

        const series = chart.addCandlestickSeries({
            upColor: "#00C896",
            downColor: "#FF4C4C",
            borderUpColor: "#00C896",
            borderDownColor: "#FF4C4C",
            wickUpColor: "#00C896",
            wickDownColor: "#FF4C4C"
        });

        fetch("https://harukitech.site/candles?limit=200")
            .then(res => res.json())
            .then(data => {

                data.sort((a, b) => new Date(a.time) - new Date(b.time));

                const candles = data.map(d => ({
                    time: Math.floor(new Date(d.time).getTime() / 1000),
                    open: d.open,
                    high: d.high,
                    low: d.low,
                    close: d.close
                }));

                series.setData(candles);
                chart.timeScale().fitContent();
            });

    })();
    """
}