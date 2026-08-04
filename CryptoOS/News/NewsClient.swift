import Foundation

/// Pulls and merges crypto news RSS feeds — no API keys needed.
struct NewsFeed {
    let name: String
    let url: URL
}

@MainActor
final class NewsStore: ObservableObject {
    @Published var items: [NewsItem] = []
    @Published var error: String?

    static let feeds: [NewsFeed] = [
        NewsFeed(name: "CoinDesk", url: URL(string: "https://www.coindesk.com/arc/outboundfeeds/rss/")!),
        NewsFeed(name: "Cointelegraph", url: URL(string: "https://cointelegraph.com/rss")!),
        NewsFeed(name: "Decrypt", url: URL(string: "https://decrypt.co/feed")!),
    ]

    func refresh() async {
        var all: [NewsItem] = []
        await withTaskGroup(of: [NewsItem].self) { group in
            for feed in Self.feeds {
                group.addTask {
                    guard let (data, _) = try? await URLSession.shared.data(from: feed.url) else { return [] }
                    return RSSParser.parse(data: data, source: feed.name)
                }
            }
            for await batch in group {
                all.append(contentsOf: batch)
            }
        }
        if all.isEmpty {
            if items.isEmpty { error = "Couldn't load news. Pull to retry." }
        } else {
            items = all.sorted { $0.date > $1.date }
            error = nil
        }
    }
}

enum RSSParser {
    static func parse(data: Data, source: String) -> [NewsItem] {
        let delegate = Delegate(source: source)
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return delegate.items
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        let source: String
        var items: [NewsItem] = []

        private var inItem = false
        private var currentElement = ""
        private var title = ""
        private var link = ""
        private var pubDate = ""
        private var imageURL: String?

        init(source: String) {
            self.source = source
        }

        private static let dateFormats: [DateFormatter] = {
            ["EEE, dd MMM yyyy HH:mm:ss Z", "EEE, dd MMM yyyy HH:mm:ss zzz", "yyyy-MM-dd'T'HH:mm:ssZ"].map {
                let f = DateFormatter()
                f.locale = Locale(identifier: "en_US_POSIX")
                f.dateFormat = $0
                return f
            }
        }()

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                    qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
            currentElement = elementName
            if elementName == "item" {
                inItem = true
                title = ""; link = ""; pubDate = ""; imageURL = nil
            }
            if inItem, imageURL == nil,
               elementName == "media:content" || elementName == "media:thumbnail" || elementName == "enclosure",
               let url = attributeDict["url"],
               attributeDict["type"]?.hasPrefix("audio") != true {
                imageURL = url
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            guard inItem else { return }
            switch currentElement {
            case "title": title += string
            case "link": link += string
            case "pubDate": pubDate += string
            default: break
            }
        }

        func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
            guard inItem, currentElement == "title",
                  let text = String(data: CDATABlock, encoding: .utf8) else { return }
            title += text
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                    qualifiedName qName: String?) {
            guard elementName == "item" else {
                currentElement = ""
                return
            }
            inItem = false
            let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanLink = link.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanDate = pubDate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanTitle.isEmpty, let url = URL(string: cleanLink) else { return }
            let date = Self.dateFormats.lazy.compactMap { $0.date(from: cleanDate) }.first ?? Date.distantPast
            items.append(NewsItem(
                id: cleanLink,
                title: cleanTitle,
                link: url,
                source: source,
                date: date,
                imageURL: imageURL.flatMap(URL.init)
            ))
        }
    }
}
