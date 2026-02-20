import SwiftUI

struct ContentView: View {

    @State private var reloadTrigger = false
    @State private var isLoading = false
    @State private var lastUpdated = Date()

    var body: some View {

        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {

                // ===== Header =====
                headerView

                // ===== Chart =====
                ChartView(reloadTrigger: $reloadTrigger)
                    .overlay {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                        }
                    }
            }
        }
        .onAppear {
            refresh()
        }
        .refreshable {
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
                        .background(Color.gray.opacity(0.3))
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
        .background(Color(#colorLiteral(red: 0.08, green: 0.1, blue: 0.15, alpha: 1)))
    }

    private func refresh() {
        isLoading = true
        reloadTrigger = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            lastUpdated = Date()
            isLoading = false
        }
    }
}

#Preview {
    ContentView()
}