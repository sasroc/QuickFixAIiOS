import SwiftUI
import MapKit

struct RepairGuideView: View {
    let guide: RepairGuide
    let isHistorical: Bool
    var onBack: (() -> Void)? = nil

    @State private var currentStepIndex = 0
    @State private var completedSteps   = Set<Int>()
    @State private var showSidebar      = true
    @State private var checkedTools     = Set<Int>()
    @State private var checkedMaterials = Set<Int>()

    private var progress: Double {
        guard !guide.steps.isEmpty else { return 0 }
        return Double(completedSteps.count) / Double(guide.steps.count)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                if !isHistorical, let back = onBack {
                    Button { back() } label: {
                        Label("New Repair", systemImage: "arrow.left")
                            .font(.subheadline)
                    }
                    .padding(.horizontal)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(guide.title)
                        .font(.title3).fontWeight(.bold)
                        .lineLimit(3)

                    HStack(spacing: 12) {
                        if let conf = guide.confidenceScore {
                            Label("\(conf)% confident", systemImage: "chart.bar.fill")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Label("\(guide.estimatedTime) min", systemImage: "clock.fill")
                            .font(.caption).foregroundStyle(.secondary)
                        if let ts = guide.timestamp {
                            Label(ts.shortFormatted, systemImage: "calendar")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }

                    // Progress bar
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Progress").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text("\(completedSteps.count)/\(guide.steps.count) steps")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.inputBackground)
                                    .frame(height: 7)
                                Capsule()
                                    .fill(LinearGradient(
                                        colors: [Color.brandBlue, Color.brand],
                                        startPoint: .leading, endPoint: .trailing
                                    ))
                                    .frame(width: max(geo.size.width * progress, 0), height: 7)
                                    .animation(.easeInOut, value: progress)
                            }
                        }
                        .frame(height: 7)
                    }
                }
                .padding(.horizontal)

                // Step navigator
                if !guide.steps.isEmpty {
                    stepCard
                        .padding(.horizontal)

                    // Prev / Next
                    HStack {
                        Button {
                            withAnimation { currentStepIndex = max(0, currentStepIndex - 1) }
                        } label: {
                            Label("Previous", systemImage: "chevron.left")
                        }
                        .disabled(currentStepIndex == 0)

                        Spacer()

                        Text("Step \(currentStepIndex + 1) of \(guide.steps.count)")
                            .font(.footnote).foregroundStyle(.secondary)

                        Spacer()

                        Button {
                            withAnimation { currentStepIndex = min(guide.steps.count - 1, currentStepIndex + 1) }
                        } label: {
                            Label("Next", systemImage: "chevron.right")
                                .labelStyle(.titleAndIcon)
                        }
                        .disabled(currentStepIndex == guide.steps.count - 1)
                    }
                    .padding(.horizontal)
                }

                // Sidebar toggle
                Button {
                    withAnimation { showSidebar.toggle() }
                } label: {
                    Label(showSidebar ? "Hide Tools & Materials" : "Show Tools & Materials",
                          systemImage: showSidebar ? "chevron.up" : "chevron.down")
                        .font(.subheadline)
                }
                .padding(.horizontal)

                if showSidebar {
                    HStack(alignment: .top, spacing: 12) {
                        // Tools
                        if !guide.tools.isEmpty {
                            ChecklistSection(title: "Tools", icon: "wrench.fill", items: guide.tools, checked: $checkedTools)
                        }
                        // Materials
                        if !guide.materials.isEmpty {
                            ChecklistSection(title: "Materials", icon: "shippingbox.fill", items: guide.materials, checked: $checkedMaterials)
                        }
                    }
                    .padding(.horizontal)
                }

                // Find nearby hardware stores
                Button {
                    let query = "hardware store"
                    if let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                       let url = URL(string: "maps://?q=\(encoded)") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Find Nearby Hardware Stores", systemImage: "map.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.cardBackground)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.brand.opacity(0.3), lineWidth: 1))
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .padding(.top, 16)
        }
        .background(Color.appBackground)
    }

    // MARK: - Step Card

    private var stepCard: some View {
        let step = guide.steps[currentStepIndex]
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    if completedSteps.contains(currentStepIndex) {
                        Circle()
                            .fill(Color.success)
                            .frame(width: 34, height: 34)
                    } else {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color.brandBlue, Color.brand],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                            .frame(width: 34, height: 34)
                            .shadow(color: Color.brand.opacity(0.3), radius: 4, y: 2)
                    }
                    Text("\(currentStepIndex + 1)")
                        .font(.headline).fontWeight(.bold).foregroundStyle(.white)
                }
                Text("Step \(currentStepIndex + 1)")
                    .font(.headline)
                Spacer()
                Button {
                    if completedSteps.contains(currentStepIndex) {
                        completedSteps.remove(currentStepIndex)
                    } else {
                        completedSteps.insert(currentStepIndex)
                    }
                } label: {
                    Label(
                        completedSteps.contains(currentStepIndex) ? "Completed" : "Mark Complete",
                        systemImage: completedSteps.contains(currentStepIndex) ? "checkmark.circle.fill" : "circle"
                    )
                    .font(.footnote)
                    .foregroundStyle(completedSteps.contains(currentStepIndex) ? Color.success : Color.secondary)
                }
            }

            Text(step.description)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(completedSteps.contains(currentStepIndex) ? Color.success.opacity(0.4) : Color.clear, lineWidth: 2)
        )
        .gesture(
            DragGesture(minimumDistance: 40)
                .onEnded { val in
                    if val.translation.width < -40 {
                        withAnimation { currentStepIndex = min(guide.steps.count - 1, currentStepIndex + 1) }
                    } else if val.translation.width > 40 {
                        withAnimation { currentStepIndex = max(0, currentStepIndex - 1) }
                    }
                }
        )
    }
}

// MARK: - Checklist Section

private struct ChecklistSection: View {
    let title: String
    let icon: String
    let items: [String]
    @Binding var checked: Set<Int>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.subheadline).fontWeight(.semibold)

            ForEach(items.indices, id: \.self) { i in
                Button {
                    if checked.contains(i) { checked.remove(i) } else { checked.insert(i) }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: checked.contains(i) ? "checkmark.square.fill" : "square")
                            .foregroundStyle(checked.contains(i) ? .green : .secondary)
                        Text(items[i])
                            .font(.caption)
                            .strikethrough(checked.contains(i))
                            .foregroundStyle(checked.contains(i) ? .secondary : .primary)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(10)
    }
}
