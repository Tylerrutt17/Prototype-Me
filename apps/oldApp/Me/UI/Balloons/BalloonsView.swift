import SwiftUI
import SwiftData

/// Dedicated view for visualizing active countdown balloons and a swipe-up list of expiring directives.
struct BalloonsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Intervention> { $0.countdownEnabled == true }) private var countdowns: [Intervention]

    @State private var sheetState: SheetState = .collapsed
    @State private var dragOffset: CGFloat = 0
    @State private var navPath = NavigationPath()
    @State private var sheetContentHeight: CGFloat = 0
    @State private var hoveredId: String? = nil
    @State private var pressedId: String? = nil

    private enum SheetState {
        case collapsed, expanded

        func offset(for height: CGFloat) -> CGFloat {
            switch self {
            case .collapsed: return max(height * 0.62, 260) // leave most of the sky visible
            case .expanded: return max(height * 0.16, 96)   // pulled mostly into view
            }
        }
    }

    var body: some View {
        NavigationStack(path: $navPath) {
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                let items = balloonItems(at: timeline.date)
                let maxRemaining = max(items.map(\.remaining).max() ?? 1, 1)
                GeometryReader { geo in
                    let sheetMetrics = sheetLayout(for: geo.size.height)
                    let groundY = geo.size.height - (sheetMetrics.sheetHeight - sheetMetrics.collapsedOffset)
                    ZStack(alignment: .bottom) {
                        skyBackground
                        balloonField(items: items,
                                     size: geo.size,
                                     time: timeline.date.timeIntervalSinceReferenceDate,
                                     groundY: groundY,
                                     maxRemaining: maxRemaining)
                        bottomSheet(items: items, height: geo.size.height, metrics: sheetMetrics, maxRemaining: maxRemaining)
                    }
                    .ignoresSafeArea(edges: .bottom)
                }
            }
            .navigationTitle("Balloons")
            .navigationBarTitleDisplayMode(.inline) // keep title fixed so list scrolling doesn’t bounce it
            .navigationDestination(for: String.self) { id in
                if let iv = try? modelContext.fetch(FetchDescriptor<Intervention>(predicate: #Predicate { $0.id == id })).first {
                    InterventionEditorView(intervention: iv)
                } else {
                    Text("Directive not found").foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Balloon data
    private func balloonItems(at date: Date) -> [BalloonItem] {
        countdowns
            .map { iv in
                let progress = max(0, min(1, iv.countdownProgress(reference: date) ?? 0))
                let remaining = iv.countdownRemaining(reference: date) ?? 0
                let resetAt = iv.countdownResetAt
                let waiting = (resetAt ?? date) > date && remaining <= 0

                return BalloonItem(intervention: iv,
                                   progress: progress,
                                   remaining: remaining,
                                   resetAt: resetAt,
                                   isWaiting: waiting)
            }
            .sorted { lhs, rhs in
                let lCategory = category(for: lhs)
                let rCategory = category(for: rhs)

                if lCategory != rCategory {
                    return lCategory.rawValue < rCategory.rawValue
                }

                switch lCategory {
                case .expired, .active:
                    return lhs.remaining < rhs.remaining
                case .waiting:
                    if let lreset = lhs.resetAt, let rreset = rhs.resetAt {
                        return lreset < rreset
                    }
                    return lhs.remaining < rhs.remaining
                }
            }
    }

    private enum BalloonCategory: Int {
        case expired = 0   // show at the top
        case active = 1
        case waiting = 2   // sit after actives
    }

    private func category(for item: BalloonItem) -> BalloonCategory {
        if item.isWaiting { return .waiting }
        if item.remaining <= 0 { return .expired }
        return .active
    }

    // MARK: - Layout
    private func balloonField(items: [BalloonItem], size: CGSize, time: TimeInterval, groundY: CGFloat, maxRemaining: TimeInterval) -> some View {
        ZStack(alignment: .bottom) {
            if items.isEmpty {
                emptyState
            } else {
                ForEach(Array(items.enumerated()), id: \.1.id) { idx, item in
                    let x = xPosition(for: idx, total: items.count, width: size.width)
                    let y = yPosition(for: item, maxRemaining: maxRemaining, groundY: groundY, height: size.height)
                    let color = timeColor(for: item, maxRemaining: maxRemaining)
                    Button {
                        navPath.append(item.intervention.id)
                    } label: {
                        BalloonShapeView(item: item, phase: time, index: idx, color: color)
                            .scaleEffect(scaleFor(item: item))
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.01, maximumDistance: 80)
                            .onChanged { _ in pressedId = item.id }
                            .onEnded { _ in pressedId = nil }
                    )
#if os(macOS) || targetEnvironment(macCatalyst)
                    .onHover { hovering in
                        hoveredId = hovering ? item.id : nil
                    }
#endif
                    .position(x: x, y: y)
                    .animation(.easeInOut(duration: 0.6), value: item.progress)
                }
            }

        }
    }

    private var skyBackground: some View {
        LinearGradient(colors: [
            Color.blue.opacity(0.28),
            Color.indigo.opacity(0.24),
            Color.cyan.opacity(0.18)
        ], startPoint: .top, endPoint: .bottom)
        .overlay(
            RadialGradient(colors: [Color.white.opacity(0.18), .clear],
                           center: .topLeading,
                           startRadius: 40,
                           endRadius: 280)
        )
        .ignoresSafeArea()
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "balloon")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No balloons yet")
                .foregroundStyle(.secondary)
            Text("Turn on countdowns in a directive to see it here.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func xPosition(for index: Int, total: Int, width: CGFloat) -> CGFloat {
        guard total > 0 else { return width / 2 }
        let spacing = width / CGFloat(total + 1)
        let jitter = CGFloat((index * 37) % 18) - 9 // mild horizontal variance
        return spacing * CGFloat(index + 1) + jitter
    }

    private func yPosition(for item: BalloonItem, maxRemaining: TimeInterval, groundY: CGFloat, height: CGFloat) -> CGFloat {
        let top = height * 0.18
        let bottom = max(top + 40, groundY - 12)

        // Waiting or empty balloons sit low near the ground
        if item.isWaiting || item.remaining <= 0 {
            return bottom - 8
        }

        let normalized = item.remaining / maxRemaining
        let clamped = max(0.02, min(1.0, normalized))
        return bottom - (bottom - top) * clamped
    }

    private func scaleFor(item: BalloonItem) -> CGFloat {
        if pressedId == item.id || hoveredId == item.id {
            return 1.08
        }
        return 1.0
    }

    private func timeColor(for item: BalloonItem, maxRemaining: TimeInterval) -> Color {
        if item.isWaiting || item.remaining <= 0 {
            return Color.red
        }
        let ratio = max(0.0, min(1.0, item.remaining / maxRemaining))
        // Ease to emphasize urgency near the ground
        let eased = pow(ratio, 0.65)
        let hueStart: Double = 0.33 // green
        let hueEnd: Double = 0.0   // red
        let hue = hueEnd + (hueStart - hueEnd) * eased
        return Color(hue: hue, saturation: 0.85, brightness: 0.95)
    }

    // MARK: - Bottom sheet
    private struct SheetMetrics {
        let sheetHeight: CGFloat
        let collapsedOffset: CGFloat
        let expandedOffset: CGFloat
    }

    private func sheetLayout(for screenHeight: CGFloat) -> SheetMetrics {
        let sheetHeight = max(sheetContentHeight, 180)
        let peek: CGFloat = min(140, max(96, sheetHeight * 0.32)) // visible strip when collapsed
        let collapsedOffset = max(sheetHeight - peek, 0)
        let expandedOffset: CGFloat = 0
        return SheetMetrics(sheetHeight: sheetHeight,
                            collapsedOffset: collapsedOffset,
                            expandedOffset: expandedOffset)
    }

    private func bottomSheet(items: [BalloonItem], height: CGFloat, metrics: SheetMetrics, maxRemaining: TimeInterval) -> some View {
        let base = sheetState == .collapsed ? metrics.collapsedOffset : metrics.expandedOffset
        let clampedOffset = max(metrics.expandedOffset, min(metrics.collapsedOffset, base + dragOffset))

        return VStack(spacing: 12) {
            Capsule()
                .fill(Color.secondary.opacity(0.7))
                .frame(width: 44, height: 5)
                .padding(.top, 6)

            HStack {
                Text("Expiring soon")
                    .font(.headline)
                Spacer()
                if !items.isEmpty {
                    Text("\(items.count)")
                        .font(.caption).bold()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.primary.opacity(0.08), in: Capsule())
                }
            }
            .padding(.horizontal, 4)

            if items.isEmpty {
                Text("No countdowns are running right now.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 12)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(items) { item in
                            let color = timeColor(for: item, maxRemaining: maxRemaining)
                            NavigationLink(value: item.intervention.id) {
                                sheetRow(for: item, color: color)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 16)
                }
                .allowsHitTesting(sheetState == .expanded)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: SheetHeightKey.self, value: proxy.size.height)
            }
        )
        .onPreferenceChange(SheetHeightKey.self) { newValue in
            // Smoothly capture intrinsic height of the sheet content
            sheetContentHeight = newValue
        }
        .contentShape(Rectangle()) // keep the drag area active even when content is disabled
        .offset(y: clampedOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation.height
                }
                .onEnded { value in
                    let predicted = base + value.predictedEndTranslation.height
                    let midpoint = (metrics.collapsedOffset + metrics.expandedOffset) / 2
                    sheetState = predicted < midpoint ? .expanded : .collapsed
                    dragOffset = 0
                }
        )
        .animation(.interactiveSpring(response: 0.32, dampingFraction: 0.88), value: sheetState)
        .animation(.easeOut(duration: 0.2), value: dragOffset)
    }

    private func sheetRow(for item: BalloonItem, color: Color) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color.opacity(0.9))
                .frame(width: 12, height: 12)
                .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.intervention.title.isEmpty ? "Untitled" : item.intervention.title)
                    .font(.headline)
                    .lineLimit(2)
                Text(statusText(for: item))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            ProgressRing(progress: item.progress,
                         color: color,
                         isWaiting: item.isWaiting)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground).opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func statusText(for item: BalloonItem) -> String {
        if item.isWaiting, let reset = item.resetAt {
            return "Resets at \(Self.timeFormatter.string(from: reset))"
        }
        if item.remaining <= 0 {
            return "Empty — pump to refill"
        }
        return "Expires in \(durationString(for: item.remaining))"
    }

    private func durationString(for interval: TimeInterval) -> String {
        if interval <= 0 { return "Now" }
        let days = Int(interval / 86_400)
        let hours = Int(interval.truncatingRemainder(dividingBy: 86_400) / 3_600)
        let minutes = Int(interval.truncatingRemainder(dividingBy: 3_600) / 60)
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    // MARK: - Types
    private struct BalloonItem: Identifiable {
        let id: String
        let intervention: Intervention
        let progress: Double
        let remaining: TimeInterval
        let resetAt: Date?
        let isWaiting: Bool

        init(intervention: Intervention,
             progress: Double,
             remaining: TimeInterval,
             resetAt: Date?,
             isWaiting: Bool) {
            self.id = intervention.id
            self.intervention = intervention
            self.progress = progress
            self.remaining = remaining
            self.resetAt = resetAt
            self.isWaiting = isWaiting
        }
    }

    private struct BalloonShapeView: View {
        let item: BalloonItem
        let phase: TimeInterval
        let index: Int
        let color: Color

        var body: some View {
            VStack(spacing: 2) {
                ZStack {
                    Circle()
                        .fill(balloonGradient)
                    Circle()
                        .stroke(.white.opacity(0.22), lineWidth: 2)
                    VStack(spacing: 4) {
                        Text(item.intervention.title.isEmpty ? "Untitled" : item.intervention.title)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .foregroundStyle(.white)
                        Text(centerLabel)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .padding(10)
                }
                .frame(width: 110, height: 110)
                .shadow(color: color.opacity(0.4), radius: 10, x: 0, y: 6)

                BalloonKnot(color: color)
                    .offset(y: -4) // tuck the knot into the balloon base

                Rectangle()
                    .fill(.white.opacity(0.7))
                    .frame(width: 2, height: 32)
                    .offset(y: -6) // attach string closer to the knot
                    .overlay(waveOverlay)
            }
            .offset(y: bobOffset)
        }

        private var balloonGradient: LinearGradient {
            LinearGradient(colors: [
                color.opacity(0.95),
                color.opacity(0.65)
            ], startPoint: .top, endPoint: .bottom)
        }

        private var centerLabel: String {
            if item.isWaiting {
                return "waiting"
            }
            if item.remaining <= 0 {
                return "empty"
            }
            let hours = Int(item.remaining / 3_600)
            let minutes = Int(item.remaining.truncatingRemainder(dividingBy: 3_600) / 60)
            if hours > 0 { return "\(hours)h \(minutes)m" }
            return "\(max(minutes, 1))m"
        }

        private var bobOffset: CGFloat {
            CGFloat(sin(phase / 2.4 + Double(index)) * 6)
        }

        private var waveOverlay: some View {
            Rectangle()
                .fill(
                    LinearGradient(colors: [.white.opacity(0.25), .clear],
                                   startPoint: .top,
                                   endPoint: .bottom)
                )
        }
    }

    private struct BalloonKnot: View {
        let color: Color

        var body: some View {
            Triangle()
                .fill(color.opacity(0.9))
                .frame(width: 22, height: 16)
                .overlay(
                    Triangle()
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
        }
    }

    private struct Triangle: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
            return path
        }
    }

    private struct ProgressRing: View {
        let progress: Double
        let color: Color
        let isWaiting: Bool

        var body: some View {
            ZStack {
                Circle()
                    .stroke(Color(.systemGray4), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: CGFloat(max(0.02, progress)))
                    .stroke(color.gradient,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(label)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.primary)
            }
            .frame(width: 46, height: 46)
        }

        private var label: String {
            if isWaiting { return "wait" }
            return "\(Int(progress * 100))%"
        }
    }

    private static let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.timeStyle = .short
        return df
    }()

    private struct SheetHeightKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = max(value, nextValue())
        }
    }
}

