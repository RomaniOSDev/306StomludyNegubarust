import SwiftUI

struct TopicBrowserView: View {
    @EnvironmentObject private var store: LearningStore
    @State private var search = ""
    @State private var selectedCategory = "All"
    @State private var filter: TopicFilter = .all
    @State private var sort: TopicSort = .due
    @State private var showAdd = false
    @State private var noteDrafts: [UUID: String] = [:]

    private var filtered: [Topic] {
        store.filteredTopics(search: search, category: selectedCategory, filter: filter, sort: sort)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundView()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        BannerHeader(
                            imageName: "banner_topics",
                            title: "Topic Browser",
                            subtitle: "Spaced review, filters, and calm paper stacks."
                        )

                        DailyGoalCard()

                        actionLinks

                        filterRow
                        categoryRow
                        sortRow

                        ForEach(filtered) { topic in
                            topicRow(topic)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 28)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .dismissKeyboardOnTap()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        FeedbackService.shared.tap()
                        showAdd = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color("AppPrimary"))
                    }
                }
            }
            .searchable(text: $search, prompt: "Search topics")
            .sheet(isPresented: $showAdd) {
                AddTopicSheet()
                    .environmentObject(store)
            }
            .onAppear { store.refreshDailyCountersIfNeeded() }
        }
    }

    private var actionLinks: some View {
        HStack(spacing: 10) {
            NavigationLink {
                QuickReviewView()
            } label: {
                linkChip("Due \(store.dueTopics.count)", systemImage: "rectangle.stack.fill.badge.plus")
            }
            NavigationLink {
                FocusTimerView()
            } label: {
                linkChip("Focus", systemImage: "timer")
            }
        }
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TopicFilter.allCases) { item in
                    TopicChip(title: item.rawValue, isSelected: filter == item) {
                        FeedbackService.shared.selection()
                        filter = item
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var categoryRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                TopicChip(title: "All", isSelected: selectedCategory == "All") {
                    FeedbackService.shared.selection()
                    selectedCategory = "All"
                }
                ForEach(store.categories, id: \.self) { category in
                    Button {
                        FeedbackService.shared.selection()
                        selectedCategory = category
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: CategoryStyle.symbol(for: category))
                                .font(.system(size: 12, weight: .semibold))
                            Text(category)
                                .font(.system(size: 14, weight: .semibold, design: .serif))
                        }
                        .foregroundStyle(selectedCategory == category ? Color("AppTextPrimary") : Color("AppTextSecondary"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule(style: .continuous)
                                .fill(selectedCategory == category
                                      ? CategoryStyle.color(for: category).opacity(0.85)
                                      : Color("AppSurface").opacity(0.9))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(CategoryStyle.color(for: category).opacity(0.7), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var sortRow: some View {
        HStack {
            Text("Sort")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color("AppTextSecondary"))
            Picker("Sort", selection: $sort) {
                ForEach(TopicSort.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.menu)
            .tint(Color("AppPrimary"))
            Spacer()
        }
    }

    @ViewBuilder
    private func topicRow(_ topic: Topic) -> some View {
        let expanded = store.expandedTopicID == topic.id
        PaperCard(stackDepth: expanded ? 3 : 2) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(CategoryStyle.color(for: topic.category))
                        .frame(width: 10, height: 10)
                        .padding(.top, 7)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: CategoryStyle.symbol(for: topic.category))
                                .font(.system(size: 12))
                                .foregroundStyle(CategoryStyle.color(for: topic.category))
                            Text(topic.category)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(CategoryStyle.color(for: topic.category))
                            if topic.isDue {
                                Text("DUE")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color("AppAccent"))
                            }
                        }
                        Text(topic.title)
                            .font(.system(size: 20, weight: .semibold, design: .serif))
                            .foregroundStyle(Color("AppTextPrimary"))
                            .fixedSize(horizontal: false, vertical: true)
                        Text(topic.summary)
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundStyle(Color("AppTextSecondary"))
                            .lineLimit(expanded ? nil : 2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text(topic.status.rawValue)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(topic.status == .known ? Color("AppAccent") : Color("AppTextSecondary"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color("AppBackground").opacity(0.55))
                        .clipShape(Capsule())
                        .layoutPriority(1)
                        .fixedSize()
                }

                if expanded {
                    Text(topic.content)
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundStyle(Color("AppTextPrimary").opacity(0.92))
                        .fixedSize(horizontal: false, vertical: true)

                    TextField(
                        "Study note / hint",
                        text: Binding(
                            get: { noteDrafts[topic.id] ?? topic.note },
                            set: { noteDrafts[topic.id] = $0 }
                        ),
                        axis: .vertical
                    )
                    .lineLimit(2...4)
                    .padding(10)
                    .background(Color("AppBackground").opacity(0.45))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .foregroundStyle(Color("AppTextPrimary"))
                    .onSubmit {
                        store.updateNote(for: topic.id, note: noteDrafts[topic.id] ?? topic.note)
                    }

                    Button("Save note") {
                        FeedbackService.shared.tap()
                        store.updateNote(for: topic.id, note: noteDrafts[topic.id] ?? topic.note)
                    }
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color("AppPrimary"))

                    FlexibleChipWrap {
                        Button {
                            FeedbackService.shared.tap()
                            store.reviewTopic(topic.id)
                        } label: {
                            labelChip("Review", systemImage: "arrow.triangle.2.circlepath")
                        }
                        Button {
                            FeedbackService.shared.tap()
                            if topic.status == .known {
                                store.markLearning(topic.id)
                            } else {
                                store.markKnown(topic.id)
                            }
                        } label: {
                            labelChip(
                                topic.status == .known ? "Set Learning" : "Mark Known",
                                systemImage: topic.status == .known ? "book" : "checkmark.seal"
                            )
                        }
                        Button {
                            FeedbackService.shared.tap()
                            store.toggleBookmark(topic.id)
                        } label: {
                            labelChip(
                                topic.isBookmarked ? "Saved" : "Bookmark",
                                systemImage: topic.isBookmarked ? "bookmark.fill" : "bookmark"
                            )
                        }
                    }
                }

                Button {
                    FeedbackService.shared.selection()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        store.toggleExpand(topic.id)
                    }
                } label: {
                    HStack {
                        Text(expanded ? "Collapse" : "Expand")
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    }
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color("AppPrimary"))
                }
                .buttonStyle(.plain)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 40)
                .onEnded { value in
                    if value.translation.width < -80 {
                        FeedbackService.shared.tap()
                        withAnimation {
                            store.deleteTopic(topic.id)
                        }
                    }
                }
        )
        .contextMenu {
            Button(role: .destructive) {
                store.deleteTopic(topic.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func linkChip(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(Color("AppTextPrimary"))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Color("AppSurface"))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color("AppAccent").opacity(0.35), lineWidth: 1)
            )
    }

    private func labelChip(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(Color("AppTextPrimary"))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color("AppPrimary").opacity(0.75))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .lineLimit(1)
            .minimumScaleFactor(0.85)
    }
}

