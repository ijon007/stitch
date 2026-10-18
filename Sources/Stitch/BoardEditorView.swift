import SwiftUI
import UIKit

// MARK: - Model

struct BoardItem: Identifiable, Equatable {
    enum Content: Equatable {
        case photo(UIImage)
        case sticker(StickerKind)
    }

    let id = UUID()
    var content: Content
    /// Unit space: 0...1 of the board, so the layout survives any board size.
    var center: CGPoint
    var scale: CGFloat = 1
    var rotation: Angle = .zero

    var accessibilityName: String {
        switch content {
        case .photo: "Photo"
        case .sticker(let kind): kind.label
        }
    }
}

/// Board items plus undo history. Changes made inside a session collapse into one undo step.
struct BoardDraft {
    private(set) var items: [BoardItem] = []
    private var history: [[BoardItem]] = []
    private var sessionStart: [BoardItem]?

    var canUndo: Bool { !history.isEmpty }

    // ponytail: whole-array snapshots per change; fine for dozens of items, switch to diffs if boards grow huge.
    mutating func change(_ edit: (inout [BoardItem]) -> Void) {
        let before = items
        edit(&items)
        if items != before { history.append(before) }
    }

    /// Edits without an undo step; pair with a session so the step is recorded once.
    mutating func update(_ edit: (inout [BoardItem]) -> Void) {
        edit(&items)
    }

    mutating func beginSession() {
        sessionStart = items
    }

    mutating func endSession() {
        if let start = sessionStart, start != items { history.append(start) }
        sessionStart = nil
    }

    mutating func undo() {
        if let last = history.popLast() { items = last }
    }
}

enum BoardDraftCheck {
    static func run() {
        var draft = BoardDraft()
        draft.change { $0.append(BoardItem(content: .sticker(.silk), center: CGPoint(x: 0.5, y: 0.5))) }
        assert(draft.items.count == 1 && draft.canUndo)
        draft.beginSession()
        draft.update { $0[0].scale = 2 }
        draft.update { $0[0].scale = 3 }
        draft.endSession()
        draft.undo()
        assert(draft.items[0].scale == 1)
        draft.beginSession()
        draft.endSession()
        draft.undo()
        assert(draft.items.isEmpty && !draft.canUndo)
    }
}

struct LiveTransform {
    typealias Value = SimultaneousGesture<SimultaneousGesture<DragGesture, MagnifyGesture>, RotateGesture>.Value

    var offset: CGSize = .zero
    var scale: CGFloat = 1
    var rotation: Angle = .zero

    init() {}

    init(_ value: Value) {
        offset = value.first?.first?.translation ?? .zero
        scale = value.first?.second?.magnification ?? 1
        rotation = value.second?.rotation ?? .zero
    }
}

// MARK: - Editor

