import SwiftUI

struct MapNavigationBanner: View {
    let instructions: [MapNavigationViewModel.Instruction]
    @Binding var currentIndex: Int

    var body: some View {
        TabView(selection: $currentIndex) {
            ForEach(Array(instructions.enumerated()), id: \.element.id) { index, instruction in
                instructionPage(instruction)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 96)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Navigation instructions")
        .accessibilityHint("Swipe left or right to change instruction")
    }

    private func instructionPage(_ instruction: MapNavigationViewModel.Instruction) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: instruction.systemImage)
                .font(Font.Brand.largeTitle)
                .foregroundStyle(Color.Brand.labelPrimary)
                .frame(width: 72, height: 72)
                .background(Color.Brand.labelPrimary.opacity(0.2), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: "%.0f km", instruction.distanceKm))
                    .font(Font.Brand.title2Bold)
                    .foregroundStyle(Color.primary)

                Text(instruction.text)
                    .font(Font.Brand.title2)
                    .foregroundStyle(Color.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                if instructions.count > 1 {
                    HStack(spacing: 4) {
                        ForEach(0..<instructions.count, id: \.self) { index in
                            Circle()
                                .fill(
                                    index == currentIndex
                                        ? Color.Brand.labelPrimary
                                        : Color.Brand.labelPrimary.opacity(0.2)
                                )
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.top, 6)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

#Preview {
    MapNavigationBanner(
        instructions: [
            .init(distanceKm: 3, text: "Turn left onto Jalan Damai Foresta", systemImage: "arrow.turn.up.left"),
            .init(distanceKm: 1.2, text: "Continue straight", systemImage: "arrow.up"),
            .init(distanceKm: 0.8, text: "Keep right", systemImage: "arrow.turn.up.right")
        ],
        currentIndex: .constant(0)
    )
    .padding()
}
