import SwiftUI

struct ContentView: View {
    @StateObject private var model = TrafficWatchModel()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Monitor outgoing traffic", isOn: $model.monitoring)
                } footer: {
                    Text("When enabled, TrafficWatch records the destination of new outgoing connections from your device and looks up which organization owns that network.")
                }

                Section("Recent connections") {
                    if model.rows.isEmpty {
                        Text("No connections recorded yet.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(model.rows) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(row.destination)
                                    .font(.body.weight(.medium))
                                Spacer()
                                Text(row.transport)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let org = row.organization {
                                Label(org.name, systemImage: "building.2")
                                    .font(.subheadline)
                                    .foregroundStyle(.blue)
                            } else if row.lookupFailed {
                                Label("Organization unknown", systemImage: "questionmark.circle")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            HStack {
                                if let app = row.app {
                                    Text(app)
                                }
                                Spacer()
                                Text(row.timeText)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }

                Section {
                    Button("Clear history", role: .destructive) {
                        model.clear()
                    }
                }
            }
            .navigationTitle("TrafficWatch")
        }
    }
}

#Preview {
    ContentView()
}
