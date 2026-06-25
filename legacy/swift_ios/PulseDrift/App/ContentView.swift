import SpriteKit
import SwiftUI

struct ContentView: View {
    @StateObject private var session = GameSession()
    @State private var scene = GameScene(size: UIScreen.main.bounds.size)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.08, blue: 0.15),
                    Color(red: 0.06, green: 0.18, blue: 0.22),
                    Color(red: 0.11, green: 0.09, blue: 0.18),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            SpriteView(scene: scene)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                header
                Spacer()
                footer
            }
            .padding(24)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            scene.scaleMode = .resizeFill
            scene.session = session
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Pulse Drift")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                Text("Tap a lane to dodge the gates and keep the chain alive.")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.8))
                HStack(spacing: 10) {
                    Capsule()
                        .fill(Color.cyan.opacity(0.55))
                        .frame(width: 38, height: 8)
                    Text("Three lanes. One tap. Endless run.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                StatBadge(title: "Score", value: "\(session.score)")
                StatBadge(title: "Best", value: "\(session.bestScore)")
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Capsule()
                    .fill(Color.white.opacity(0.16))
                    .frame(width: 1, height: 20)

                Text("Multiplier x\(String(format: "%.1f", session.multiplier))")
                    .font(.headline)
                Text("Speed \(String(format: "%.1f", session.currentSpeed))")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
            }

            HStack(spacing: 10) {
                HintChip(text: "Tap a lane to move")
                HintChip(text: "Cyan = bonus spark")
            }

            if session.isGameOver {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Run ended")
                        .font(.title2.bold())
                    Text("Tap Restart for a fresh lane pattern. Best score saves automatically.")
                        .foregroundStyle(.white.opacity(0.78))
                    Button("Restart") {
                        session.restartRequested()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.97, green: 0.44, blue: 0.32))
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            } else {
                Text("Collect glowing sparks for a short score surge.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

}

private struct HintChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.white.opacity(0.1), in: Capsule())
    }
}

private struct StatBadge: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.65))
            Text(value)
                .font(.title3.bold())
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