struct BoardEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focus: BoardFocus?
    @State private var title = ""
    @State private var draft = BoardDraft()
    @State private var drawerOpen = false
    @State private var draggingID: UUID?
    @State private var dragLocation: CGPoint?
    @State private var boardSize: CGSize = .zero
    @State private var confirmDiscard = false
    @State private var added = 0
    @State private var undone = 0

    private var motion: Animation {
        reduceMotion ? .easeOut(duration: 0.18) : .spring(response: 0.34, dampingFraction: 1)
    }

    private var binCenter: CGPoint {
        CGPoint(x: boardSize.width / 2, y: boardSize.height - 110)
    }

    private var overBin: Bool {
        guard let dragLocation else { return false }
        return hypot(dragLocation.x - binCenter.x, dragLocation.y - binCenter.y) < 48
    }

    var body: some View {
        editor
            .background(StitchColor.cream)
            .interactiveDismissDisabled(!draft.items.isEmpty)
            .onAppear(perform: BoardDraftCheck.run)
    }

    private var editor: some View {
        VStack(spacing: 0) {
            topBar
            board
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $drawerOpen) {
            BoardDrawer(onPhoto: addPhoto, onSticker: addSticker)
                .presentationDetents([.medium, .large])
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .presentationDragIndicator(.visible)
        }
        .confirmationDialog("Discard this board?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard", role: .destructive) { dismiss() }
            Button("Keep editing", role: .cancel) {}
        }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: added)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: undone)
        .sensoryFeedback(.selection, trigger: overBin)
    }

    // MARK: Top bar

    private var topBar: some View {
        ZStack {
            TextField("Board title", text: $title, prompt: Text("Untitled").foregroundStyle(StitchColor.ink))
                .font(StitchFont.display(22))
                .foregroundStyle(StitchColor.ink)
                .multilineTextAlignment(.center)
                .focused($focus, equals: .title)
                .submitLabel(.done)
                .onSubmit { focus = nil }
                .padding(.horizontal, 72)
                .accessibilityHint("Rename the board")

            HStack {
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(StitchColor.ink)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Close")

                Spacer()

                Button(action: save) {
                    Text("Save")
                        .font(StitchFont.sans(16, weight: .semibold))
                        .foregroundStyle(draft.items.isEmpty ? StitchColor.muted : StitchColor.accent)
                        .frame(height: 44)
                        .padding(.horizontal, 6)
                        .contentShape(Rectangle())
                }
                .disabled(draft.items.isEmpty)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .frame(height: 52)
    }

    // MARK: Board

    private var board: some View {
        GeometryReader { geo in
            ZStack {
                StitchColor.slot
                    .contentShape(Rectangle())
                    .onTapGesture { focus = nil }

                if draft.items.isEmpty && !drawerOpen {
                    Text("Add photos, stickers or words")
                        .font(StitchFont.display(22))
                        .foregroundStyle(StitchColor.muted)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }

                ForEach(draft.items) { item in
                    BoardItemView(
                        item: item,
                        board: geo.size,
                        shrinking: draggingID == item.id && overBin,
                        onDrag: { location in
                            draggingID = item.id
                            dragLocation = location
                        },
                        onCommit: { live in commit(item.id, live, in: geo.size) },
                        onDelete: { delete(item.id) }
                    )
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.6).combined(with: .opacity))
                }

                if draggingID != nil {
                    bin
                        .position(binCenter)
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }
            .coordinateSpace(.named(BoardItemView.space))
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { boardSize = $0 }
        .overlay(alignment: .topTrailing) {
            if draggingID == nil {
                VStack(spacing: 10) {
                    floatingButton(drawerOpen ? "chevron.down" : "plus", label: drawerOpen ? "Close drawer" : "Add photos or stickers") {
                        withAnimation(motion) { drawerOpen.toggle() }
                    }
                }
                .padding(12)
                .transition(.opacity)
            }
        }
        .overlay(alignment: .topLeading) {
            if draft.canUndo && draggingID == nil {
                floatingButton("arrow.uturn.backward", label: "Undo", action: undo)
                    .padding(12)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .clipped()
        .ignoresSafeArea(edges: .bottom)
        .animation(motion, value: draggingID == nil)
        .animation(motion, value: overBin)
        .animation(motion, value: draft.canUndo)
    }

    private var bin: some View {
        Image(systemName: "trash")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(overBin ? StitchColor.cream : StitchColor.ink)
            .frame(width: 52, height: 52)
            .glassEffect(overBin ? Glass.regular.tint(StitchColor.accent) : Glass.regular, in: .circle)
            .scaleEffect(overBin && !reduceMotion ? 1.15 : 1)
            .accessibilityHidden(true)
    }

    private func floatingButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(StitchColor.ink)
                .frame(width: 36, height: 36)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .controlSize(.small)
        .accessibilityLabel(label)
    }

    // MARK: Actions

    private func close() {
        if draft.items.isEmpty { dismiss() } else { confirmDiscard = true }
    }

    private func save() {
        focus = nil
    }

    private func undo() {
        withAnimation(motion) { draft.undo() }
        undone += 1
    }

    private func add(_ content: BoardItem.Content) {
        // Fan new pieces out a little so a stack stays readable.
        let fan = CGFloat(draft.items.count % 5) - 2
        let item = BoardItem(
            content: content,
            center: CGPoint(x: 0.5 + fan * 0.04, y: 0.36 + fan * 0.03),
            rotation: .degrees(Double.random(in: -7...7))
        )
        withAnimation(motion) {
            draft.change { $0.append(item) }
            drawerOpen = false
        }
        added += 1
    }

    private func addPhoto(_ image: UIImage) {
        add(.photo(image))
    }

    private func addSticker(_ kind: StickerKind) {
        add(.sticker(kind))
    }

    private func delete(_ id: UUID) {
        withAnimation(motion) { draft.change { $0.removeAll { $0.id == id } } }
    }

    /// Commits the gesture without animation: the live transform and the model swap in the same frame.
    private func commit(_ id: UUID, _ live: LiveTransform, in size: CGSize) {
        let deleting = draggingID == id && overBin
        draggingID = nil
        dragLocation = nil
        if deleting { return delete(id) }
        guard size.width > 0, size.height > 0 else { return }
        draft.change { items in
            guard let index = items.firstIndex(where: { $0.id == id }) else { return }
            var item = items.remove(at: index)
            item.center.x = min(max(item.center.x + live.offset.width / size.width, 0), 1)
            item.center.y = min(max(item.center.y + live.offset.height / size.height, 0), 1)
            item.scale = min(max(item.scale * live.scale, 0.4), 4)
            item.rotation += live.rotation
            items.append(item)
        }
    }
}

enum BoardFocus: Hashable {
    case title
    case text
}

// MARK: - Items

private struct BoardItemView: View {
    static let space = "board"

    var item: BoardItem
    var board: CGSize
    var shrinking: Bool
    var onDrag: (CGPoint) -> Void
    var onCommit: (LiveTransform) -> Void
    var onDelete: () -> Void

    @GestureState private var live = LiveTransform()

    var body: some View {
        let unit = board.width / 360
        BoardItemContent(content: item.content)
            .simultaneousGesture(transform)
            .scaleEffect(item.scale * live.scale * unit * (shrinking ? 0.55 : 1))
            .rotationEffect(item.rotation + live.rotation)
            .opacity(shrinking ? 0.7 : 1)
            .position(
                x: item.center.x * board.width + live.offset.width,
                y: item.center.y * board.height + live.offset.height
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(item.accessibilityName)
            .accessibilityAction(named: "Delete", onDelete)
    }

    private var transform: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named(Self.space))
            .simultaneously(with: MagnifyGesture())
            .simultaneously(with: RotateGesture())
            .updating($live) { value, state, _ in state = LiveTransform(value) }
            .onChanged { value in
                if let drag = value.first?.first { onDrag(drag.location) }
            }
            .onEnded { value in onCommit(LiveTransform(value)) }
    }
}

struct BoardItemContent: View {
    var content: BoardItem.Content

    var body: some View {
        switch content {
        case .photo(let image): BoardPhoto(image: image)
        case .sticker(let kind): StickerView(kind: kind)
        }
    }
}

private struct BoardPhoto: View {
    var image: UIImage

    var body: some View {
        let ratio = min(max(image.size.height / max(image.size.width, 1), 0.7), 1.4)
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: 140, height: 140 * ratio)
            .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
            .padding(8)
            .padding(.bottom, 20)
            .background(StitchColor.paper, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(StitchColor.line, lineWidth: 1)
            }
            .shadow(color: StitchColor.ink.opacity(0.08), radius: 8, y: 4)
    }
}

/// Static board rendering, used for the save preview and exports.
struct BoardStage: View {
    var items: [BoardItem]

    var body: some View {
        GeometryReader { geo in
            let unit = geo.size.width / 360
            ZStack {
                StitchColor.slot
                ForEach(items) { item in
                    BoardItemContent(content: item.content)
                        .scaleEffect(item.scale * unit)
                        .rotationEffect(item.rotation)
                        .position(x: item.center.x * geo.size.width, y: item.center.y * geo.size.height)
                }
            }
        }
    }
}
