import SwiftUI

struct StatusView: View {
    @ObservedObject var tunnel: TunnelManager

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: tunnel.isConnected ? "checkmark.shield.fill" : "shield.slash")
                    .font(.system(size: 80))
                    .foregroundStyle(tunnel.isConnected ? Color.green : Color.secondary)
                Text(tunnel.status).font(.title2)
                Button {
                    tunnel.toggle()
                } label: {
                    Text(tunnel.isConnected ? "Отключить" : "Включить")
                        .frame(maxWidth: .infinity).padding()
                        .background(tunnel.isConnected ? Color.red : Color.blue)
                        .foregroundStyle(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 32)
                if let err = tunnel.error {
                    Text(err).foregroundStyle(Color.red).font(.caption).padding(.horizontal)
                }
                Spacer()
            }
            .navigationTitle("M1DPI")
        }
    }
}
