import AVFoundation
import Foundation

/// Klang und Musik. Es gibt bewusst keine Audiodateien im Projekt: alles wird
/// beim Start als PCM-Puffer berechnet. Damit gibt es keine Lizenzfragen und
/// nichts, das fehlen könnte.
///
/// Aufbau: ein `AVAudioEngine` mit drei Spielern — Wasserrauschen als
/// Endlosschleife, ein Spieler für die Melodie und ein kleiner Pool für
/// Effekte. Alle Puffer werden vorab erzeugt, im Audio-Thread läuft also keine
/// eigene Rechenarbeit.
final class AudioManager {

    static let shared = AudioManager()

    enum Effect {
        case cast
        case splash
        case bite
        case reel
        case catchSmall
        case catchBig
        case lineSnap
        case uiTap
    }

    private let engine = AVAudioEngine()
    private let ambiencePlayer = AVAudioPlayerNode()
    private let musicPlayer = AVAudioPlayerNode()
    private var effectPlayers: [AVAudioPlayerNode] = []
    private var nextEffectPlayer = 0

    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var effectBuffers: [String: AVAudioPCMBuffer] = [:]
    private var ambienceBuffer: AVAudioPCMBuffer?
    private var noteBuffers: [AVAudioPCMBuffer] = []

    private var musicTimer: Timer?
    private var isRunning = false

    private(set) var musicEnabled = true
    private(set) var effectsEnabled = true

    private init() {}

    // MARK: - Lebenszyklus

    /// Baut Engine und Puffer auf. Schlägt etwas fehl, bleibt das Spiel stumm,
    /// läuft aber normal weiter.
    func start() {
        guard !isRunning else { return }

        do {
            let session = AVAudioSession.sharedInstance()
            // .ambient: Die Musik anderer Apps wird nicht unterbrochen und der
            // Stummschalter des iPhones wird respektiert.
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            return
        }

        engine.attach(ambiencePlayer)
        engine.attach(musicPlayer)
        engine.connect(ambiencePlayer, to: engine.mainMixerNode, format: format)
        engine.connect(musicPlayer, to: engine.mainMixerNode, format: format)

        for _ in 0..<4 {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            effectPlayers.append(player)
        }

        buildBuffers()

        do {
            try engine.start()
        } catch {
            return
        }

        isRunning = true
        startAmbience()
        startMusicLoop()
    }

    func stop() {
        musicTimer?.invalidate()
        musicTimer = nil
        ambiencePlayer.stop()
        musicPlayer.stop()
        effectPlayers.forEach { $0.stop() }
        engine.stop()
        isRunning = false
    }

    func apply(settings: GameSettings) {
        musicEnabled = settings.music
        effectsEnabled = settings.sfx

        ambiencePlayer.volume = settings.sfx ? 0.5 : 0
        musicPlayer.volume = settings.music ? 0.5 : 0
    }

    // MARK: - Wiedergabe

    func play(_ effect: Effect) {
        guard isRunning, effectsEnabled else { return }
        guard let buffer = effectBuffers[key(for: effect)] else { return }

        let player = effectPlayers[nextEffectPlayer % max(1, effectPlayers.count)]
        nextEffectPlayer += 1

        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !player.isPlaying { player.play() }
    }

    private func startAmbience() {
        guard let buffer = ambienceBuffer else { return }
        ambiencePlayer.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        ambiencePlayer.volume = effectsEnabled ? 0.5 : 0
        ambiencePlayer.play()
    }

