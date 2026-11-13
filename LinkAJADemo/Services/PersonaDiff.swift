import SwiftUI

struct DiffRow: Identifiable {
    let id: String
    let group: String
    let label: String
    let budi: String
    let siti: String
    var differs: Bool { budi != siti }
}

/// Side by side comparison of Budi and Siti: resolved variables and theme tokens.
/// Used by the Persona Diff screen in Demo Tools and by the unit tests.
enum PersonaDiff {
    /// The 30 resolved variables compared: every variable either persona overrides, plus one shared control.
    static var variableKeys: [PEKeys] {
        var keys = Set<PEKeys>()
        for cfg in PersonaRegistry.all { keys.formUnion(cfg.overrides.keys) }
        keys.insert(.streakTarget)
        return PEKeys.allCases.filter { keys.contains($0) }
    }

    static func variableRows() -> [DiffRow] {
        let r = PEResolver.shared
        return variableKeys.map { k in
            DiffRow(id: k.name, group: "Resolved variables", label: k.name,
                    budi: r.display(k, for: PersonaRegistry.budi), siti: r.display(k, for: PersonaRegistry.siti))
        }
    }

    private static func tokens(_ t: PersonaTheme) -> [(String, String)] {
        [("Header gradient", "\(t.headerStartHex) to \(t.headerEndHex)"),
         ("Background", t.backgroundHex), ("Card", t.cardHex), ("Card border", t.borderHex ?? "none"),
         ("Accent", t.accentHex), ("Secondary", t.secondaryHex), ("CTA", t.ctaHex), ("Highlight", t.highlightHex),
         ("Icon tints", t.iconTintHexes.joined(separator: ", ")),
         ("Corner radius", "\(Int(t.radius))"), ("Font design", t.fontDesign == .rounded ? "SF Rounded" : "SF default"),
         ("Spacing", "\(Int(t.spacing))"), ("Icon style", t.squareIcons ? "line, rounded squares" : "filled, circles"),
         ("Balance font size", "\(Int(t.balanceFontSize))"),
         ("Tab set", t.tabs.map(\.rawValue).joined(separator: ", ")),
         ("Home modules", t.homeModules.map(\.rawValue).joined(separator: ", "))]
    }

    static func tokenRows() -> [DiffRow] {
        let b = tokens(.budi), s = tokens(.siti)
        return zip(b, s).map { DiffRow(id: "token." + $0.0, group: "Theme tokens", label: $0.0, budi: $0.1, siti: $1.1) }
    }

    static func allRows() -> [DiffRow] { tokenRows() + variableRows() }
}

struct PersonaDiffView: View {
    private let rows = PersonaDiff.allRows()

    var body: some View {
        let differing = rows.filter(\.differs).count
        List {
            Section {
                Text("\(differing) of \(rows.count) differ").font(.headline)
                HStack {
                    Spacer()
                    Text("Budi").font(.caption.bold()).frame(width: 120, alignment: .leading)
                    Text("Siti").font(.caption.bold()).frame(width: 120, alignment: .leading)
                }
            }
            ForEach(["Theme tokens", "Resolved variables"], id: \.self) { group in
                Section(group) {
                    ForEach(rows.filter { $0.group == group }) { r in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(r.label).font(.caption2.monospaced()).foregroundStyle(.secondary)
                            HStack(alignment: .top) {
                                Text(r.budi.isEmpty ? "(empty)" : r.budi).font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                                Text(r.siti.isEmpty ? "(empty)" : r.siti).font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .listRowBackground(r.differs ? Theme.secondary.opacity(0.15) : Color.clear)
                    }
                }
            }
        }
        .navigationTitle("Persona Diff")
        .navigationBarTitleDisplayMode(.inline)
    }
}
