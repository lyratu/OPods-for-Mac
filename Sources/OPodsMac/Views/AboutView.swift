import SwiftUI

struct AboutView: View {
    @EnvironmentObject private var store: PodsStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Label("OPods for Mac", systemImage: "earbuds")
                    .font(.title2.weight(.semibold))

                Text(store.text("about.description"))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                Text(store.text("about.reference"))
                    .font(.headline)
                Text(store.text("about.reference.body"))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(store.text("about.sync"))
                    .font(.headline)
                Text(store.text("about.sync.body"))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(store.text("about.license"))
                    .font(.headline)
                Text(store.text("about.license.body"))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(24)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
