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

        // ===============================
        // Chart
        // ===============================
        const chart = LightweightCharts.createChart(container, {
            width: w,
            height: h,
            layout: {
                background: {
                type: "solid",
                color: "#111"   
                },
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
        // Candlestick Series（v4）
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
        // Data Fetch
        // ===============================
        fetch("https://harukitech.site/candles?limit=200")
            .then(res => {
                if (!res.ok) {
                    throw new Error("HTTP " + res.status);
                }
                return res.json();
            })
            .then(data => {

                let currentTrade = null;
                const exitMarkers = [];

                // ===============================
                // Candles
                // ===============================
                const candles = data.map(d => ({
                    time: Math.floor(new Date(d.time).getTime() / 1000), // ← 統一
                    open: d.open,
                    high: d.high,
                    low: d.low,
                    close: d.close
                }));

                series.setData(candles);

                data.forEach(d => {
                    const time = Math.floor(new Date(d.time).getTime() / 1000);

                    // ========= ENTRY =========
                    if (!currentTrade && (d.direction === "LONG" || d.direction === "SHORT")) {
                        currentTrade = {
                            direction: d.direction,
                            entryTime: time,
                            entryPrice: d.close
                        };
                    }

                    // ========= EXIT =========
                    if (currentTrade && d.exit === 1) {
                        const exitPrice = d.close;

                        const lineSeries = chart.addLineSeries({
                            color: "#888",
                            lineWidth: 2,
                            lineStyle: LightweightCharts.LineStyle.Dashed,
                            priceLineVisible: false,
                            lastValueVisible: false,
                        });

                        lineSeries.setData([
                            { time: currentTrade.entryTime, value: currentTrade.entryPrice },
                            { time: time, value: exitPrice }
                        ]);

                        const isProfit =
                            (currentTrade.direction === "LONG" && exitPrice > currentTrade.entryPrice) ||
                            (currentTrade.direction === "SHORT" && exitPrice < currentTrade.entryPrice);

                        let shape;
                        let position;

                        if (currentTrade.direction === "LONG") {
                            shape = isProfit ? "arrowUp" : "arrowDown";
                            position = isProfit ? "aboveBar" : "belowBar";
                        } else {
                            shape = isProfit ? "arrowDown" : "arrowUp";
                            position = isProfit ? "belowBar" : "aboveBar";
                        }

                        exitMarkers.push({
                            time: time,
                            position: position,
                            color: isProfit ? "#4caf50" : "#ff5252",
                            shape: shape,
                            text: isProfit ? "TP" : "SL"
                        });

                        currentTrade = null;
                    }
                });

                // ===============================
                // Entry Markers
                // ===============================
                const markers = data
                    .filter(d => d.direction === "LONG" || d.direction === "SHORT")
                    .map(d => ({
                        time: Math.floor(new Date(d.time).getTime() / 1000),
                        position: d.direction === "LONG" ? "belowBar" : "aboveBar",
                        color: d.direction === "LONG" ? "#26a69a" : "#ef5350",
                        shape: d.direction === "LONG" ? "arrowUp" : "arrowDown",
                        text: d.direction
                    }));

                series.setMarkers(markers.concat(exitMarkers));

                chart.timeScale().fitContent();

                window.webkit.messageHandlers.jsHandler.postMessage(
                    "Chart rendered. candles=" + candles.length +
                    " markers=" + markers.length
                );
            })
            .catch(err => {
                window.webkit.messageHandlers.jsHandler.postMessage(
                    "❌ fetch error: " + err.message
                );
            });
    })();
    """
}
