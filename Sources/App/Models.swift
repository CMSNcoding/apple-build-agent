import Foundation
import SwiftUI

// MARK: - 每日一言

struct Quote: Identifiable, Hashable, Codable {
    var id = UUID()
    let text: String
    let author: String
}

/// 一言 API（https://hitokoto.cn）响应
struct HitokotoResponse: Decodable {
    let hitokoto: String
    let from: String?
    let fromWho: String?

    enum CodingKeys: String, CodingKey {
        case hitokoto, from
        case fromWho = "from_who"
    }
}

enum QuoteLibrary {

    // MARK: - 远程一言（hitokoto.cn）

    private static let endpoint = "https://v1.hitokoto.cn/?c=d&c=i&c=k&encode=json&charset=utf-8"
    private static let cacheKey = "quote.cache.v2"

    private struct CachedQuote: Codable {
        let day: String
        let text: String
        let author: String
    }

    private static func dayString(_ date: Date = Date()) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private static func authorFrom(_ r: HitokotoResponse) -> String {
        if let w = r.fromWho, !w.isEmpty { return w }
        if let f = r.from, !f.isEmpty { return f }
        return "佚名"
    }

    /// 当天已经缓存过的远程一言（同日不再重复请求）
    static func cached(for date: Date = Date()) -> Quote? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let c = try? JSONDecoder().decode(CachedQuote.self, from: data),
              c.day == dayString(date) else { return nil }
        return Quote(text: c.text, author: c.author)
    }

    private static func saveCache(_ quote: Quote) {
        let c = CachedQuote(day: dayString(), text: quote.text, author: quote.author)
        guard let data = try? JSONEncoder().encode(c) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
    }

    private static func request() async throws -> HitokotoResponse {
        guard let url = URL(string: endpoint) else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.timeoutInterval = 8
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X)",
                     forHTTPHeaderField: "User-Agent")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let r = try JSONDecoder().decode(HitokotoResponse.self, from: data)
        guard !r.hitokoto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw URLError(.cannotParseResponse)
        }
        return r
    }

    /// 拉当天的一言并写缓存
    static func fetchDaily() async throws -> Quote {
        let r = try await request()
        let quote = Quote(text: r.hitokoto.trimmingCharacters(in: .whitespacesAndNewlines),
                          author: authorFrom(r))
        saveCache(quote)
        return quote
    }

    /// 点「换一条」时用，不写缓存
    static func fetchFresh() async throws -> Quote {
        let r = try await request()
        return Quote(text: r.hitokoto.trimmingCharacters(in: .whitespacesAndNewlines),
                     author: authorFrom(r))
    }

    // MARK: - 离线兜底

    static let all: [Quote] = [
        Quote(text: "生活不是等待风暴过去，而是学会在雨中起舞。", author: "维维安·格林"),
        Quote(text: "我们唯一要恐惧的，就是恐惧本身。", author: "罗斯福"),
        Quote(text: "把每一天都当作最后一天来过，总有一天你会如愿以偿。", author: "乔布斯"),
        Quote(text: "世界以痛吻我，要我报之以歌。", author: "泰戈尔"),
        Quote(text: "一个人的价值，应当看他贡献什么，而不是取得什么。", author: "爱因斯坦"),
        Quote(text: "不要因为走得太远，而忘记为什么出发。", author: "纪伯伦"),
        Quote(text: "真正的发现之旅，不在于寻找新风景，而在于拥有新眼光。", author: "普鲁斯特"),
        Quote(text: "所有的伟大，都源于一个勇敢的开始。", author: "佚名"),
        Quote(text: "认识你自己。", author: "苏格拉底"),
        Quote(text: "凡是过往，皆为序章。", author: "莎士比亚"),
        Quote(text: "保持饥饿，保持愚蠢。", author: "乔布斯"),
        Quote(text: "你若盛开，蝴蝶自来。", author: "佚名"),
        Quote(text: "苦难是人生的老师。", author: "巴尔扎克"),
        Quote(text: "希望是附丽于存在的，有存在，便有希望。", author: "鲁迅"),
        Quote(text: "人的一切痛苦，本质上都是对自己无能的愤怒。", author: "王小波"),
        Quote(text: "生命不息，奋斗不止。", author: "佚名"),
        Quote(text: "莫愁前路无知己，天下谁人不识君。", author: "高适"),
        Quote(text: "山重水复疑无路，柳暗花明又一村。", author: "陆游"),
        Quote(text: "长风破浪会有时，直挂云帆济沧海。", author: "李白"),
        Quote(text: "不积跬步，无以至千里。", author: "荀子"),
        Quote(text: "路漫漫其修远兮，吾将上下而求索。", author: "屈原"),
        Quote(text: "天行健，君子以自强不息。", author: "《周易》"),
        Quote(text: "纸上得来终觉浅，绝知此事要躬行。", author: "陆游"),
        Quote(text: "会当凌绝顶，一览众山小。", author: "杜甫"),
        Quote(text: "凡是不能杀死我的，都会使我更强大。", author: "尼采"),
        Quote(text: "人生如逆旅，我亦是行人。", author: "苏轼"),
        Quote(text: "未来属于那些相信梦想之美的人。", author: "罗斯福夫人"),
        Quote(text: "真正的自由，是能够拒绝。", author: "康德"),
        Quote(text: "沉默是一种美德，但在需要说话的时候沉默，是一种懦弱。", author: "佚名"),
        Quote(text: "愿你走出半生，归来仍是少年。", author: "佚名")
    ]

    /// 按"年内第几天"取，保证同一天始终是同一条
    static func quoteOfTheDay(for date: Date = Date()) -> Quote {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        return all[day % all.count]
    }

    static func random(excluding current: Quote?) -> Quote {
        var next = all.randomElement() ?? all[0]
        var guardCount = 0
        while next.text == current?.text && guardCount < 10 {
            next = all.randomElement() ?? all[0]
            guardCount += 1
        }
        return next
    }
}

