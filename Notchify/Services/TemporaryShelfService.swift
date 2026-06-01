import Combine
import Foundation

@MainActor
final class TemporaryShelfService: ObservableObject {
    @Published private(set) var items: [ShelfItem] = []

    func add(urls: [URL]) {
        for url in urls where !items.contains(where: { $0.url == url }) {
            items.insert(ShelfItem(url: url, addedAt: Date()), at: 0)
        }
        items = Array(items.prefix(12))
    }

    func remove(_ item: ShelfItem) {
        items.removeAll { $0.id == item.id }
    }
}

