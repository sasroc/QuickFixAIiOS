import SwiftUI

struct LandingView: View {
    @State private var showAuth    = false
    @State private var showPricing = false
    @State private var showFAQ     = false
    @State private var showTerms   = false
    @State private var showPrivacy = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroSection
                trustBadges
                stepsSection
                featuresSection
                founderSection
                beforeAfterSection
                faqPreviewSection
                bottomCTA
                footerSection
            }
        }
        .ignoresSafeArea(edges: .top)
        .sheet(isPresented: $showAuth)    { AuthView() }
        .sheet(isPresented: $showPricing) { PricingView(startTrial: false) }
        .sheet(isPresented: $showFAQ)     { FAQView() }
        .sheet(isPresented: $showTerms)   { TermsView() }
        .sheet(isPresented: $showPrivacy) { PrivacyView() }
    }

    // MARK: - Hero

    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            Color.brandGradient.ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer(minLength: 80)

                // Logo + Title
                VStack(spacing: 8) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.white)

                    HStack(spacing: 0) {
                        Text("Quick")
                            .font(.system(size: 38, weight: .heavy))
                            .foregroundStyle(.white)
                        Text("Fix")
                            .font(.system(size: 38, weight: .heavy))
                            .foregroundStyle(.white.opacity(0.85))
                        Text(" AI")
                            .font(.system(size: 38, weight: .heavy))
                            .foregroundStyle(Color.yellow)
                    }
                }

                Text("Your AI-Powered Home Maintenance Advisor")
                    .font(.title3)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 40)

                Text("Get instant, professional-grade repair guidance for any home issue — powered by advanced AI.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.horizontal, 30)

                VStack(spacing: 12) {
                    Button {
                        showAuth = true
                    } label: {
                        HStack {
                            Image(systemName: "star.fill")
                            Text("Start 5-Day FREE Trial")
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.yellow)
                        .foregroundStyle(Color(red: 0.07, green: 0.35, blue: 0.18))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
                    }
                    .padding(.horizontal, 30)

                    Button {
                        showAuth = true
                    } label: {
                        Text("Sign In")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.white.opacity(0.15))
                            .foregroundStyle(.white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(.white.opacity(0.4), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 30)
                }
                .padding(.top, 8)

                Spacer(minLength: 40)
            }
        }
        .frame(minHeight: 560)
    }

    // MARK: - Trust Badges

    private var trustBadges: some View {
        HStack(spacing: 0) {
            ForEach(badges, id: \.title) { badge in
                VStack(spacing: 6) {
                    Image(systemName: badge.icon)
                        .font(.title2)
                        .foregroundStyle(Color.brand)
                    Text(badge.title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                if badge.title != badges.last?.title {
                    Divider().frame(height: 40)
                }
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal)
        .background(Color.cardBackground)
    }

    private let badges = [
        (icon: "lock.shield.fill",   title: "Secure\n& Private"),
        (icon: "bolt.fill",          title: "Instant\nSolutions"),
        (icon: "checkmark.seal.fill", title: "Accurate\nResults")
    ].map { (icon: $0.icon, title: $0.title) }

    // MARK: - Steps

    private var stepsSection: some View {
        VStack(spacing: 24) {
            SectionHeader(title: "How It Works", subtitle: "Get your repair guide in seconds")

            HStack(alignment: .top, spacing: 16) {
                StepCard(number: "1", icon: "text.bubble.fill", title: "Describe", detail: "Tell us about your home repair issue in plain language.")
                StepCard(number: "2", icon: "brain.head.profile", title: "AI Guidance", detail: "Our AI analyzes your issue and crafts a step-by-step plan.")
                StepCard(number: "3", icon: "checkmark.circle.fill", title: "Fix It", detail: "Follow the guide and complete your repair with confidence.")
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 32)
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(spacing: 24) {
            SectionHeader(title: "Everything You Need", subtitle: "Professional repairs made simple")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                FeatureCard(icon: "brain.fill",              title: "Smart AI Diagnosis",          detail: "Advanced models identify issues from your description or photo.")
                FeatureCard(icon: "list.bullet.clipboard",  title: "Professional Guides",         detail: "Detailed step-by-step instructions with tools & materials lists.")
                FeatureCard(icon: "house.and.flag.fill",    title: "All Home Systems",            detail: "Plumbing, electrical, HVAC, carpentry, and more.")
                FeatureCard(icon: "iphone.radiowaves.left.and.right", title: "Always Accessible", detail: "Access guides anytime, anywhere — even offline once loaded.")
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 32)
        .background(Color.heroGradient)
    }

    // MARK: - Founder

    private var founderSection: some View {
        VStack(spacing: 20) {
            SectionHeader(title: "Built by a Homeowner", subtitle: "For homeowners")

            VStack(spacing: 16) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(Color.brand)

                VStack(spacing: 8) {
                    Text("Rocco Sassani")
                        .font(.title2).fontWeight(.bold)
                    Text("Founder")
                        .font(.subheadline).foregroundStyle(.secondary)
                }

                Text("\"I built QuickFix AI after struggling with expensive contractor calls for simple home repairs. Now anyone can get professional guidance instantly — no experience required.\"")
                    .font(.subheadline)
                    .italic()
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
            }
            .padding()
            .background(Color.cardBackground)
            .cornerRadius(16)
            .padding(.horizontal)
        }
        .padding(.vertical, 32)
    }

    // MARK: - Before/After

    private var beforeAfterSection: some View {
        VStack(spacing: 24) {
            SectionHeader(title: "Real Results", subtitle: "See QuickFix AI in action")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(beforeAfterExamples, id: \.title) { ex in
                        BeforeAfterCard(example: ex)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 32)
        .background(Color.heroGradient)
    }

    private let beforeAfterExamples: [BeforeAfterExample] = [
        BeforeAfterExample(title: "Leaky Faucet", category: "Plumbing",    before: "dripping tap, water stains", after: "clean, dry fixture"),
        BeforeAfterExample(title: "Cracked Wall", category: "Drywall",     before: "visible crack, peeling paint", after: "smooth, painted surface"),
        BeforeAfterExample(title: "Dead Outlet",  category: "Electrical",  before: "non-functional outlet", after: "working outlet, safe wiring")
    ]

    // MARK: - FAQ Preview

    private var faqPreviewSection: some View {
        VStack(spacing: 20) {
            SectionHeader(title: "Common Questions", subtitle: "")

            VStack(spacing: 12) {
                ForEach(faqPreviews, id: \.q) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.q).font(.subheadline).fontWeight(.semibold)
                        Text(item.a).font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.cardBackground)
                    .cornerRadius(10)
                }
            }
            .padding(.horizontal)

            Button { showFAQ = true } label: {
                Text("View All FAQs")
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.brand)
            }
        }
        .padding(.vertical, 32)
    }

    private let faqPreviews = [
        (q: "How does the AI repair guidance work?",
         a: "Describe your issue (or upload a photo) and our AI generates step-by-step instructions with tools and materials."),
        (q: "Is my information secure?",
         a: "Yes. We use Firebase Auth and encrypted storage. Your repair data is private to your account."),
        (q: "Can I cancel my subscription anytime?",
         a: "Absolutely. Cancel anytime from Account Settings — no questions asked.")
    ]

    // MARK: - Bottom CTA

    private var bottomCTA: some View {
        VStack(spacing: 20) {
            Text("Ready to Fix It?")
                .font(.title).fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text("Join thousands of homeowners saving money with AI-powered repair guidance.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            Button {
                showAuth = true
            } label: {
                Text("Get Started Free")
                    .primaryButtonStyle()
                    .padding(.horizontal, 40)
            }

            Button { showPricing = true } label: {
                Text("View Pricing")
                    .font(.subheadline)
                    .foregroundStyle(Color.brand)
            }
        }
        .padding(.vertical, 40)
        .padding(.horizontal)
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 12) {
            Divider()
            HStack(spacing: 24) {
                Button { showTerms   = true } label: { Text("Terms").font(.caption).foregroundStyle(.secondary) }
                Button { showPrivacy = true } label: { Text("Privacy").font(.caption).foregroundStyle(.secondary) }
                Button { showFAQ     = true } label: { Text("FAQ").font(.caption).foregroundStyle(.secondary) }
            }
            Text("© 2025 QuickFix AI. All rights reserved.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 20)
    }
}

