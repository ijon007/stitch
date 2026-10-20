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