struct FlexibleChipWrap: Layout {
    var spacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, origin) in result.origins.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var origins: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalWidth = max(totalWidth, x - spacing)
            totalHeight = y + rowHeight
        }
        return (CGSize(width: totalWidth, height: totalHeight), origins)
    }
}

struct AddTopicSheet: View {
    @EnvironmentObject private var store: LearningStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    @State private var title = ""
    @State private var summary = ""
    @State private var content = ""
    @State private var category = "Custom"
    @State private var note = ""

    private enum Field: Hashable {
        case title, summary, category, content, note
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color("AppBackground").ignoresSafeArea()
                Form {
                    Section("Details") {
                        TextField("Title", text: $title)
                            .focused($focusedField, equals: .title)
                        TextField("Summary", text: $summary, axis: .vertical)
                            .focused($focusedField, equals: .summary)
                        TextField("Category", text: $category)
                            .focused($focusedField, equals: .category)
                    }
                    Section("Flashcard body") {
                        TextField("Content", text: $content, axis: .vertical)
                            .lineLimit(4...10)
                            .focused($focusedField, equals: .content)
                    }
                    Section("Study note / hint") {
                        TextField("Optional hint", text: $note, axis: .vertical)
                            .focused($focusedField, equals: .note)
                    }
                }
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
            .dismissKeyboardOnTap()
            .navigationTitle("Add Topic")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        hideKeyboard()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        FeedbackService.shared.success()
                        hideKeyboard()
                        store.addTopic(title: title, summary: summary, content: content, category: category, note: note)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              || content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                        hideKeyboard()
                    }
                }
            }
        }
    }
}
