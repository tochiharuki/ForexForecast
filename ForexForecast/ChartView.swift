import SwiftUI
import WebKit

struct ChartView: UIViewRepresentable {

    func makeUIView(context: Context) -> WKWebView {
        print("makeUIView start")
    
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptEnabled = true
        config.defaultWebpagePreferences.allowsContentJavaScript = true
    
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
    
        if let jsURL = Bundle.main.url(forResource: "lightweight-charts", withExtension: "js") {
            print("JS file found at \(jsURL)")
            webView.loadHTMLString(html, baseURL: jsURL.deletingLastPathComponent())
        } else {
            print("JS file not found, loading HTML only")
            webView.loadHTMLString(html, baseURL: nil)
        }
    
        print("makeUIView end")
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    private let html = """
    <!DOCTYPE html>
    <html>
    <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
            body { margin: 0; background-color: #111; }
            #chart { width: 100vw; height: 100vh; }
        </style>
    </head>
    <body>
        <div id="chart"></div>

        <script>
        console.log("HTML loaded");
        </script>

        <script src="lightweight-charts.js"></script>

        <script>
            console.log("JS start");

            const chart = LightweightCharts.createChart(
                document.getElementById('chart'),
                {
                    layout: {
                        background: { color: '#111' },
                        textColor: '#DDD',
                    }
                }
            );

            const series = chart.addCandlestickSeries();

            series.setData([
                { time: '2024-01-01', open: 140.2, high: 140.8, low: 139.9, close: 140.5 },
                { time: '2024-01-02', open: 140.5, high: 141.0, low: 140.2, close: 140.9 },
                { time: '2024-01-03', open: 140.9, high: 141.2, low: 140.4, close: 140.6 }
            ]);

            console.log("Chart rendered");
        </script>
    </body>
    </html>
    """
}