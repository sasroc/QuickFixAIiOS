import SwiftUI

/// Standalone navigation-pushable view for a saved repair (used if navigating via URL / notification).
struct HistoricalRepairDetailView: View {
    let guide: RepairGuide

    var body: some View {
        RepairGuideView(guide: guide, isHistorical: true)
            .navigationTitle("Repair Guide")
            .navigationBarTitleDisplayMode(.inline)
    }
}
