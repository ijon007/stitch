import SwiftUI
import UIKit

// MARK: - Model

struct BoardItem: Identifiable, Equatable {
    enum Content: Equatable {
        case photo(UIImage, PhotoFrame)
        case sticker(StickerKind)
        case text(BoardText)
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
        case .text(let text): text.string.isEmpty ? "Text" : text.string
        }
    }

    var text: BoardText? {
        if case .text(let text) = content { return text }
        return nil
    }
}

struct BoardText: Equatable {
    var string = ""
    var font: BoardFont = .editorial
    var style: BoardTextStyle = .plain
    var bold = false
    var italic = false
    var underline = false

    var isBlank: Bool { string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

enum BoardFont: String, CaseIterable, Identifiable {
    case editorial, clean, classic, round, mono

    var id: String { rawValue }

    var name: String {
        switch self {
        case .editorial: "Editorial"
        case .clean: "Clean"
        case .classic: "Classic"
        case .round: "Round"
        case .mono: "Mono"
        }
    }

    func font(_ size: CGFloat) -> Font {
        switch self {
        case .editorial: StitchFont.display(size)
        case .clean: StitchFont.sans(size, weight: .medium)
        case .classic: .system(size: size, design: .serif)
        case .round: .system(size: size, weight: .semibold, design: .rounded)
        case .mono: .system(size: size, weight: .medium, design: .monospaced)
        }
    }
}

enum BoardTextStyle: CaseIterable {
    case plain, label, silk, tape

    var name: String {
        switch self {
        case .plain: "Plain"
        case .label: "Label"
        case .silk: "Silk"
        case .tape: "Tape"
        }
    }

    var ink: Color {
        switch self {
        case .plain, .label: StitchColor.ink
        case .silk: StitchColor.accent
        case .tape: StitchColor.cream
        }
    }

    var fill: Color? {
        switch self {
        case .plain: nil
        case .label: StitchColor.paper
        case .silk: StitchColor.silk
        case .tape: StitchColor.accent
        }
    }

    var next: BoardTextStyle {
        let all = Self.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
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
        assert(BoardTextStyle.tape.next == .plain)
        assert(PhotoFrame.plain.next == .polaroid)
    }
}

enum PhotoFrame: String, CaseIterable, Identifiable {
    case plain, polaroid

    var id: String { rawValue }

    var name: String {
        switch self {
        case .plain: "Plain"
        case .polaroid: "Polaroid"
        }
    }

    var next: PhotoFrame {
        let all = Self.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
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
    @State private var editingID: UUID?
    @State private var draggingID: UUID?
    @State private var dragLocation: CGPoint?
    @State private var boardSize: CGSize = .zero
    @State private var confirmDiscard = false
    @State private var export: BoardExport?
    @State private var added = 0
    @State private var undone = 0

    private var motion: Animation {
        reduceMotion ? .easeOut(duration: 0.18) : .spring(response: 0.34, dampingFraction: 1)
    }

    private var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled" : trimmed
    }

    private func slide(fromTrailing: Bool) -> AnyTransition {
        if reduceMotion { return .opacity }
        return .offset(x: fromTrailing ? 28 : -28).combined(with: .opacity)
    }

    private var binCenter: CGPoint {
        CGPoint(x: boardSize.width / 2, y: boardSize.height - 110)
    }

    private var overBin: Bool {
        guard let dragLocation else { return false }
        return hypot(dragLocation.x - binCenter.x, dragLocation.y - binCenter.y) < 48
    }

    var body: some View {
        ZStack {
            if let export {
                SaveBoardView(
                    title: displayTitle,
                    items: draft.items,
                    aspect: boardSize.width / max(boardSize.height, 1),
                    export: export,
                    onBack: { withAnimation(motion) { self.export = nil } },
                    onDone: { dismiss() }
                )
                .transition(slide(fromTrailing: true))
            } else {
                ZStack(alignment: .bottom) {
                    editor
                    if let editingID {
                        if draft.items.first(where: { $0.id == editingID })?.text != nil {
                            TextStyleBar(text: textBinding(editingID))
                                .padding(.bottom, 12)
                                .transition(.opacity.combined(with: .offset(y: reduceMotion ? 0 : 10)))
                        } else if let frame = photoFrameBinding(editingID) {
                            PhotoStyleBar(frame: frame)
                                .padding(.bottom, 12)
                                .transition(.opacity.combined(with: .offset(y: reduceMotion ? 0 : 10)))
                        }
                    }
                }
                .animation(motion, value: editingID)
                .transition(slide(fromTrailing: false))
            }
        }
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
            BoardDrawer(onAdd: add)
                .presentationDetents([.medium, .large])
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .presentationDragIndicator(.visible)
                .presentationBackground(StitchColor.background)
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

                if editingID != nil {
                    Button(action: endEditing) {
                        Text("Done")
                            .font(StitchFont.sans(16, weight: .semibold))
                            .foregroundStyle(StitchColor.ink)
                            .frame(height: 44)
                            .padding(.horizontal, 6)
                            .contentShape(Rectangle())
                    }
                    .accessibilityHint("Finish editing")
                } else {
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
                    .onTapGesture {
                        focus = nil
                        endEditing()
                    }

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
                        editing: item.id == editingID && item.text != nil ? textBinding(item.id) : nil,
                        focus: $focus,
                        selected: item.id == editingID,
                        dimmed: editingID != nil && item.id != editingID,
                        shrinking: draggingID == item.id && overBin,
                        onTap: { beginEditing(item) },
                        onDrag: { location in
                            if drawerOpen { withAnimation(motion) { drawerOpen = false } }
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
            if draggingID == nil && editingID == nil {
                VStack(spacing: 10) {
                    floatingButton(drawerOpen ? "chevron.down" : "plus", label: drawerOpen ? "Close drawer" : "Add photos or stickers") {
                        withAnimation(motion) { drawerOpen.toggle() }
                    }
                    Button(action: addText) {
                        Text("T")
                            .font(StitchFont.sans(17, weight: .semibold))
                            .foregroundStyle(StitchColor.ink)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .controlSize(.small)
                    .accessibilityLabel("Add text")
                }
                .padding(12)
                .transition(.opacity)
            }
        }
        .overlay(alignment: .topLeading) {
            if draft.canUndo && draggingID == nil && editingID == nil {
                floatingButton("arrow.uturn.backward", label: "Undo", action: undo)
                    .padding(12)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .clipped()
        .ignoresSafeArea(edges: .bottom)
        .animation(motion, value: draggingID == nil)
        .animation(motion, value: editingID == nil)
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
        endEditing()
        focus = nil
        let rendered = BoardExport.render(title: displayTitle, items: draft.items, aspect: boardSize.width / max(boardSize.height, 1))
        withAnimation(motion) { export = rendered }
    }

    private func addText() {
        endEditing()
        let item = BoardItem(content: .text(BoardText()), center: CGPoint(x: 0.5, y: 0.3))
        draft.beginSession()
        withAnimation(motion) {
            draft.update { $0.append(item) }
            drawerOpen = false
        }
        editingID = item.id
        added += 1
    }

    private func beginEditing(_ item: BoardItem) {
        guard item.id != editingID else { return }
        endEditing()
        switch item.content {
        case .text:
            draft.beginSession()
            editingID = item.id
        case .photo:
            draft.beginSession()
            editingID = item.id
        case .sticker:
            break
        }
    }

    /// Drops text left blank, then folds the whole edit into a single undo step.
    private func endEditing() {
        guard let id = editingID else { return }
        withAnimation(motion) {
            draft.update { $0.removeAll { $0.id == id && $0.text?.isBlank == true } }
            editingID = nil
        }
        draft.endSession()
        focus = nil
    }

    private func textBinding(_ id: UUID) -> Binding<BoardText> {
        Binding(
            get: { draft.items.first { $0.id == id }?.text ?? BoardText() },
            set: { text in
                draft.update { items in
                    if let index = items.firstIndex(where: { $0.id == id }) { items[index].content = .text(text) }
                }
            }
        )
    }

    private func undo() {
        withAnimation(motion) { draft.undo() }
        undone += 1
    }

    private func add(_ contents: [BoardItem.Content]) {
        guard !contents.isEmpty else { return }
        // Fan new pieces out a little so a stack stays readable.
        withAnimation(motion) {
            draft.change { items in
                for content in contents {
                    let fan = CGFloat(items.count % 5) - 2
                    items.append(BoardItem(
                        content: content,
                        center: CGPoint(x: 0.5 + fan * 0.04, y: 0.36 + fan * 0.03),
                        rotation: .degrees(Double.random(in: -7...7))
                    ))
                }
            }
            drawerOpen = false
        }
        added += contents.count
    }

    private func photoFrameBinding(_ id: UUID) -> Binding<PhotoFrame>? {
        guard case .photo = draft.items.first(where: { $0.id == id })?.content else { return nil }
        return Binding(
            get: {
                if case .photo(_, let frame) = draft.items.first(where: { $0.id == id })?.content { return frame }
                return .plain
            },
            set: { frame in
                draft.update { items in
                    guard let index = items.firstIndex(where: { $0.id == id }),
                          case .photo(let image, _) = items[index].content else { return }
                    items[index].content = .photo(image, frame)
                }
            }
        )
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
    var editing: Binding<BoardText>?
    var focus: FocusState<BoardFocus?>.Binding
    var selected: Bool
    var dimmed: Bool
    var shrinking: Bool
    var onTap: () -> Void
    var onDrag: (CGPoint) -> Void
    var onCommit: (LiveTransform) -> Void
    var onDelete: () -> Void

    @GestureState private var live = LiveTransform()

    var body: some View {
        let unit = board.width / 360
        // Text being edited lifts clear of the keyboard, then settles back.
        let y = editing == nil ? item.center.y : min(item.center.y, 0.3)
        visual
            .gesture(TapGesture().onEnded { onTap() }, isEnabled: editing == nil)
            .simultaneousGesture(transform, isEnabled: editing == nil && !dimmed)
            .scaleEffect(item.scale * live.scale * unit * (shrinking ? 0.55 : 1))
            .rotationEffect(item.rotation + live.rotation)
            .opacity(dimmed ? 0.35 : shrinking ? 0.7 : 1)
            .position(
                x: item.center.x * board.width + live.offset.width,
                y: y * board.height + live.offset.height
            )
            .accessibilityLabel(item.accessibilityName)
            .accessibilityAction(named: "Delete", onDelete)
    }

    @ViewBuilder
    private var visual: some View {
        if let editing {
            TextEditingField(text: editing, focus: focus)
        } else {
            BoardItemContent(content: item.content)
                .padding(selected ? 4 : 0)
                .overlay {
                    if selected {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(StitchColor.accent, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityAddTraits(selected ? [.isSelected] : [])
        }
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
        case .photo(let image, let frame): BoardPhoto(image: image, frame: frame)
        case .sticker(let kind): StickerView(kind: kind)
        case .text(let text):
            Text(text.string)
                .boardGlyphs(text)
                .frame(maxWidth: 280)
                .fixedSize()
                .boardChip(text.style)
        }
    }
}

private struct TextEditingField: View {
    @Binding var text: BoardText
    var focus: FocusState<BoardFocus?>.Binding

    var body: some View {
        // The hidden Text sizes the field so it hugs and wraps like the finished label.
        Text(text.string.isEmpty ? "Type something" : text.string + " ")
            .boardGlyphs(text)
            .frame(maxWidth: 280)
            .fixedSize()
            .opacity(0)
            .overlay {
                TextField("Type something", text: $text.string, axis: .vertical)
                    .boardGlyphs(text)
                    .tint(text.style == .tape ? StitchColor.cream : StitchColor.accent)
                    .focused(focus, equals: .text)
                    .onAppear { focus.wrappedValue = .text }
            }
            .boardChip(text.style)
    }
}

private extension View {
    func boardGlyphs(_ text: BoardText) -> some View {
        font(text.font.font(28))
            .bold(text.bold)
            .italic(text.italic)
            .underline(text.underline)
            .foregroundStyle(text.style.ink)
            .multilineTextAlignment(.center)
    }

    func boardChip(_ style: BoardTextStyle) -> some View {
        padding(.horizontal, style.fill == nil ? 4 : 14)
            .padding(.vertical, style.fill == nil ? 2 : 8)
            .background(style.fill ?? .clear, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                if style == .label {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(StitchColor.line, lineWidth: 1)
                }
            }
    }
}

// MARK: - Text style bar

private struct TextStyleBar: View {
    @Binding var text: BoardText
    @State private var taps = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView(.horizontal) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    Button {
                        apply { $0.style = $0.style.next }
                    } label: {
                        Text("A")
                            .font(StitchFont.display(18, weight: .medium))
                            .foregroundStyle(text.style.ink)
                            .frame(width: 26, height: 26)
                            .background(text.style.fill ?? .clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                            .overlay {
                                if text.style.fill == nil || text.style == .label {
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .stroke(StitchColor.dash, lineWidth: 1)
                                }
                            }
                            .frame(width: 44, height: 44)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .accessibilityLabel("Text style, \(text.style.name)")

                    toggle("bold", label: "Bold", isOn: text.bold) { $0.bold.toggle() }
                    toggle("italic", label: "Italic", isOn: text.italic) { $0.italic.toggle() }
                    toggle("underline", label: "Underline", isOn: text.underline) { $0.underline.toggle() }

                    Capsule()
                        .fill(StitchColor.dash)
                        .frame(width: 1, height: 22)
                        .padding(.horizontal, 4)
                        .accessibilityHidden(true)

                    ForEach(BoardFont.allCases) { font in
                        let isOn = text.font == font
                        Button {
                            apply { $0.font = font }
                        } label: {
                            Text(font.name)
                                .font(font.font(16))
                                .foregroundStyle(isOn ? StitchColor.cream : StitchColor.ink)
                                .padding(.horizontal, 16)
                                .frame(height: 44)
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .glassEffect(isOn ? Glass.regular.tint(StitchColor.ink).interactive() : Glass.regular.interactive(), in: .capsule)
                        .accessibilityLabel("Font, \(font.name)")
                        .accessibilityAddTraits(isOn ? [.isSelected] : [])
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .sensoryFeedback(.selection, trigger: taps)
    }

    private func toggle(_ symbol: String, label: String, isOn: Bool, edit: @escaping (inout BoardText) -> Void) -> some View {
        Button {
            apply(edit)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isOn ? StitchColor.cream : StitchColor.ink)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(isOn ? Glass.regular.tint(StitchColor.ink).interactive() : Glass.regular.interactive(), in: .circle)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    private func apply(_ edit: (inout BoardText) -> Void) {
        withAnimation(reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.3, dampingFraction: 1)) {
            edit(&text)
        }
        taps += 1
    }
}

private struct PhotoStyleBar: View {
    @Binding var frame: PhotoFrame
    @State private var taps = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(PhotoFrame.allCases) { option in
                    let isOn = frame == option
                    Button {
                        withAnimation(reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.3, dampingFraction: 1)) {
                            frame = option
                        }
                        taps += 1
                    } label: {
                        Text(option.name)
                            .font(StitchFont.sans(16, weight: .semibold))
                            .foregroundStyle(isOn ? StitchColor.cream : StitchColor.ink)
                            .padding(.horizontal, 16)
                            .frame(height: 44)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .glassEffect(isOn ? Glass.regular.tint(StitchColor.ink).interactive() : Glass.regular.interactive(), in: .capsule)
                    .accessibilityLabel("Photo style, \(option.name)")
                    .accessibilityAddTraits(isOn ? [.isSelected] : [])
                }
            }
            .padding(.horizontal, 16)
        }
        .sensoryFeedback(.selection, trigger: taps)
    }
}

private struct BoardPhoto: View {
    var image: UIImage
    var frame: PhotoFrame

    var body: some View {
        let ratio = min(max(image.size.height / max(image.size.width, 1), 0.7), 1.4)
        let photo = Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: 140, height: 140 * ratio)
            .clipShape(RoundedRectangle(cornerRadius: frame == .polaroid ? 2 : 8, style: .continuous))

        switch frame {
        case .plain:
            photo
        case .polaroid:
            photo
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
