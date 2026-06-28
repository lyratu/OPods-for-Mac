import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("OPods for Mac", systemImage: "earbuds")
                .font(.title2.weight(.semibold))

            Text("A native macOS SwiftUI controller for OPPO, OnePlus, and realme earbuds, adapted from the Windows OPPO Pods reverse-engineered protocol.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            Text("Protocol and device matrix reference")
                .font(.headline)
            Text("Zhaoyi-ya/OPPO-Pods-For-Windows, Leaf-lsgtky/OppoPods, 1812z/OppoPods, and OPPO Melody 16.8.1 extracted device metadata.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("License")
                .font(.headline)
            Text("The protocol-derived implementation and bundled device metadata are treated as GPL-3.0-derived material from the reference project.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: 700, alignment: .leading)
    }
}
