import SwiftUI

struct CloudSettingsView: View {
    @EnvironmentObject var cloudAuth: CloudAuthService
    @EnvironmentObject var cloudBackup: CloudBackupService
    @State private var showLogin = false
    @State private var showBackupList = false

    var body: some View {
        ScrollView {
            VStack(spacing: Tokens.Space.xl) {
                // Account section
                CloudAccountSection(showLogin: $showLogin)

                if cloudAuth.isAuthenticated {
                    // Backup section
                    CloudBackupSection(showBackupList: $showBackupList)

                    // Subscription section
                    CloudSubscriptionSection()
                }
            }
            .padding(Tokens.Space.xl)
        }
        .background(LiquidBackdrop())
        .navigationTitle("Cloud & Backup")
        .sheet(isPresented: $showLogin) {
            LoginView()
                .environmentObject(cloudAuth)
        }
        .sheet(isPresented: $showBackupList) {
            BackupListView()
                .environmentObject(cloudAuth)
                .environmentObject(cloudBackup)
        }
        .onAppear {
            Task {
                await cloudAuth.verifySession()
                await cloudBackup.getSchedule()
            }
        }
    }
}
