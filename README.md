# Dan-Fishing — Angeln am Bergsee

Modul- und Projektname sind `DanFishing` ohne Bindestrich: Swift lässt in
Modulnamen keinen zu. Auf dem Gerät steht unter dem Symbol „Dan-Fishing“.

Ein ruhiges Angelspiel für das iPhone. Der Spieler rudert in einem kleinen
Kahn über einen japanisch angehauchten Bergsee, sucht sich einen Platz, wählt
einen Köder und versucht sein Glück. Kein Zeitdruck, keine Energieleiste, keine
Käufe.

SwiftUI für alle Menüs, SpriteKit für den See. Alle Grafiken und Klänge
entstehen zur Laufzeit im Code — im Projekt liegt keine einzige Bild- oder
Audiodatei.

## Anforderungen

* Xcode 16 oder neuer
* iOS 17 oder neuer
* Hochformat, iPhone

## Starten

```bash
open DanFishing.xcodeproj
```

Schema `DanFishing` wählen, ein iPhone-Ziel einstellen, `Cmd+R`.
Tests laufen mit `Cmd+U`.

Ohne Mac zur Hand baut der Workflow `.github/workflows/ios.yml` auf einem
macOS-Runner von GitHub Actions: Er kompiliert, führt die Tests aus, macht ein
Bildschirmfoto aus dem Simulator und legt zusätzlich ein unsigniertes `.ipa` ab.

## Spielablauf

1. Mit dem Joystick links einen Platz ansteuern (oder ins Wasser tippen — das
   Boot rudert dann selbst dorthin).
2. Umgebung lesen: Schilf, Seerosen, Totholz, Zufluss und Tiefwasser haben
   jeweils eigene Bewohner. Die Fische im Wasser sind sichtbar.
3. Köder wählen.
4. Aktionstaste rechts halten — die Anzeige pendelt, im richtigen Moment
   loslassen. Das bestimmt die Wurfweite.
5. Warten. Der Schwimmer zuckt, wenn ein Fisch prüft.
6. Beim Biss anschlagen: dieselbe Taste, kurz antippen. Das Zeitfenster ist
   gut eine Sekunde lang.
7. Drill: Die Einholtaste hält den Fangbereich oben, Loslassen lässt ihn
   sinken. Der Fisch muss im Bereich bleiben, ohne dass die Spannung reißt.
8. Fisch verkaufen, für die Sammlung behalten oder wieder freilassen.
9. Münzen in Rute, Rolle, Schnur, Haken, Boot, Laterne, Fischfinder oder
   Glücksbringer stecken.

## Projektstruktur

```
DanFishing/
  App/            Einstiegspunkt und Umschalter Menü ↔ Spiel
  Models/         Reine Datentypen: Fisch, Köder, Ausrüstung, Mission
  Data/           Kataloge: alle Fischarten, Köder und Upgrades
  Systems/        Spiellogik ohne Darstellung
  Managers/       Ton und Haptik
  Scenes/         Die SpriteKit-Szene
  GameObjects/    Knoten: Boot, Fisch, Schwimmer, Kulisse
  UI/             SwiftUI-Ansichten
  ViewModels/     GameSession als Bindeglied
  Persistence/    Spielstand und Speicherung
  Support/        Zufall, Rauschen, Farben, Texturen
DanFishingTests/     Tests der Kernlogik
```

## Die wichtigsten Systeme

**LakeMap** erzeugt den See aus einem festen Startwert: ein Raster aus Zellen,
jede davon Land oder eine von sechs Zonen. Daraus kommen Kollision, Wassertiefe
und die Frage, welche Fische an einem Punkt überhaupt stehen können. Gleicher
Startwert, gleicher See — der Spielstand muss die Karte deshalb nicht speichern.

**BoatController** rechnet die Fahrt: Das Boot dreht sich zur gewünschten
Richtung, statt seitwärts zu rutschen, und gleitet an Ufern entlang, statt hart
stehen zu bleiben. Reine Mathematik, keine Physics-Engine — dadurch testbar.

**FishingSystem** ist die Zustandsmaschine vom Auswerfen bis zum Anschlag
(`idle → charging → flying → waiting → nibble → biteWindow → hooked`). Sie
meldet Ereignisse nach oben; Szene und Oberfläche entscheiden, was sie damit
anzeigen.

**BaitSystem** bewertet, wie interessant ein Köder für eine Art gerade ist —
aus Zone, Tageszeit, Vorliebe der Art, Seltenheit und Ausrüstung. Daraus
entsteht sowohl die Wartezeit bis zum Biss als auch die Auswahl, welcher Fisch
anbeißt. Der Spieler sieht keine Zahlen; er lernt es über das Fangbuch.

**FishSpawner** zieht die Art nach diesen Gewichten und würfelt die Länge aus
einer Dreiecksverteilung. Große Köder verschieben den Schwerpunkt nach oben,
deshalb bringt der Köderfisch im Schnitt größere Hechte als die Made.

**CatchMiniGame** ist der Drill, komplett ohne UI: Der Fisch wandert in einer
Bahn, der Fangbereich steigt beim Halten und sinkt beim Loslassen. Halten
belastet die Schnur, Loslassen entlastet sie; vorwärts geht es nur, solange der
Fisch im Fangbereich liegt. Daraus wird ein Tauziehen mit zwei Verlustwegen —
gerissene Schnur bei zu viel Spannung, ausgeschlitzter Haken bei zu langer
Schlaffheit.

