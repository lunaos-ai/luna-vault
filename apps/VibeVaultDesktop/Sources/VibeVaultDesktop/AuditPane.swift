import SwiftCrossUI
import VaultCore

struct AuditPane: View {
    @Binding var model: DesktopModel
    var onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Audit log")
                .font(.system(size: 18, weight: .semibold))
            Text("Every vault read is recorded with the agent name. Values are never logged.")
                .foregroundColor(.gray)
            if model.auditLines.isEmpty {
                Text("No events yet")
                    .foregroundColor(.gray)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(model.auditLines, id: \.self) { line in
                            Text(line)
                                .font(.system(size: 12))
                        }
                    }
                }
            }
            Button("Refresh") { onRefresh() }
            Spacer()
        }
        .padding(8)
    }
}
