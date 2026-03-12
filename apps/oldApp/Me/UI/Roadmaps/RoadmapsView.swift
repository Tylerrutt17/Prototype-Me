import SwiftUI
import SwiftData
import Observation

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}

private struct FlashingBorder: ViewModifier {
    let active: Bool
    @State private var borderOpacity: Double = 1.0

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white, lineWidth: 4)
                    .opacity(active ? borderOpacity : 0)
            )
            .onAppear { startAnimation() }
            .onChange(of: active) { _ in startAnimation() }
    }

    private func startAnimation() {
        guard active else {
            borderOpacity = 1.0
            return
        }

        borderOpacity = 1.0
        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
            borderOpacity = 0.2
        }
    }
}

struct RoadmapDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var roadmap: Roadmap
    @State private var selectedNodeId: String? = nil
    @State private var isConnecting: Bool = false
    @State private var connectSourceId: String? = nil
    @State private var editingNode: RoadmapNode? = nil
    @State private var pendingDeleteNode: RoadmapNode? = nil
    @State private var showDeleteAlert: Bool = false
    @State private var zoomScale: CGFloat = 1.0
    @State private var baseScale: CGFloat = 1.0
    /// Logical canvas size for building the roadmap layout. Content is confined within this rect and a subtle border shows the bounds.
    private let canvasSize = CGSize(width: 1200, height: 1200)

    // Track viewport offset within the scroll view to render a minimap rectangle
    @State private var scrollOffset: CGPoint = .zero
    @State private var viewportSize: CGSize = .zero

    private var connectorsLayer: some View {
        Canvas { ctx, size in
            let nodes = roadmap.nodes ?? []
            for node in nodes {
                if let pid = node.parentId, let parent = nodes.first(where: { $0.id == pid }) {
                    let from = parent.position
                    let to = node.position
                    var path = Path()
                    path.move(to: from)
                    path.addLine(to: to)
                    ctx.stroke(path, with: .color(.accentColor), lineWidth: 2)
                }
            }
        }
    }

    private func nodeBubble(for node: RoadmapNode) -> some View {
        let baseColor = Color.named(node.colorName)
        return Text(node.title)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 8).fill(baseColor))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.3))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.blue, lineWidth: selectedNodeId == node.id ? 3 : 0)
            )
            .modifier(FlashingBorder(active: isConnecting && connectSourceId == node.id))
            .position(node.position)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Keep the node within the logical canvas bounds
                        let newX = value.location.x.clamped(to: 0...canvasSize.width)
                        let newY = value.location.y.clamped(to: 0...canvasSize.height)
                        node.position = CGPoint(x: newX, y: newY)
                    }
            )
            .onTapGesture {
                if isConnecting {
                    if node.id != connectSourceId,
                       let child = roadmap.nodes?.first(where: { $0.id == connectSourceId }) {
                        child.parentId = node.id
                    }
                    isConnecting = false
                }
                selectedNodeId = node.id
            }
            .onTapGesture(count: 2) {
                selectedNodeId = node.id
                editingNode = node
            }
    }

    var body: some View {
        GeometryReader { geo in
            let _ = DispatchQueue.main.async {
                viewportSize = geo.size
                // Sync from model once when view appears
                if zoomScale == 1.0 {
                    zoomScale = CGFloat(roadmap.zoomScale)
                    baseScale = zoomScale
                    // Scroll to stored offset after layout updates
                    DispatchQueue.main.async {
                        proxyScroll(to: CGPoint(x: roadmap.offsetX, y: roadmap.offsetY))
                    }
                }
            }
            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                ZStack {
                    connectorsLayer

                    ForEach(roadmap.nodes ?? []) { node in
                        nodeBubble(for: node)
                    }
                }
                .frame(width: canvasSize.width, height: canvasSize.height)
                .background(Color.gray.opacity(0.05))
                .border(Color.gray.opacity(0.3), width: 1)
                // Apply zoom only to the canvas content, not the surrounding ScrollView
                .scaleEffect(zoomScale, anchor: .topLeading)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            zoomScale = (baseScale * value).clamped(to: 0.5...3)
                        }
                        .onEnded { _ in
                            baseScale = zoomScale
                            saveViewportState()
                        }
                )
                // Track content position relative to the scroll view to update minimap
                .overlay(
                    GeometryReader { geo in
                        Color.clear
                            .preference(key: ScrollOffsetKey.self, value: geo.frame(in: .named("canvasScroll")).origin)
                    }
                )
            }
            .coordinateSpace(name: "canvasScroll")
            .onPreferenceChange(ScrollOffsetKey.self) { value in
                scrollOffset = CGPoint(x: -value.x, y: -value.y)
                saveViewportState()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Minimap overlay
            .overlay(alignment: .bottomTrailing) {
                minimap
                    .padding(8)
            }
            .navigationTitle(roadmap.name)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        addNode(in: geo.size)
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $editingNode) { node in
                RoadmapNodeEditorSheet(node: node)
                .presentationDetents([.large])
            }
            // Bottom action toolbar for selected node
            .safeAreaInset(edge: .bottom) {
                let selNode = selectedNodeId.flatMap { id in
                    roadmap.nodes?.first(where: { $0.id == id })
                }

                HStack {
                    Button {
                        guard let node = selNode else { return }
                        isConnecting.toggle()
                        connectSourceId = node.id
                    } label: {
                        Text("Link")
                            .font(.title2)
                    }
                    .disabled(selNode == nil)

                    // Extra spacing between Link and Unlink buttons
                    Spacer().frame(width: 32)

                    Button {
                        guard let node = selNode else { return }

                        // Remove parent link of selected node
                        node.parentId = nil

                        // Also remove links where selected node is the parent
                        roadmap.nodes?.forEach { child in
                            if child.parentId == node.id {
                                child.parentId = nil
                            }
                        }
                    } label: {
                        Text("Unlink")
                            .font(.title2)
                    }
                    .disabled(selNode == nil)

                    Spacer()

                    Button(role: .destructive) {
                        guard let node = selNode else { return }
                        pendingDeleteNode = node
                        showDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.title2)
                    }
                    .disabled(selNode == nil)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(.thinMaterial)
            }
            .alert("Delete Node", isPresented: $showDeleteAlert, actions: {
                Button("Delete", role: .destructive) {
                    if let node = pendingDeleteNode {
                        delete(node: node)
                        pendingDeleteNode = nil
                    }
                }
                Button("Cancel", role: .cancel) {
                    pendingDeleteNode = nil
                }
            }, message: {
                Text("Are you sure you want to delete this node? This action cannot be undone.")
            })
        }
    }

    private func addNode(in size: CGSize) {
        let count = (roadmap.nodes ?? []).count

        // Calculate the logical canvas point that represents the visual centre of the viewport
        let centreX = scrollOffset.x + viewportSize.width / 2 / zoomScale
        let centreY = scrollOffset.y + viewportSize.height / 2 / zoomScale
        var position = CGPoint(x: centreX, y: centreY)

        // If a node is selected, offset new node to the right of it
        if let selectedId = selectedNodeId,
           let selected = roadmap.nodes?.first(where: { $0.id == selectedId }) {
            position = CGPoint(x: selected.position.x + 150, y: selected.position.y)
        }

        // Keep within canvas bounds
        position.x = position.x.clamped(to: 0...canvasSize.width)
        position.y = position.y.clamped(to: 0...canvasSize.height)

        let new = RoadmapNode(title: "Step \(count + 1)", position: position)
        if roadmap.nodes == nil {
            roadmap.nodes = [new]
        } else {
            roadmap.nodes?.append(new)
        }
    }

    private func delete(node: RoadmapNode) {
        roadmap.nodes?.removeAll { $0.id == node.id }
        if selectedNodeId == node.id { selectedNodeId = nil }
        if editingNode?.id == node.id { editingNode = nil }
        if isConnecting { isConnecting = false }
    }

    // MARK: - Minimap

    private var minimap: some View {
        let mapSize: CGFloat = 100
        let scale: CGFloat = mapSize / canvasSize.width

        return Canvas { ctx, size in
            // Draw canvas border
            let borderRect = CGRect(origin: .zero, size: CGSize(width: canvasSize.width * scale, height: canvasSize.height * scale))
            ctx.stroke(Path(borderRect), with: .color(.gray.opacity(0.5)), lineWidth: 1)

            // Draw connectors
            for node in roadmap.nodes ?? [] {
                if let pid = node.parentId, let parent = roadmap.nodes?.first(where: { $0.id == pid }) {
                    var p = Path()
                    p.move(to: CGPoint(x: parent.position.x * scale, y: parent.position.y * scale))
                    p.addLine(to: CGPoint(x: node.position.x * scale, y: node.position.y * scale))
                    ctx.stroke(p, with: .color(.accentColor), lineWidth: 1)
                }
            }

            // Draw nodes as small rectangles
            for node in roadmap.nodes ?? [] {
                let rect = CGRect(x: node.position.x * scale - 2.5, y: node.position.y * scale - 2.5, width: 5, height: 5)
                ctx.fill(Path(rect), with: .color(Color.named(node.colorName)))
                ctx.stroke(Path(rect), with: .color(.primary), lineWidth: 0.5)
            }

            // Draw viewport rectangle
            let viewWidth = viewportSize.width / zoomScale
            let viewHeight = viewportSize.height / zoomScale
            let viewportRect = CGRect(
                x: scrollOffset.x * scale,
                y: scrollOffset.y * scale,
                width: viewWidth * scale,
                height: viewHeight * scale
            ).intersection(borderRect)
            ctx.stroke(Path(viewportRect), with: .color(.blue.opacity(0.7)), lineWidth: 1)
        }
        .frame(width: mapSize, height: mapSize)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // PreferenceKey for capturing scroll offset
    private struct ScrollOffsetKey: PreferenceKey {
        static var defaultValue: CGPoint { .zero }
        static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {
            value = nextValue()
        }
    }

    // Helpers
    private func saveViewportState() {
        roadmap.zoomScale = Double(zoomScale)
        roadmap.offsetX = Double(scrollOffset.x)
        roadmap.offsetY = Double(scrollOffset.y)
    }

    private func proxyScroll(to point: CGPoint) {
        // placeholder: ScrollViewReader proxy removal earlier removed scrollViewProxy; so ignore for now
    }
}

#Preview {
    do {
        let container = try! ModelContainer(for: Roadmap.self, RoadmapNode.self)
        var rm = Roadmap(name: "Preview")
        rm.nodes = [
            RoadmapNode(title: "A", position: CGPoint(x: 80, y: 80)),
            RoadmapNode(title: "B", position: CGPoint(x: 200, y: 200))
        ]
        container.mainContext.insert(rm)

        return NavigationStack {
            RoadmapDetailView(roadmap: rm)
        }
        .modelContainer(container)
    }
}
