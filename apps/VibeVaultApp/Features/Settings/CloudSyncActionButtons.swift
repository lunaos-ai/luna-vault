import SwiftUI

struct CloudSyncActionButtons: View {
    let canSyncToICloud: Bool
    let canPull: Bool
    let isWorking: Bool
    let onPush: () async -> Void
    let onPull: () async -> Void
    let onPreview: () -> Void
    let onRefresh: () -> Void

    var body: some View {
        HStack {
            Button {
                Task { await onPush() }
            } label: {
                Label("Sync to iCloud", systemImage: "icloud.and.arrow.up")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSyncToICloud)

            Button {
                Task { await onPull() }
            } label: {
                Label("Import from iCloud", systemImage: "icloud.and.arrow.down")
            }
            .disabled(!canPull)

            Button {
                onPreview()
            } label: {
                Label("Preview iCloud", systemImage: "doc.text.magnifyingglass")
            }
            .disabled(!canPull)

            Button {
                onRefresh()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(isWorking)
        }
    }
}
