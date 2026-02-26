import SwiftUI

struct ContentView: View {

    @State private var refreshTrigger = false
    @State private var isLoading = false
    @State private var lastUpdated = Date()
    
    var body: some View {

        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {

                headerView

                ChartView(refreshTrigger: $refreshTrigger)
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
                Text("FX Forecast")
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

            HStack {
                Text("Last Update:")
                    .foregroundColor(.gray)

                Text(lastUpdated.formatted(date: .omitted, time: .standard))
                    .foregroundColor(.green)

                Spacer()
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
