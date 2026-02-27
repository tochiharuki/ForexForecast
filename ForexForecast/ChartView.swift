import SwiftUI
import WebKit

struct ChartView: UIViewRepresentable {
    @Binding var refreshTrigger: Bool
    @Binding var totalProfit: Int
    @Binding var tradeProfits: [Int]  // ← ContentView の配列をバインディングで渡す
    @Binding var winRate: Double       // 勝率（0〜100）
    

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
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
    
        var parent: ChartView
        init(parent: ChartView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript(ChartView.chartJS)
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            // ここで損益サマリを受け取る
            if let dict = message.body as? [String: Any],
               dict["type"] as? String == "profitSummary" {
            
                let total = dict["totalProfit"] as? Int ?? 0
                let trades = dict["tradeProfits"] as? [Int] ?? []
                let win = dict["winRate"] as? Double ?? 0.0
            
                DispatchQueue.main.async {
                    self.parent.totalProfit = total
                    self.parent.tradeProfits = trades
                    self.parent.winRate = win
                }
                return
            }

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
        window.tradeLines = [];
        const chart = LightweightCharts.createChart(container, {
            width: w,
            height: h - 30,
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

            // 既存ライン削除（重要）
            if (window.tradeLines && window.tradeLines.length > 0) {
                window.tradeLines.forEach(line => chart.removeSeries(line));
                window.tradeLines = [];
            }
            fetch("https://harukitech.site/candles?limit=960")
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
                            window.tradeLines.push(lineSeries);

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
                                color: isProfit ? "#4caf50" : "#5255ff",
                                shape: isProfit ? "arrowUp" : "arrowDown",
                                text: isProfit ? "TP" : "SL"
                            });

                            currentTrade = null;
                        }
                    });

                    // ===============================
                    // APPLY MARKERS（完全版）
                    // ===============================
                    const allMarkers = [
                        ...entryMarkers,
                        ...exitMarkers
                    ].sort((a, b) => a.time - b.time);

                    series.setMarkers(allMarkers);

                    chart.timeScale().scrollToRealTime();
                    let totalProfit = 0;
                    let tradeProfits = [];
                    let wins = 0;
                    
                    exitMarkers.forEach(marker => {
                        let profit = marker.text === "TP" ? 60000 : -30000;
                        totalProfit += profit;
                        tradeProfits.push(profit);
                        if (profit > 0) wins += 1;
                    });
                    
                    let winRate = exitMarkers.length > 0 ? (wins / exitMarkers.length) * 100 : 0;
                    
                    window.webkit.messageHandlers.jsHandler.postMessage({
                        type: "profitSummary",
                        totalProfit: totalProfit,
                        tradeProfits: tradeProfits,
                        winRate: winRate
                    });

                    // ログ
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