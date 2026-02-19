import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            RepairView()
                .tabItem { Label("Repair", systemImage: "wrench.and.screwdriver.fill") }

            RepairHistoryView()
                .tabItem { Label("History", systemImage: "clock.fill") }

            CommunityView()
                .tabItem { Label("Community", systemImage: "person.3.fill") }

            AccountSettingsView()
                .tabItem { Label("Account", systemImage: "person.crop.circle.fill") }
        }
        .tint(Color.brand)
    }
}
