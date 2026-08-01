import SwiftUI

/// Der Hinweis des Tutorials. Eine schmale Karte am oberen Rand, mehr nicht —
/// sie verdeckt nichts Wichtiges und verschwindet von selbst.
struct TutorialOverlay: View {
    let step: TutorialStep
    let onSkip: () -> Void

    @State private var pulse = false

    var body: some View {
        VStack {
            Spacer().frame(height: 116)

            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Palette.vermilion.swiftUIColor.opacity(0.16))
                        .frame(width: 40, height: 40)
                        .scaleEffect(pulse ? 1.12 : 1)

                    Image(systemName: step.symbol)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Palette.vermilion.swiftUIColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(step.title)
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .foregroundStyle(Palette.uiInk)

                    Text(step.hint)
                        .font(.system(size: 13, design: .serif))
                        .foregroundStyle(Palette.inkSoft.swiftUIColor)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                Button(action: onSkip) {
                    Text("Überspringen")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.inkSoft.swiftUIColor)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Palette.paper.swiftUIColor.opacity(0.94))
                    .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
            )
            .padding(.horizontal, 16)

            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
