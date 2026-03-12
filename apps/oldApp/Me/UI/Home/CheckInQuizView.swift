import SwiftUI
import SwiftData

struct CheckInQuizView: View {
    let trackables: [Trackable]
    @Binding var levels: [String: Int]
    @Environment(\.dismiss) private var dismiss
    @State private var page = 0

    private let numberFormatter: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .none
        return nf
    }()

    var body: some View {
        NavigationStack {
            TabView(selection: $page) {
                ForEach(Array(trackables.enumerated()), id: \.1.id) { idx, trackable in
                    VStack(spacing: 32) {
                        Text(trackable.name)
                            .font(.largeTitle).bold()
                        slider(for: trackable)
                        Spacer()
                        Button(idx == trackables.count - 1 ? "Done" : "Next") {
                            if idx == trackables.count - 1 {
                                dismiss()
                            } else {
                                withAnimation { page = min(page + 1, trackables.count - 1) }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .navigationTitle("Daily Quiz")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }

    private func slider(for trackable: Trackable) -> some View {
        let valueBinding = Binding<Double>(
            get: { Double(levels[trackable.id] ?? trackable.defaultValue) },
            set: { levels[trackable.id] = Int($0) }
        )

        return VStack {
            Slider(value: valueBinding,
                   in: Double(trackable.min)...Double(trackable.max),
                   step: 1)
                .tint(Color.named(trackable.colorName))
            Text(numberFormatter.string(from: NSNumber(value: Int(valueBinding.wrappedValue))) ?? "0")
                .font(.title2)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    let container = try! ModelContainer(for: Trackable.self)
    let context = ModelContext(container)
    let sample = Trackable(name: "Energy")
    context.insert(sample)
    return CheckInQuizView(trackables: [sample], levels: .constant([sample.id: 5]))
}
