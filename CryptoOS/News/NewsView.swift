import SwiftUI
import SafariServices

struct NewsView: View {
    @StateObject private var news = NewsStore()
    @State private var sourceFilter: String?
    @State private var reading: NewsItem?

    private var filtered: [NewsItem] {
        guard let source = sourceFilter else { return news.items }
        return news.items.filter { $0.source == source }
    }

    var body: some View {
        NavigationStack {
            List {
                if let error = news.error {
                    Text(error).foregroundStyle(.secondary)
                }
                ForEach(filtered) { item in
                    Button {
                        reading = item
                    } label: {
                        NewsRow(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
            .navigationTitle("News")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("All sources") { sourceFilter = nil }
                        ForEach(NewsStore.feeds, id: \.name) { feed in
                            Button(feed.name) { sourceFilter = feed.name }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .refreshable { await news.refresh() }
            .task {
                if news.items.isEmpty { await news.refresh() }
            }
            .overlay {
                if news.items.isEmpty && news.error == nil {
                    ProgressView()
                }
            }
            .sheet(item: $reading) { item in
                SafariView(url: item.link)
                    .ignoresSafeArea()
            }
        }
    }
}

struct NewsRow: View {
    let item: NewsItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(3)
                HStack(spacing: 6) {
                    Text(item.source)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tint)
                    if item.date != Date.distantPast {
                        Text(item.date, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            if let imageURL = item.imageURL {
                AsyncImage(url: imageURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray5))
                }
                .frame(width: 72, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.vertical, 4)
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
