import SwiftUI

struct RepairHistoryView: View {
    @Environment(HistoryViewModel.self) private var historyVM
    @Environment(UserViewModel.self)    private var userVM
    @Environment(RevenueCatService.self) private var revenueCatService

    @State private var deleteTarget: RepairGuide? = nil
    @State private var showDeleteAlert = false
    @State private var selected: RepairGuide? = nil
    @State private var showUnlockPaywall = false

    private var isPreview: Bool {
        userVM.isInDiagnosisPreview(timing: revenueCatService.paywallTiming)
    }

    var body: some View {
        NavigationStack {
            Group {
                if historyVM.isLoading {
                    ProgressView("Loading history…")
                } else if let error = historyVM.errorMessage {
                    errorState(message: error)
                } else if historyVM.repairs.isEmpty {
                    emptyState
                } else {
                    repairList
                }
            }
            .navigationTitle("Repair History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(
                LinearGradient(colors: [Color.brandBlue, Color.brand], startPoint: .leading, endPoint: .trailing),
                for: .navigationBar
            )
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .background(Color.appBackground)
        .alert("Delete Repair?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let target = deleteTarget {
                    Task { await historyVM.delete(repair: target) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This repair guide will be permanently deleted.")
        }
        .sheet(item: $selected) { guide in
            NavigationStack {
                RepairGuideView(
                    guide: guide,
                    isHistorical: true,
                    onUnlock: isPreview ? { showUnlockPaywall = true } : nil
                )
                    .navigationTitle("Repair Guide")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { selected = nil }
                        }
                    }
            }
            .sheet(isPresented: $showUnlockPaywall) {
                UnlockPaywallSheet()
            }
        }
        .onChange(of: userVM.hasActiveAccess) { _, hasAccess in
            if hasAccess { showUnlockPaywall = false }
        }
    }

    private var repairHistoryHeader: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Repair History")
                    .font(.title2).fontWeight(.heavy)
                    .foregroundStyle(.primary)

                Group {
                    if let cap = userVM.profile?.plan.historyCap {
                        Text("\(historyVM.repairs.count) / \(cap) repairs saved")
                    } else {
                        Text("\(historyVM.repairs.count) repair\(historyVM.repairs.count == 1 ? "" : "s") saved")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()

            // Circular progress (only when there's a cap)
            if let cap = userVM.profile?.plan.historyCap {
                let fraction = min(Double(historyVM.repairs.count) / Double(cap), 1.0)
                ZStack {
                    Circle()
                        .stroke(Color.inputBackground, lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: fraction)
                        .stroke(
                            LinearGradient(
                                colors: [Color.brandBlue, Color.brand],
                                startPoint: .leading, endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut, value: fraction)
                    Text("\(historyVM.repairs.count)")
                        .font(.caption2).fontWeight(.bold)
                        .foregroundStyle(Color.brand)
                }
                .frame(width: 44, height: 44)
            } else {
                Image(systemName: "clock.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.brand)
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.brandBlue.opacity(0.06), Color.brand.opacity(0.06)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    LinearGradient(
                        colors: [Color.brandBlue.opacity(0.2), Color.brand.opacity(0.2)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
    }

    private var repairList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Header card
                repairHistoryHeader
                    .padding(.top, 4)

                // At-cap warning (only when reached limit)
                if let plan = userVM.profile?.plan, let cap = plan.historyCap {
                    if historyVM.repairs.count >= cap {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("You've reached your \(plan.displayName) history limit (\(cap) repairs).")
                                .font(.footnote)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(10)
                    }
                }

                ForEach(historyVM.repairs) { repair in
                    RepairHistoryCard(repair: repair) {
                        deleteTarget = repair
                        showDeleteAlert = true
                    }
                    .onTapGesture { selected = repair }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .background(Color.appBackground)
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.lock.fill")
                .font(.system(size: 56))
                .foregroundStyle(.orange)
            Text("Couldn't Load History")
                .font(.title3).fontWeight(.semibold)
            Text(message)
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("No Repair History")
                .font(.title3).fontWeight(.semibold)
            Text("Your saved repair guides will appear here.")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Card

private struct RepairHistoryCard: View {
    let repair: RepairGuide
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Left gradient accent bar
            Rectangle()
                .fill(LinearGradient(
                    colors: [Color.brandBlue, Color.brand],
                    startPoint: .top, endPoint: .bottom
                ))
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Text(repair.title)
                        .font(.subheadline).fontWeight(.semibold)
                        .lineLimit(2)
                    Spacer()
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.subheadline)
                            .foregroundStyle(.red.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 16) {
                    StatPill(icon: "list.number",  value: "\(repair.steps.count) steps")
                    StatPill(icon: "wrench.fill",  value: "\(repair.tools.count) tools")
                    StatPill(icon: "clock.fill",   value: "\(repair.estimatedTime) min")
                }

                if let ts = repair.timestamp {
                    Text(ts.mediumFormatted)
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
        }
        .background(Color.cardBackground)
        .cornerRadius(12)
        .clipped()
    }
}

private struct StatPill: View {
    let icon: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(Color.brand)
            Text(value)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
