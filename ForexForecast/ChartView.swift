import SwiftUI
import WebKit

struct ChartView: UIViewRepresentable {
    @Binding var refreshTrigger: Bool

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

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // JavaScript 関数を呼んでデータのみ更新
        guard refreshTrigger else { return }

        uiView.evaluateJavaScript("(function(){ if(typeof updateChartData==='function'){ updateChartData(); }})();")

        DispatchQueue.main.async {
            refreshTrigger = false
        }
    }

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
        const container = document.getElementById("chart");

        if (typeof LightweightCharts === "undefined") {
            window.webkit.messageHandlers.jsHandler.postMessage("❌ LightweightCharts undefined");
            return;
        }

        const w = container.clientWidth;
        const h = container.clientHeight;

        // ===============================
        // Chart
        // ===============================
        const chart = LightweightCharts.createChart(container, {
            width: w,
            height: h,
            layout: {
                background: { type: "solid", color: "#111" },
                textColor: "#DDD"
            },
            grid: {
                vertLines: { color: "#222" },
                horzLines: { color: "#222" }
            },
            timeScale: {
                timeVisible: true,
                secondsVisible: false
            },
            rightPriceScale: {
                borderColor: "#444"
            },
            crosshair: {
                mode: LightweightCharts.CrosshairMode.Normal
            }
        });

        // ===============================
        // Candlestick Series
        // ===============================
        const series = chart.addCandlestickSeries({
            upColor: "#26a69a",
            downColor: "#ef5350",
            borderUpColor: "#26a69a",
            borderDownColor: "#ef5350",
            wickUpColor: "#26a69a",
            wickDownColor: "#ef5350"
        });

        // ===============================
        // Data Fetch (exposed)
        // ===============================
        function updateChartData() {
            fetch("https://harukitech.site/candles?limit=200")
                .then(res => {
                    if (!res.ok) throw new Error("HTTP " + res.status);
                    return res.json();
                })
                .then(data => {
                    data.sort((a, b) => new Date(a.time) - new Date(b.time));
                    // -------------------------------
                    // Candles
                    // -------------------------------
                    const candles = data.map(d => ({
                        time: Math.floor(new Date(d.time).getTime() / 1000),
                        open: d.open,
                        high: d.high,
                        low: d.low,
                        close: d.close
                    }));

                    series.setData(candles);

                    let currentTrade = null;
                    const entryMarkers = [];
                    const exitMarkers = [];

                    data.forEach(d => {
                        const time = Math.floor(new Date(d.time).getTime() / 1000);

                        // ===============================
                        // ENTRY marker（シグナル：全表示）
                        // ===============================
                        if (d.direction === "LONG" || d.direction === "SHORT") {
                            entryMarkers.push({
                                time,
                                position: d.direction === "LONG" ? "belowBar" : "aboveBar",
                                color: d.direction === "LONG" ? "#26a69a" : "#ef5350",
                                shape: d.direction === "LONG" ? "arrowUp" : "arrowDown",
                                text: d.direction
                            });

                            if (!currentTrade) {
                                currentTrade = {
                                    direction: d.direction,
                                    entryTime: time,
                                    entryPrice: d.close
                                };
                            }
                        }

                        // ===============================
                        // EXIT
                        // ===============================
                        if (currentTrade && d.exit === 1) {
                            const exitPrice = d.close;

                            // --- trade line ---
                            const lineSeries = chart.addLineSeries({
                                color: "#888",
                                lineWidth: 2,
                                lineStyle: LightweightCharts.LineStyle.Dashed,
                                priceLineVisible: false,
                                lastValueVisible: false,
                            });

                            lineSeries.setData([
                                { time: currentTrade.entryTime, value: currentTrade.entryPrice },
                                { time, value: exitPrice }
                            ]);

                            const isProfit =
                                (currentTrade.direction === "LONG" && exitPrice > currentTrade.entryPrice) ||
                                (currentTrade.direction === "SHORT" && exitPrice < currentTrade.entryPrice);

                            exitMarkers.push({
                                time,
                                position: isProfit
                                    ? (currentTrade.direction === "LONG" ? "aboveBar" : "belowBar")
                                    : (currentTrade.direction === "LONG" ? "belowBar" : "aboveBar"),
                                color: isProfit ? "#4caf50" : "#ff5252",
                                shape: isProfit ? "arrowUp" : "arrowDown",
                                text: isProfit ? "TP" : "SL"
                            });

                            currentTrade = null;
                        }
                    });

                    // ===============================
                    // APPLY MARKERS（重要）
                    // ===============================
                    series.setMarkers([
                        ...entryMarkers,
                        ...exitMarkers
                    ]);

                    chart.timeScale().fitContent();

                    window.webkit.messageHandlers.jsHandler.postMessage(
                        "Chart rendered candles=" + candles.length +
                        " entry=" + entryMarkers.length +
                        " exit=" + exitMarkers.length
                    );
                })
                .catch(err => {
                    window.webkit.messageHandlers.jsHandler.postMessage(
                        "❌ fetch error: " + err.message
                    );
                });
        }
        // expose function and run first time
        window.updateChartData = updateChartData;
        updateChartData();
    })();
    """
}
