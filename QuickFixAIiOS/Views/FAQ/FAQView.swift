import SwiftUI

struct FAQView: View {
    @State private var expanded: Set<Int> = []

    var body: some View {
        NavigationStack {
            List {
                ForEach(faqs.indices, id: \.self) { i in
                    let faq = faqs[i]
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expanded.contains(i) },
                            set: { open in
                                if open { expanded.insert(i) } else { expanded.remove(i) }
                            }
                        )
                    ) {
                        Text(faq.answer)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    } label: {
                        Text(faq.question)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("FAQ")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private let faqs: [(question: String, answer: String)] = [
        (
            "How does the AI repair guidance work?",
            "Describe your home repair issue in plain language (or upload a photo) and our AI generates a step-by-step repair guide tailored to your specific problem, complete with tools, materials, and time estimates."
        ),
        (
            "What types of repairs can QuickFix AI help with?",
            "QuickFix AI covers plumbing, electrical, HVAC, carpentry, painting, flooring, roofing, appliances, landscaping, and general home maintenance."
        ),
        (
            "Is my information secure and private?",
            "Yes. We use Firebase Authentication with encrypted storage. Your repair data is private to your account and never shared."
        ),
        (
            "What is the 5-day free trial?",
            "New users can try the Starter plan for 5 days at no cost. Your card is required upfront but won't be charged until the trial ends. You can cancel anytime during the trial."
        ),
        (
            "Can I cancel my subscription anytime?",
            "Absolutely. Cancel anytime from Account Settings → Manage Subscription. You'll retain access until the end of your billing period."
        ),
        (
            "What's the difference between plans?",
            "Starter ($2/mo): 10 repairs/month, GPT-4.1 Nano, 10 saved repairs.\nPro ($10/mo): 25 repairs/month, GPT-4o Mini, 50 saved repairs.\nPremium ($20/mo): 100 repairs/month, GPT-4o, unlimited history."
        ),
        (
            "What is the refund policy?",
            "We offer a full refund within 24 hours of your first payment if you haven't used any credits. Request it from Account Settings."
        ),
        (
            "Does image analysis cost extra credits?",
            "No. Attaching a photo uses the same 1 credit as a text-only repair request. All plans include image analysis."
        ),
        (
            "What are credits?",
            "Each AI repair analysis uses 1 credit. Credits reset monthly. Starter gets 10, Pro 25, Premium 100."
        ),
        (
            "How does the community feature work?",
            "Share before-and-after photos of completed repairs with other QuickFix AI members. Like and engage with other homeowners' success stories."
        )
    ]
}
