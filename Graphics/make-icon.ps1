# App-Symbol fuer den Home-Bildschirm.
#
# Gestaltung: aufgehende Sonne ueber ruhigem Wasser, davor die Silhouette eines
# springenden Fisches. Wenige, grosse Formen — ein Symbol wird auf dem Geraet
# nur rund 60 Punkte gross angezeigt, Details verschwinden dort ohnehin.
# Kein Alphakanal: Apple verlangt ein deckendes Bild.

Add-Type -AssemblyName System.Drawing

$size = 1024
$out = 'C:\Users\Daniel\workspaces\mizuumi-fishing\DanFishing\Assets.xcassets\AppIcon.appiconset\AppIcon.png'

$bmp = New-Object System.Drawing.Bitmap $size, $size, ([System.Drawing.Imaging.PixelFormat]::Format32bppRgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

function C { param([int]$r, [int]$g, [int]$b) [System.Drawing.Color]::FromArgb(255, $r, $g, $b) }

# Himmel: warmer Verlauf von Sandpapier nach Morgenrot.
$skyRect = New-Object System.Drawing.Rectangle 0, 0, $size, ([int]($size * 0.62))
$sky = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    $skyRect, (C 244 230 205), (C 226 176 132), 90)
$g.FillRectangle($sky, $skyRect)

# Sonne als kraeftige Scheibe, leicht ausserhalb der Mitte.
$sunSize = [int]($size * 0.42)
$sunX = [int]($size * 0.30)
$sunY = [int]($size * 0.14)
$g.FillEllipse((New-Object System.Drawing.SolidBrush (C 197 84 60)), $sunX, $sunY, $sunSize, $sunSize)

# Wasser: kuehler Verlauf, klare Kante zum Himmel.
$waterRect = New-Object System.Drawing.Rectangle 0, ([int]($size * 0.60)), $size, ([int]($size * 0.40))
$water = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    $waterRect, (C 122 154 158), (C 58 92 108), 90)
$g.FillRectangle($water, $waterRect)

# Auf die Spiegelung wird bewusst verzichtet. Sie lag als braune Ovale im
# Wasser und wirkte schmutzig, statt Licht anzudeuten — bei einem Symbol, das
# auf dem Gerät kaum größer als ein Daumennagel ist, zählt jede Fläche.

# Wellenlinien im Wasser.
$pen = New-Object System.Drawing.Pen ((C 226 236 236)), ([single]($size * 0.012))
$pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
foreach ($line in @(@(0.70, 0.06, 0.30), @(0.79, 0.62, 0.34), @(0.88, 0.12, 0.42))) {
    $y = [int]($size * $line[0])
    $x1 = [int]($size * $line[1])
    $x2 = [int]($size * ($line[1] + $line[2]))
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddBezier($x1, $y,
                    [int](($x1 + $x2) / 2 - $size * 0.06), [int]($y - $size * 0.035),
                    [int](($x1 + $x2) / 2 + $size * 0.06), [int]($y + $size * 0.035),
                    $x2, $y)
    $g.DrawPath($pen, $path)
    $path.Dispose()
}

# Springender Fisch als dunkle Silhouette, diagonal aus dem Wasser.
$ink = New-Object System.Drawing.SolidBrush (C 38 46 52)

# Der Fisch springt links unten aus dem Wasser und lässt die Sonne frei —
# vorher lag er quer über der Scheibe und nahm ihr die Wirkung.
$state = $g.Save()
$g.TranslateTransform([single]($size * 0.40), [single]($size * 0.70))
$g.RotateTransform(-34)

$bodyW = [single]($size * 0.38)
$bodyH = [single]($size * 0.155)
$g.FillEllipse($ink, -$bodyW / 2, -$bodyH / 2, $bodyW, $bodyH)

# Schwanzflosse
$tail = @(
    (New-Object System.Drawing.PointF ([single](-$bodyW * 0.44), [single]0)),
    (New-Object System.Drawing.PointF ([single](-$bodyW * 0.78), [single](-$bodyH * 0.85))),
    (New-Object System.Drawing.PointF ([single](-$bodyW * 0.62), [single]0)),
    (New-Object System.Drawing.PointF ([single](-$bodyW * 0.78), [single]($bodyH * 0.85)))
)
$g.FillPolygon($ink, $tail)

# Rueckenflosse
$dorsal = @(
    (New-Object System.Drawing.PointF ([single](-$bodyW * 0.10), [single](-$bodyH * 0.42))),
    (New-Object System.Drawing.PointF ([single]($bodyW * 0.02), [single](-$bodyH * 0.95))),
    (New-Object System.Drawing.PointF ([single]($bodyW * 0.18), [single](-$bodyH * 0.40)))
)
$g.FillPolygon($ink, $dorsal)

# Auge als heller Punkt
$g.FillEllipse((New-Object System.Drawing.SolidBrush (C 244 238 222)),
               [single]($bodyW * 0.28), [single](-$bodyH * 0.20),
               [single]($size * 0.035), [single]($size * 0.035))

$g.Restore($state)

# Spritzer dort, wo der Fisch das Wasser verlassen hat: ein Ring und drei
# Tropfen, die der Sprungrichtung folgen.
$drop = New-Object System.Drawing.SolidBrush (C 226 236 236)

foreach ($d in @(@(0.155, 0.735, 0.026), @(0.115, 0.695, 0.018), @(0.205, 0.780, 0.014))) {
    $r = [int]($size * $d[2])
    $g.FillEllipse($drop, [int]($size * $d[0]), [int]($size * $d[1]), $r, $r)
}

$g.Dispose()
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

"gespeichert: $out"
