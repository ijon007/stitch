import Observation
import SwiftUI
import UIKit

struct SavedBoard: Codable, Identifiable, Hashable {
    var id: UUID
    var title: String
    var created: Date
    var file: String
}

/// Boards you finish, kept as a JSON index plus one PNG each in Documents.
@MainActor
@Observable
final class BoardStore {
    static let shared = BoardStore()

    private(set) var boards: [SavedBoard] = []

    private let folder = URL.documentsDirectory.appending(path: "Boards", directoryHint: .isDirectory)
    private var index: URL { folder.appending(path: "boards.json") }

    private init() {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: index),
           let saved = try? JSONDecoder().decode([SavedBoard].self, from: data) {
            boards = saved
        }
    }

    func imageURL(_ board: SavedBoard) -> URL { folder.appending(path: board.file) }

    func image(_ board: SavedBoard) -> UIImage? { UIImage(contentsOfFile: imageURL(board).path) }

    func add(title: String, png: URL) {
        let id = UUID()
        let file = "\(id.uuidString).png"
        do {
            try FileManager.default.copyItem(at: png, to: folder.appending(path: file))
        } catch {
            return
        }
        boards.insert(SavedBoard(id: id, title: title, created: .now, file: file), at: 0)
        persist()
    }

    func rename(_ board: SavedBoard, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = boards.firstIndex(where: { $0.id == board.id }) else { return }
        boards[index].title = trimmed
        persist()
    }

    /// Swaps in a re-edited image under a new file name, so covers refresh.
    func replace(_ board: SavedBoard, title: String, png: URL) {
        guard let index = boards.firstIndex(where: { $0.id == board.id }) else { return add(title: title, png: png) }
        let file = "\(UUID().uuidString).png"
        do {
            try FileManager.default.copyItem(at: png, to: folder.appending(path: file))
        } catch {
            return
        }
        try? FileManager.default.removeItem(at: imageURL(boards[index]))
        boards[index].title = title
        boards[index].file = file
        persist()
    }

    /// Saved boards keep only their picture, so editing starts from it as one full-size photo.
    func editItems(_ board: SavedBoard) -> [BoardItem] {
        guard let image = image(board) else { return [] }
        return [BoardItem(content: .photo(image, .plain), center: CGPoint(x: 0.5, y: 0.5), scale: 2.55)]
    }

    func remove(_ board: SavedBoard) {
        try? FileManager.default.removeItem(at: imageURL(board))
        boards.removeAll { $0.id == board.id }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(boards) else { return }
        try? data.write(to: index, options: .atomic)
    }
}
