import SwiftUI

struct RepairHistoryView: View {
    @Environment(HistoryViewModel.self) private var historyVM
    @Environment(UserViewModel.self)    private var userVM

    @State private var deleteTarget: RepairGuide? = nil
    @State private var showDeleteAlert = false
    @State private var selected: RepairGuide? = nil

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
            .navigationBarTitleDisplayMode(.large)
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
                RepairGuideView(guide: guide, isHistorical: true)
                    .navigationTitle("Repair Guide")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { selected = nil }
                        }
                    }
            }
        }
    }

    private var repairList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if let plan = userVM.profile?.plan, let cap = plan.historyCap {
                    let atCap = historyVM.repairs.count >= cap
                    if atCap {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("You've reached your \(plan.displayName) history limit (\(cap) repairs).")
                                .font(.footnote)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                }

                ForEach(historyVM.repairs) { repair in
                    RepairHistoryCard(repair: repair)
                        .onTapGesture { selected = repair }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                deleteTarget = repair
                                showDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(repair.title)
                .font(.subheadline).fontWeight(.semibold)
                .lineLimit(2)

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
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(12)
    }
}

private struct StatPill: View {
    let icon: String
    let value: String

    var body: some View {
        Label(value, systemImage: icon)
            .font(.caption2)
            .foregroundStyle(.secondary)
    }
}
