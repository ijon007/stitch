import Observation
import SwiftUI

/// What the edit, rename and delete actions are working on right now.
@MainActor
@Observable
final class BoardActionState {
    var renaming: SavedBoard?
    var name = ""
    var deleting: SavedBoard?
    var editing: SavedBoard?

    func rename(_ board: SavedBoard) {
        name = board.title
        renaming = board
    }
}

/// Edit, Rename, Share and Delete, shared by the long-press menu and the board's own menu.
struct BoardMenuItems: View {
    var board: SavedBoard
    var actions: BoardActionState

    var body: some View {
        Button("Edit", systemImage: "pencil") { actions.editing = board }
        Button("Rename", systemImage: "character.cursor.ibeam") { actions.rename(board) }
        if let image = BoardStore.shared.image(board) {
            ShareLink(
                item: Image(uiImage: image),
                preview: SharePreview(board.title, image: Image(uiImage: image))
            ) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
        Divider()
        Button("Delete", systemImage: "trash") { actions.deleting = board }
    }
}

private struct BoardActionsModifier: ViewModifier {
    @Bindable var actions: BoardActionState
    var onDeleted: () -> Void

    func body(content: Content) -> some View {
        content
            .alert("Rename board", isPresented: Binding(
                get: { actions.renaming != nil },
                set: { if !$0 { actions.renaming = nil } }
            )) {
                TextField("Title", text: $actions.name)
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    if let board = actions.renaming { BoardStore.shared.rename(board, to: actions.name) }
                }
            }
            .confirmationDialog(
                "Delete this board?",
                isPresented: Binding(
                    get: { actions.deleting != nil },
                    set: { if !$0 { actions.deleting = nil } }
                ),
                titleVisibility: .visible,
                presenting: actions.deleting
            ) { board in
                Button("Delete", role: .destructive) {
                    BoardStore.shared.remove(board)
                    onDeleted()
                }
            } message: { _ in
                Text("It’s removed from your profile. This can’t be undone.")
            }
            .fullScreenCover(item: $actions.editing) { board in
                BoardEditorView(
                    startTitle: board.title,
                    startItems: BoardStore.shared.editItems(board),
                    replacing: board
                )
            }
    }
}

extension View {
    func boardActions(_ actions: BoardActionState, onDeleted: @escaping () -> Void = {}) -> some View {
        modifier(BoardActionsModifier(actions: actions, onDeleted: onDeleted))
    }
}
