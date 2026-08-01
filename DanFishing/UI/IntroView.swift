import SpriteKit
import SwiftUI

/// Rahmen um die Vorspann-Szene. Hält sie am Leben und meldet, wenn sie
/// durch ist.
struct IntroView: View {
    @EnvironmentObject private var session: GameSession
    @State private var scene: IntroScene?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                if let scene {
                    SpriteView(scene: scene, options: [.ignoresSiblingOrder])
                        .ignoresSafeArea()
                }
            }
            .onAppear {
                guard scene == nil else { return }
                let intro = IntroScene(size: geometry.size)
                intro.onFinish = {
                    session.finishIntro()
                }
                scene = intro
            }
        }
    }
}