**DayNightSystem** läuft einen Tag in acht Minuten durch und liefert Phase,
Dunkelheit und Farbstimmung. Nachtfische gibt es dadurch regelmäßig, ohne dass
jemand warten muss.

**GameSession** hält alles zusammen: Spielstand, Eingaben der Oberfläche,
Ereignisse der Szene. Szene und SwiftUI kennen einander nicht.

**AudioManager** berechnet beim Start PCM-Puffer für Wasserrauschen, einzelne
gezupfte Töne einer pentatonischen Reihe und alle Effekte. Im Audio-Thread
läuft dadurch keine Rechenarbeit, und es gibt keine Lizenzfrage.

## Was fertig ist

* Ein See mit sechs Zonen, Inseln, Steinen, Schilf, Seerosen, Totholz und
  einem Zufluss, prozedural erzeugt
* Ruderboot mit Trägheit, Kollision, Ruderanimation und Antippen-Steuerung
* Sichtbare Fischschwärme, die auf den Köder reagieren
* Auswerfen mit Weitenanzeige, Zupfen, Biss, Anschlag mit Zeitfenster
* Fang-Minispiel mit Spannung, Fortschritt und zwei Verlustwegen
* 12 Fischarten, 12 Köder, zufällige Größen mit Trophäen
* 8 Ausrüstungsreihen mit mehreren Stufen
* Fangbuch, das sich mit der Zahl der Fänge weiter öffnet
* Tagesaufgaben, Erfahrung und Spielerstufen
* Verkaufen, behalten oder freilassen mit unterschiedlichem Ertrag
* Tageszeitwechsel, Nebel, Blüten, Laterne fürs Nachtangeln
* Ton und Haptik, beides abschaltbar
* Spielstand in UserDefaults, automatisch beim Wechsel in den Hintergrund
* Tests für Karte, Boot, Köder, Spawner, Drill, Wirtschaft, Missionen und
  Speicherung

## Sinnvolle Erweiterungen

* Weitere Seegebiete, freigeschaltet über die Spielerstufe
* Wetter mit spürbarer Wirkung: Regen bringt Fische an die Oberfläche
* Köder, die man führen muss, statt nur liegen zu lassen
* Sammlungen mit Abschlussbelohnung
* Ein Händler mit wechselndem Angebot
* Fotomodus für besondere Fänge
* Game Center für Bestenlisten

## Eigene Inhalte ergänzen

**Neue Fischart:** Einen Eintrag in `Data/FishCatalog.swift` anhängen. Zonen,
Beißzeiten, Köder, Kampfstärke und Farben angeben — Spawner, Fangbuch,
Missionen und Grafik greifen sofort darauf zu.

**Neuer Köder:** Eintrag in `Data/BaitCatalog.swift`. Über `strongHabitats`,
`strongTimes`, `sizeBias` und `rarityBias` steuert man die Wirkung. Danach die
ID bei den Fischarten unter `preferredBaitIDs` eintragen, die ihn mögen.

**Neues Upgrade:** Reihe in `Data/UpgradeCatalog.swift` anlegen. Jede Stufe
liefert ein `EquipmentStatDelta`; die Systeme lesen nur die aufsummierten
Werte, es ist also kein weiterer Code nötig.

**Echte Grafiken statt Platzhalter:** In `Support/TextureFactory.swift` die
jeweilige Funktion durch `SKTexture(imageNamed:)` ersetzen. Formen aus
Code — Boot, Kulisse — liegen in `GameObjects/BoatNode.swift` und
`GameObjects/DecorFactory.swift`.

**Echte Klänge:** In `Managers/AudioManager.swift` die Puffererzeugung durch
`AVAudioFile`-Laden ersetzen. Die Aufrufstellen (`play(.cast)` und so weiter)
bleiben unverändert.

## Testen

**Simulator**

1. Schema `DanFishing`, Ziel z. B. iPhone 16
2. `Cmd+R`
3. „Neuer Spielstand“, dann rudern, werfen, anschlagen, drillen
4. App in den Hintergrund schicken und neu starten — der Fortschritt muss
   erhalten bleiben

Haptik und Ton sind im Simulator eingeschränkt; die Vibration fehlt dort ganz.

**Echtes iPhone**

1. iPhone anschließen, in Xcode auswählen
2. Unter „Signing & Capabilities“ ein Team eintragen (ein kostenloser
   Apple-Account genügt) und die Bundle-ID auf etwas Eigenes ändern,
   z. B. `com.deinname.danfishing`
3. `Cmd+R`
4. Beim ersten Start auf dem Gerät: Einstellungen → Allgemein → VPN & Geräte­
   verwaltung → Entwickler-App vertrauen

Ohne Mac: Das unsignierte `.ipa` aus dem CI-Lauf herunterladen und mit
Sideloadly oder AltStore vom PC aufs iPhone übertragen. Mit einem kostenlosen
Apple-Account läuft die App sieben Tage und muss danach erneut übertragen
werden.

Auf dem Gerät zusätzlich prüfen: Vibration beim Biss und bei kritischer
Spannung, Bildrate beim Rudern über Seerosenfelder, Bedienbarkeit der
Wurftaste mit dem Daumen.