// MARK: - 新闻

struct NewsItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let source: String
    let urlString: String
    let hot: String?
}

/// 兼容 vvhan 热榜接口的宽松解析：字段名在不同类别下略有差异
struct VVHanResponse: Decodable {
    struct Item: Decodable {
        let title: String?
        let name: String?
        let url: String?
        let mobilUrl: String?
        let hot: String?
        let index: Int?
    }
    let success: Bool?
    let data: FlexibleData?

    enum FlexibleData: Decodable {
        case list([Item])
        case dict([String: Item])

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let arr = try? container.decode([Item].self) {
                self = .list(arr)
            } else if let dict = try? container.decode([String: Item].self) {
                self = .dict(dict)
            } else {
                self = .list([])
            }
        }

        var items: [Item] {
            switch self {
            case .list(let a): return a
            case .dict(let d): return d.values.sorted { ($0.index ?? 0) < ($1.index ?? 0) }
            }
        }
    }
}

enum NewsService {
    /// 主源：vvhan 全网热榜（聚合微博/知乎/百度等）
    static let primaryURL = "https://api.vvhan.com/api/hotlist/all"

    static func fetch() async throws -> [NewsItem] {
        var request = URLRequest(url: URL(string: primaryURL)!)
        request.timeoutInterval = 12
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(VVHanResponse.self, from: data)
        let items = decoded.data?.items ?? []

        return items.compactMap { raw in
            guard let title = raw.title ?? raw.name, !title.isEmpty else { return nil }
            let link = raw.url ?? raw.mobilUrl ?? ""
            return NewsItem(
                title: title,
                source: link.isEmpty ? "热榜" : (URL(string: link)?.host ?? "热榜"),
                urlString: link,
                hot: raw.hot
            )
        }
    }

    /// 网络不通时的兜底，保证界面永远有内容可看
    static let fallback: [NewsItem] = [
        NewsItem(title: "网络不可用，这是本地示例数据", source: "本地", urlString: "", hot: nil),
        NewsItem(title: "下拉可重新请求热榜接口", source: "本地", urlString: "", hot: nil),
        NewsItem(title: "接口地址：api.vvhan.com/api/hotlist/all", source: "本地", urlString: "https://api.vvhan.com/api/hotlist/all", hot: nil)
    ]
}

// MARK: - 待办

struct TodoItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var isDone: Bool = false
    var createdAt: Date = Date()
}

final class TodoStore: ObservableObject {
    @Published private(set) var items: [TodoItem] = []

    private let key = "todo.items.v1"

    init() { load() }

    var pending: [TodoItem] { items.filter { !$0.isDone } }
    var completed: [TodoItem] { items.filter { $0.isDone } }

    func add(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items.insert(TodoItem(title: trimmed), at: 0)
        save()
    }

    func toggle(_ item: TodoItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx].isDone.toggle()
        save()
    }

    func delete(at offsets: IndexSet, from source: [TodoItem]) {
        let ids = offsets.map { source[$0].id }
        items.removeAll { ids.contains($0.id) }
        save()
    }

    func clearCompleted() {
        items.removeAll { $0.isDone }
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([TodoItem].self, from: data) else { return }
        items = decoded
    }
}
