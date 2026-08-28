import DefaultBackend
import SwiftCrossUI

@main
struct VibeVaultDesktopApp: App {
    @State var model = DesktopModel()

    var body: some Scene {
        WindowGroup("Vibe Vault") {
            DesktopRootView(model: $model)
                .padding(12)
        }
        .defaultSize(width: 960, height: 640)
    }
}
