import Observation
import SwiftUI

/// What the edit and delete actions are working on right now.
@MainActor
@Observable
final class BoardActionState {
    var deleting: SavedBoard?
    var editing: SavedBoard?
}

/// Edit, Share and Delete, shared by the long-press menu and the board's own menu.
struct BoardMenuItems: View {
    var board: SavedBoard
    var actions: BoardActionState

    var body: some View {
        // ContentView tints the whole app red, and menus inherit it; only Delete should be red.
        Group {
            items
        }
        .tint(.primary)
    }

    @ViewBuilder
    private var items: some View {
        Button("Edit", systemImage: "pencil") { actions.editing = board }
        if let image = BoardStore.shared.image(board) {
            ShareLink(
                item: Image(uiImage: image),
                preview: SharePreview(board.title, image: Image(uiImage: image))
            ) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
        Divider()
        Button("Delete", systemImage: "trash", role: .destructive) { actions.deleting = board }
    }
}

private struct BoardActionsModifier: ViewModifier {
    @Bindable var actions: BoardActionState
    var onDeleted: () -> Void

    func body(content: Content) -> some View {
        content
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
