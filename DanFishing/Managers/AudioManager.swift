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
    private var introBuffer: AVAudioPCMBuffer?

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

    /// Kreiszahl mal zwei — in jeder Schwingung gebraucht.
    private static let tau: Double = 2 * Double.pi

    /// Eine Sinusschwingung. Als eigene Funktion, damit der Typprüfer in den
    /// Klangformeln unten nicht jedes Mal über verschachtelte Literale läuft.
    private static func tone(_ frequency: Double, _ t: Double) -> Double {
        sin(AudioManager.tau * frequency * t)
    }

    /// Exponentiell abfallende Hüllkurve.
    private static func decay(_ rate: Double, _ t: Double) -> Double {
        exp(-rate * t)
    }

    private func buildBuffers() {
        registerEffect("cast", duration: 0.5) { t, duration in
            // Rauschwisch, der nach oben zieht: die Schnur, die von der Rolle läuft.
            let envelope: Double = AudioManager.decay(6, t)
            let noise: Double = Double.random(in: -1...1)
            let frequency: Double = 900 + 1400 * (t / duration)
            let sweep: Double = AudioManager.tone(frequency, t) * 0.25
            return (noise * 0.5 + sweep) * envelope * 0.5
        }

        registerEffect("splash", duration: 0.7) { t, _ in
            let envelope: Double = AudioManager.decay(9, t)
            let noise: Double = Double.random(in: -1...1)
            let body: Double = AudioManager.tone(220, t) * 0.2 * AudioManager.decay(14, t)
            return (noise * 0.55 + body) * envelope * 0.55
        }

        registerEffect("bite", duration: 0.35) { t, _ in
            // Kurzer, tiefer „Plopp“.
            let envelope: Double = AudioManager.decay(22, t)
            let pitch: Double = 320 - 180 * (t / 0.35)
            return AudioManager.tone(pitch, t) * envelope * 0.7
        }

        registerEffect("reel", duration: 0.22) { t, _ in
            let envelope: Double = AudioManager.decay(18, t)
            let click: Double = AudioManager.tone(1200, t) + AudioManager.tone(1800, t) * 0.4
            return click * envelope * 0.25
        }

        registerEffect("catchSmall", duration: 0.9) { t, _ in
            // Zwei Töne einer Pentatonik, leicht versetzt.
            let a: Double = AudioManager.tone(587.33, t) * AudioManager.decay(4, t)
            let delayed: Double = max(0, t - 0.16)
            let b: Double = AudioManager.tone(880, t) * AudioManager.decay(4, delayed)
            return (a + b) * 0.28
        }

        registerEffect("catchBig", duration: 1.6) { t, _ in
            let a: Double = AudioManager.tone(392, t) * AudioManager.decay(2.2, t)
            let b: Double = AudioManager.tone(587.33, t) * AudioManager.decay(2.2, max(0, t - 0.2))
            let c: Double = AudioManager.tone(783.99, t) * AudioManager.decay(2.0, max(0, t - 0.42))
            return (a + b + c) * 0.24
        }

        registerEffect("lineSnap", duration: 0.5) { t, _ in
            let envelope: Double = AudioManager.decay(12, t)
            let crack: Double = Double.random(in: -1...1) * AudioManager.decay(40, t)
            let tone: Double = AudioManager.tone(1600, t) * AudioManager.decay(18, t)
            return (crack * 0.8 + tone * 0.4) * envelope * 0.6
        }

        registerEffect("uiTap", duration: 0.14) { t, _ in
            AudioManager.tone(1046.5, t) * AudioManager.decay(30, t) * 0.3
        }

        // Wasser: schmalbandiges Rauschen, das langsam an- und abschwillt.
        var lowpassState = 0.0
        ambienceBuffer = makeBuffer(duration: 8.0) { t, duration in
            let noise: Double = Double.random(in: -1...1)
            lowpassState += (noise - lowpassState) * 0.02

            // Weiche Wellenbewegung, an den Enden ausgeblendet, damit die
            // Schleife nicht knackt.
            let swell: Double = 0.6 + 0.4 * AudioManager.tone(0.25, t)
            let edge: Double = min(t, duration - t)
            let fade: Double = min(1, edge / 0.4)
            return lowpassState * 3.0 * swell * fade * 0.35
        }

        // Pentatonische Tonleiter (D-Dur-Pentatonik), zwei Oktaven.
        let scale: [Double] = [293.66, 329.63, 392.00, 440.00, 587.33, 659.25, 783.99]
        noteBuffers = scale.compactMap { frequency in
            makeBuffer(duration: 2.4) { t, _ in
                // Gezupfter Klang: schneller Anschlag, langer weicher Ausklang.
                let attack: Double = min(1, t / 0.01)
                let body: Double = AudioManager.decay(1.6, t)
                let fundamental: Double = AudioManager.tone(frequency, t)
                let harmonic: Double = AudioManager.tone(frequency * 2, t) * 0.22 * AudioManager.decay(3, t)
                return (fundamental + harmonic) * attack * body * 0.22
            }
        }
    }

    /// Legt einen Effektpuffer an. Kommt keiner zustande, fehlt später nur
    /// dieser eine Klang — das Spiel läuft weiter.
    private func registerEffect(_ key: String,
                                duration: Double,
                                generator: (Double, Double) -> Double) {
        guard let buffer = makeBuffer(duration: duration, generator: generator) else { return }
        effectBuffers[key] = buffer
    }

    // MARK: - Vorspannmusik

    /// Rechteckwelle mit einstellbarem Tastverhältnis — der Grundklang alter
    /// Handheld-Konsolen. Zwei Kanäle Melodie plus ein Basskanal reichen, um
    /// den Charakter zu treffen.
    private static func square(_ frequency: Double, _ t: Double, duty: Double = 0.5) -> Double {
        guard frequency > 0 else { return 0 }
        let phase = (t * frequency).truncatingRemainder(dividingBy: 1)
        return phase < duty ? 1 : -1
    }

    /// Spielt das Titelstück des Vorspanns.
    ///
    /// Das Stück wird beim ersten Aufruf einmal berechnet und liegt danach
    /// fertig im Speicher. Es ist eine eigene, hier komponierte Melodie in
    /// D-Dur — keine Anleihe bei bestehenden Stücken.
    func playIntroTheme() {
        guard isRunning, musicEnabled else { return }

        if introBuffer == nil {
            introBuffer = makeIntroTheme()
        }
        guard let buffer = introBuffer else { return }

        musicTimer?.invalidate()
        musicTimer = nil

        musicPlayer.stop()
        musicPlayer.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        musicPlayer.volume = musicEnabled ? 0.55 : 0
        musicPlayer.play()
    }

    /// Beendet die Vorspannmusik und schaltet zurück auf die ruhige Kulisse.
    func stopIntroTheme() {
        musicPlayer.stop()
        startMusicLoop()
    }

    /// Gezupfter Ton mit langem Ausklang — der Klang einer Koto.
    ///
    /// Aufbau: Grundton plus zwei leise Obertöne, die schneller verklingen als
    /// der Grundton. Genau das unterscheidet eine gezupfte Saite von einem
    /// reinen Sinuston.
    private static func pluck(_ frequency: Double, _ local: Double, decay: Double) -> Double {
        guard local >= 0 else { return 0 }
        let attack = min(1, local / 0.006)
        let body = exp(-local * decay)
        let fundamental = sin(2 * Double.pi * frequency * local)
        let second = sin(2 * Double.pi * frequency * 2 * local) * 0.28 * exp(-local * decay * 2.4)
        let third = sin(2 * Double.pi * frequency * 3 * local) * 0.12 * exp(-local * decay * 4)
        return (fundamental + second + third) * attack * body
    }

    /// Atmender Flötenton mit Anblasgeräusch — angelehnt an eine Shakuhachi.
    private static func flute(_ frequency: Double, _ local: Double, length: Double) -> Double {
        guard local >= 0 else { return 0 }
        let attack = min(1, local / 0.35)
        let release = min(1, (length - local) / 0.5)
        // Der Ton steht nicht still, sondern schwankt leicht.
        let breath = 1 + sin(local * 4.5) * 0.012
        let tone = sin(2 * Double.pi * frequency * local * breath)
        let air = Double.random(in: -1...1) * 0.05 * attack
        return (tone * 0.9 + air) * attack * release
    }

    private func makeIntroTheme() -> AVAudioPCMBuffer? {
        // Hirajōshi, die klassische japanische Leiter: Grundton, kleine Sekunde,
        // Quarte, Quinte, kleine Sexte. Ihre Halbtonschritte geben den
        // charakteristischen Klang — mit einer Dur-Tonleiter klänge es
        // europäisch, egal wie sanft man spielt.
        func note(_ step: Int) -> Double {
            let hirajoshi = [0, 2, 3, 7, 8]     // Halbtöne über dem Grundton
            let octave = step >= 0 ? step / 5 : (step - 4) / 5
            var index = step % 5
            if index < 0 { index += 5 }
            // Grundton D3.
            return 146.83 * pow(2.0, (Double(hirajoshi[index]) + Double(octave) * 12) / 12.0)
        }

        // Sparsame Melodie, viel Raum dazwischen: (Stufe, Startzeit, Ausklang).
        let koto: [(Int, Double, Double)] = [
            (5, 0.20, 1.1), (7, 1.60, 1.1), (8, 2.90, 0.9),
            (10, 4.10, 0.8), (9, 5.40, 1.0), (7, 6.60, 1.0),
            (5, 8.00, 0.8), (8, 9.30, 0.7), (10, 10.60, 0.55),
            (12, 11.80, 0.45)
        ]

        // Zwei lange Flötentöne, die den Bogen darüber spannen.
        let shakuhachi: [(Int, Double, Double)] = [
            (10, 2.20, 3.4),
            (12, 7.40, 4.2)
        ]

        // Tiefer Bordunton, kaum hörbar, trägt das Ganze.
        let drone = note(0) / 2

        let duration = 13.5

        return makeBuffer(duration: duration) { t, _ in
            var sample = 0.0

            for (step, start, decay) in koto where t >= start {
                sample += AudioManager.pluck(note(step), t - start, decay: decay) * 0.15
            }

            for (step, start, length) in shakuhachi where t >= start && t < start + length {
                sample += AudioManager.flute(note(step) / 2, t - start, length: length) * 0.085
            }

            sample += sin(2 * Double.pi * drone * t) * 0.045
            sample += sin(2 * Double.pi * drone * 1.5 * t) * 0.02

            // Weit auf- und abblenden, damit nichts einsetzt oder abbricht.
            let fadeIn = min(1, t / 1.4)
            let fadeOut = min(1, (duration - t) / 2.4)
            return sample * fadeIn * fadeOut
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
