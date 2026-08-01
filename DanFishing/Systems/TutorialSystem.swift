import Foundation

/// Das Tutorial beim ersten Spielstart.
///
/// Kein Textblock und keine Sperre: Jeder Schritt beschreibt in einem Satz,
/// was zu tun ist, und geht von selbst weiter, sobald der Spieler es getan
/// hat. Wer es ohnehin versteht, rauscht in unter einer Minute durch.
enum TutorialStep: Int, CaseIterable, Equatable {
    case welcome
    case move
    case cast
    case wait
    case watch
    case strike
    case fight
    case done

    var title: String {
        switch self {
        case .welcome: return "Willkommen bei Dan Fishing"
        case .move: return "Rudern"
        case .cast: return "Auswerfen"
        case .wait: return "Warten"
        case .watch: return "Beobachten"
        case .strike: return "Anschlagen"
        case .fight: return "Drill"
        case .done: return "Petri Heil"
        }
    }

    var hint: String {
        switch self {
        case .welcome: return "Ein stiller See, ein Boot, viel Zeit."
        case .move: return "Zieh am Ring unten links, um zu rudern."
        case .cast: return "Zwei Schritte: erst ziehen und loslassen für die Richtung, dann ziehen und loslassen für die Weite."
        case .wait: return "Der Köder liegt. Jetzt entscheidet der See."
        case .watch: return "Ein Fisch schaut sich den Köder an — der Punkt über ihm verrät ihn."
        case .strike: return "Der Schwimmer taucht weg. Tippe jetzt die Taste!"
        case .fight: return "Halte gedrückt, um einzuholen. Loslassen entlastet die Schnur."
        case .done: return "Jeder Fang bringt Münzen und Erfahrung. Petri Heil."
        }
    }

    var symbol: String {
        switch self {
        case .welcome: return "leaf"
        case .move: return "dot.circle.and.hand.point.up.left.fill"
        case .cast: return "arrow.up.forward"
        case .wait: return "hourglass"
        case .watch: return "eye"
        case .strike: return "bolt.fill"
        case .fight: return "figure.fishing"
        case .done: return "checkmark.seal"
        }
    }

    /// Schritte, die nach ein paar Sekunden von selbst weitergehen, auch wenn
    /// nichts passiert — sonst hängt jemand fest, weil kein Fisch anbeißt.
    var autoAdvanceAfter: TimeInterval? {
        switch self {
        case .welcome: return 3.5
        case .watch: return 14
        case .done: return 6
        default: return nil
        }
    }

    var next: TutorialStep? {
        TutorialStep(rawValue: rawValue + 1)
    }
}

/// Was im Spiel passiert ist. Der Tutorialablauf hört nur darauf und kennt
/// weder Szene noch Oberfläche.
enum TutorialTrigger: Equatable {
    case boatMoved
    case castLanded
    case fishInspecting
    case bite
    case hooked
    case fishLanded
    case lineLost
}

/// Führt durch die Schritte. Bewusst eine eigene kleine Zustandsmaschine,
/// damit das Tutorial später ohne Eingriff ins Spiel geändert werden kann.
struct TutorialSystem {

    private(set) var step: TutorialStep?
    private var elapsed: TimeInterval = 0

    var isRunning: Bool { step != nil }

    init(active: Bool) {
        step = active ? .welcome : nil
    }

    mutating func update(deltaTime: TimeInterval) {
        guard let current = step else { return }
        elapsed += deltaTime

        if let limit = current.autoAdvanceAfter, elapsed >= limit {
            advance()
        }
    }

    /// Meldet ein Ereignis. Passt es zum aktuellen Schritt, geht es weiter.
    mutating func report(_ trigger: TutorialTrigger) {
        guard let current = step else { return }

        let matches: Bool
        switch (current, trigger) {
        case (.move, .boatMoved): matches = true
        case (.cast, .castLanded): matches = true
        case (.wait, .fishInspecting): matches = true
        case (.wait, .bite): matches = true
        case (.watch, .bite): matches = true
        case (.strike, .hooked): matches = true
        case (.fight, .fishLanded): matches = true
        // Reißt die Schnur im Tutorial, geht es trotzdem weiter — sonst
        // klebt der Hinweis fest, bis endlich einmal ein Fisch im Boot liegt.
        case (.fight, .lineLost): matches = true
        default: matches = false
        }

        guard matches else { return }

        // Beim Biss darf der Beobachtungsschritt übersprungen werden.
        if current == .wait && trigger == .bite {
            step = .strike
            elapsed = 0
            return
        }

        advance()
    }

    mutating func advance() {
        guard let current = step else { return }
        step = current.next
        elapsed = 0
    }

    mutating func skip() {
        step = nil
    }
}
