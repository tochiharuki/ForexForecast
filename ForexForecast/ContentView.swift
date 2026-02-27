import SwiftUI

struct ContentView: View {

    @State private var refreshTrigger = false
    @State private var isLoading = false
    @State private var lastUpdated = Date()
    @State private var totalProfit: Int = 0
    @State private var tradeProfits: [Int] = []
    @State private var winRate: Double = 0.0
    
    private var averageProfit: Double {
        guard !tradeProfits.isEmpty else { return 0 }
        let sum = tradeProfits.reduce(0, +)
        return Double(sum) / Double(tradeProfits.count)
    }

    var body: some View {

        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {

                headerView

                ChartView(
                    refreshTrigger: $refreshTrigger,
                    totalProfit: $totalProfit,
                    tradeProfits: $tradeProfits,
                    winRate: $winRate
                )
                    // give the web view a non‑zero height so the chart can render
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay {
                        if isLoading {
                            ZStack {
                                Color.black.opacity(0.6)
                                ProgressView()
                                    .scaleEffect(1.4)
                                    .tint(.white)
                            }
                        }
                    }
            }
        }
        .onAppear {
            refresh()
        }
    }

    private var headerView: some View {
        VStack(spacing: 12) {

            HStack {
                Text("ForexForecast")
                    .font(.title2.bold())
                    .foregroundColor(.white)

                Spacer()

                Button {
                    refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.gray.opacity(0.25))
                        .clipShape(Circle())
                }
            }

            HStack(spacing: 12) {
                Text("Total Profit (20):")
                    .foregroundColor(.gray)
                Text(totalProfit.formatted())
                    .foregroundColor(totalProfit >= 0 ? .green : .red)
            
                Text("Avg:")
                    .foregroundColor(.gray)
                Text(averageProfit.formatted())
                    .foregroundColor(averageProfit >= 0 ? .green : .red)
            
                Text("Win Rate:")
                    .foregroundColor(.gray)
                Text(String(format: "%.1f%%", winRate))
                    .foregroundColor(.green)
            }
            .font(.caption)
        }
        .padding()
        .background(Color(red: 0.08, green: 0.1, blue: 0.15))
    }

    private func refresh() {
        isLoading = true
        refreshTrigger = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            lastUpdated = Date()
            isLoading = false
        }
    }
}

#Preview {
    ContentView()
}