// MARK: - Sub-components

private struct SectionHeader: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(spacing: 6) {
            Text(title).font(.title2).fontWeight(.bold)
            if !subtitle.isEmpty {
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
    }
}

private struct StepCard: View {
    let number: String
    let icon: String
    let title: String
    let detail: String
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(Color.brandBlue).frame(width: 40, height: 40)
                Text(number).font(.headline).fontWeight(.bold).foregroundStyle(.white)
            }
            Image(systemName: icon).font(.title2).foregroundStyle(Color.brandBlue)
            Text(title).font(.subheadline).fontWeight(.semibold)
            Text(detail).font(.caption).multilineTextAlignment(.center).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color.cardBackground)
        .cornerRadius(12)
    }
}

private struct FeatureCard: View {
    let icon: String
    let title: String
    let detail: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon).font(.title2).foregroundStyle(Color.brand)
            Text(title).font(.subheadline).fontWeight(.semibold)
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(12)
    }
}

struct BeforeAfterExample {
    let title: String
    let category: String
    let before: String
    let after: String
}

private struct BeforeAfterCard: View {
    let example: BeforeAfterExample
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(example.title).font(.headline).fontWeight(.bold)
            Text(example.category).font(.caption).foregroundStyle(Color.brand).fontWeight(.semibold)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Before", systemImage: "xmark.circle.fill").font(.caption).foregroundStyle(.red)
                    Text(example.before).font(.caption2).foregroundStyle(.secondary)
                        .frame(width: 110)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Label("After", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(Color.success)
                    Text(example.after).font(.caption2).foregroundStyle(.secondary)
                        .frame(width: 110)
                }
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(14)
        .frame(width: 260)
    }
}