    /// Sehr ruhige Melodie: alle paar Sekunden ein einzelner Ton aus einer
    /// pentatonischen Reihe. Das wirkt wie ein Koto im Hintergrund, ohne dass
    /// eine feste Komposition nötig wäre.
    private func startMusicLoop() {
        musicPlayer.volume = musicEnabled ? 0.5 : 0
        musicPlayer.play()

        musicTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 3.4, repeats: true) { [weak self] _ in
            self?.playRandomNote()
        }
        RunLoop.main.add(timer, forMode: .common)
        musicTimer = timer
    }

    private func playRandomNote() {
        guard isRunning, musicEnabled, !noteBuffers.isEmpty else { return }
        let buffer = noteBuffers[Int.random(in: 0..<noteBuffers.count)]
        musicPlayer.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        if !musicPlayer.isPlaying { musicPlayer.play() }
    }

    // MARK: - Klangerzeugung

    private func key(for effect: Effect) -> String {
        switch effect {
        case .cast: return "cast"
        case .splash: return "splash"
        case .bite: return "bite"
        case .reel: return "reel"
        case .catchSmall: return "catchSmall"
        case .catchBig: return "catchBig"
        case .lineSnap: return "lineSnap"
        case .uiTap: return "uiTap"
        }
    }

    private func buildBuffers() {
        effectBuffers["cast"] = makeBuffer(duration: 0.5) { t, duration in
            // Rauschwisch, der nach oben zieht: die Schnur, die von der Rolle läuft.
            let envelope = exp(-t * 6)
            let noise = Double.random(in: -1...1)
            let sweep = sin(2 * .pi * (900 + 1400 * t / duration) * t) * 0.25
            return (noise * 0.5 + sweep) * envelope * 0.5
        }

        effectBuffers["splash"] = makeBuffer(duration: 0.7) { t, _ in
            let envelope = exp(-t * 9)
            let noise = Double.random(in: -1...1)
            let body = sin(2 * .pi * 220 * t) * 0.2 * exp(-t * 14)
            return (noise * 0.55 + body) * envelope * 0.55
        }

        effectBuffers["bite"] = makeBuffer(duration: 0.35) { t, _ in
            // Kurzer, tiefer „Plopp“.
            let envelope = exp(-t * 22)
            let pitch = 320 - 180 * t / 0.35
            return sin(2 * .pi * pitch * t) * envelope * 0.7
        }

        effectBuffers["reel"] = makeBuffer(duration: 0.22) { t, _ in
            let envelope = exp(-t * 18)
            let click = sin(2 * .pi * 1200 * t) + sin(2 * .pi * 1800 * t) * 0.4
            return click * envelope * 0.25
        }

        effectBuffers["catchSmall"] = makeBuffer(duration: 0.9) { t, _ in
            // Zwei Töne einer Pentatonik, leicht versetzt.
            let a = sin(2 * .pi * 587.33 * t) * exp(-t * 4)
            let b = sin(2 * .pi * 880.00 * t) * exp(-max(0, t - 0.16) * 4)
            return (a + b) * 0.28
        }

        effectBuffers["catchBig"] = makeBuffer(duration: 1.6) { t, _ in
            let a = sin(2 * .pi * 392.00 * t) * exp(-t * 2.2)
            let b = sin(2 * .pi * 587.33 * t) * exp(-max(0, t - 0.2) * 2.2)
            let c = sin(2 * .pi * 783.99 * t) * exp(-max(0, t - 0.42) * 2.0)
            return (a + b + c) * 0.24
        }

        effectBuffers["lineSnap"] = makeBuffer(duration: 0.5) { t, _ in
            let envelope = exp(-t * 12)
            let crack = Double.random(in: -1...1) * exp(-t * 40)
            let tone = sin(2 * .pi * 1600 * t) * exp(-t * 18)
            return (crack * 0.8 + tone * 0.4) * envelope * 0.6
        }

        effectBuffers["uiTap"] = makeBuffer(duration: 0.14) { t, _ in
            sin(2 * .pi * 1046.5 * t) * exp(-t * 30) * 0.3
        }

        // Wasser: schmalbandiges Rauschen, das langsam an- und abschwillt.
        var lowpassState = 0.0
        ambienceBuffer = makeBuffer(duration: 8.0) { t, duration in
            let noise = Double.random(in: -1...1)
            lowpassState += (noise - lowpassState) * 0.02
            // Weiche Wellenbewegung, an den Enden ausgeblendet, damit die
            // Schleife nicht knackt.
            let swell = 0.6 + 0.4 * sin(2 * .pi * t / 4.0)
            let fade = min(1, min(t, duration - t) / 0.4)
            return lowpassState * 3.0 * swell * fade * 0.35
        }

        // Pentatonische Tonleiter (D-Dur-Pentatonik), zwei Oktaven.
        let scale: [Double] = [293.66, 329.63, 392.00, 440.00, 587.33, 659.25, 783.99]
        noteBuffers = scale.map { frequency in
            makeBuffer(duration: 2.4) { t, _ in
                // Gezupfter Klang: schneller Anschlag, langer weicher Ausklang.
                let attack = min(1, t / 0.01)
                let body = exp(-t * 1.6)
                let fundamental = sin(2 * .pi * frequency * t)
                let harmonic = sin(2 * .pi * frequency * 2 * t) * 0.22 * exp(-t * 3)
                return (fundamental + harmonic) * attack * body * 0.22
            }
        }
    }

    /// Erzeugt einen Mono-Puffer. `generator` bekommt die Zeit in Sekunden und
    /// die Gesamtlänge und liefert einen Wert in [-1, 1].
    private func makeBuffer(duration: Double, generator: (Double, Double) -> Double) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(duration * format.sampleRate)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channel = buffer.floatChannelData?[0] else { return nil }

        buffer.frameLength = frameCount
        let step = 1.0 / format.sampleRate

        for frame in 0..<Int(frameCount) {
            let t = Double(frame) * step
            let value = generator(t, duration)
            channel[frame] = Float(min(max(value, -1), 1))
        }
        return buffer
    }
}
