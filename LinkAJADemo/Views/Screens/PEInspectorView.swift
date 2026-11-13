import SwiftUI

/// Lists every LinkAJA.* variable with default, live value and a highlight when they differ.
struct PEInspectorView: View {
    @EnvironmentObject var pe: PEStore
    @EnvironmentObject var resolver: PEResolver
    @State private var refreshing = false

    private var screens: [String] {
        var seen = Set<String>()
        return PEKeys.allCases.map { $0.screen }.filter { seen.insert($0).inserted }
    }

    var body: some View {
        List {
            Section("Status") {
                row("Last variables update", pe.lastUpdate.map(format) ?? "never")
                row("Last fetch", pe.lastFetchSucceeded.map { $0 ? "success" : "failed" } ?? "not run yet")
                row("Local previews active", pe.overrideCount > 0 ? "\(pe.overrideCount)" : (pe.defaultsOnly ? "defaults only" : "none"))
                Button {
                    refreshing = true
                    Task { await pe.refresh(); refreshing = false }
                } label: {
                    HStack { Text("Refresh from CleverTap"); if refreshing { Spacer(); ProgressView() } }
                }
                Button("Reset to defaults (local only)", role: .destructive) { pe.resetToDefaults() }
            }

            Section("Resolution") {
                Toggle("Persona defaults", isOn: $resolver.personaDefaults)
                Text("Order: Dashboard, then Persona, then Default. A dashboard value equal to the default does not count as a dashboard override.")
                    .font(.caption2).foregroundStyle(.secondary)
            }

            Section("Local previews (not sent to CleverTap)") {
                Button("Top up bonus on") { pe.setOverride(.bonusEnabled, true) }
                Button("Praktis variant") { pe.setOverride(.crossVariant, "praktis") }
                Button("Grid promo layout") { pe.setOverride(.promoLayout, "grid") }
            }

            ForEach(screens, id: \.self) { screen in
                Section("LinkAJA." + screen) {
                    ForEach(PEKeys.allCases.filter { $0.screen == screen }, id: \.self) { key in
                        let source = resolver.source(key)
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(key.name).font(.caption2.monospaced()).foregroundStyle(.secondary)
                                Spacer()
                                Chip(text: source.rawValue, color: source == .dashboard ? Theme.red : (source == .persona ? .blue : .gray))
                            }
                            HStack(alignment: .top) {
                                Text("default").font(.caption2).foregroundStyle(.secondary).frame(width: 56, alignment: .leading)
                                Text(key.defaultValue.display.isEmpty ? "(empty)" : key.defaultValue.display).font(.caption)
                            }
                            HStack(alignment: .top) {
                                Text("resolved").font(.caption2).foregroundStyle(.secondary).frame(width: 56, alignment: .leading)
                                let v = resolver.display(key)
                                Text(v.isEmpty ? "(empty)" : v).font(.caption.bold()).foregroundStyle(source == .dashboard ? Theme.red : .primary)
                                if pe.isLocalPreview(key) { Chip(text: "local", color: .gray) }
                            }
                        }
                        .listRowBackground(source == .dashboard ? Theme.red.opacity(0.08) : Color.clear)
                    }
                }
            }
        }
        .navigationTitle("PE Inspector")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack { Text(k).font(.subheadline); Spacer(); Text(v).font(.footnote).foregroundStyle(.secondary) }
    }

    private func format(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "d MMM HH:mm:ss"; return f.string(from: d)
    }
}
