# Schneidet die Quappe aus dem Einzelblatt aus.
#
# Das Blatt hat unter dem Fisch eine Beschriftung. Sie ist dunkel, wird vom
# Hintergrundschnitt also nicht erfasst — deshalb wird vorher auf das Band
# beschnitten, in dem nur der Fisch liegt (gemessen: Zeilen 25 bis 110).

Add-Type -AssemblyName System.Drawing

$source = 'C:\Users\Daniel\Downloads\quappe.png'
$outDir = 'C:\Users\Daniel\workspaces\mizuumi-fishing\Graphics\cut'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$bandTop = 20
$bandBottom = 115

$src = New-Object System.Drawing.Bitmap $source
$rect = New-Object System.Drawing.Rectangle 0, 0, $src.Width, $src.Height
$data = $src.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly,
                      [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$stride = $data.Stride
$bytes = New-Object byte[] ($stride * $src.Height)
[System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
$src.UnlockBits($data)
$srcW = $src.Width
$src.Dispose()

$bgB = [int]$bytes[0]; $bgG = [int]$bytes[1]; $bgR = [int]$bytes[2]
$tolerance = 96

$cw = $srcW
$ch = $bandBottom - $bandTop + 1
$tile = New-Object byte[] ($cw * $ch * 4)
for ($y = 0; $y -lt $ch; $y++) {
    [System.Array]::Copy($bytes, ($bandTop + $y) * $stride, $tile, $y * $cw * 4, $cw * 4)
}

# Hintergrund vom Rand her wegnehmen, damit Grautoene im Fisch bleiben.
$visited = New-Object bool[] ($cw * $ch)
$stack = New-Object System.Collections.Generic.Stack[int]
for ($x = 0; $x -lt $cw; $x++) { $stack.Push($x); $stack.Push(($ch - 1) * $cw + $x) }
for ($y = 0; $y -lt $ch; $y++) { $stack.Push($y * $cw); $stack.Push($y * $cw + $cw - 1) }

while ($stack.Count -gt 0) {
    $index = $stack.Pop()
    if ($index -lt 0 -or $index -ge $visited.Length) { continue }
    if ($visited[$index]) { continue }
    $visited[$index] = $true

    $p = $index * 4
    if ($tile[$p + 3] -eq 0) { continue }

    $diff = [Math]::Abs([int]$tile[$p] - $bgB) +
            [Math]::Abs([int]$tile[$p + 1] - $bgG) +
            [Math]::Abs([int]$tile[$p + 2] - $bgR)
    if ($diff -gt $tolerance) { continue }

    $tile[$p + 3] = 0
    $px = $index % $cw
    if ($px -gt 0)       { $stack.Push($index - 1) }
    if ($px -lt $cw - 1) { $stack.Push($index + 1) }
    $stack.Push($index - $cw)
    $stack.Push($index + $cw)
}

$minX = $cw; $minY = $ch; $maxX = -1; $maxY = -1
for ($y = 0; $y -lt $ch; $y++) {
    $row = $y * $cw
    for ($x = 0; $x -lt $cw; $x++) {
        if ($tile[($row + $x) * 4 + 3] -gt 12) {
            if ($x -lt $minX) { $minX = $x }
            if ($x -gt $maxX) { $maxX = $x }
            if ($y -lt $minY) { $minY = $y }
            if ($y -gt $maxY) { $maxY = $y }
        }
    }
}

if ($maxX -lt 0) { 'LEER'; exit }

$outW = $maxX - $minX + 1
$outH = $maxY - $minY + 1
$bmp = New-Object System.Drawing.Bitmap $outW, $outH, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$outRect = New-Object System.Drawing.Rectangle 0, 0, $outW, $outH
$outData = $bmp.LockBits($outRect, [System.Drawing.Imaging.ImageLockMode]::WriteOnly,
                         [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$outBytes = New-Object byte[] ($outData.Stride * $outH)
for ($y = 0; $y -lt $outH; $y++) {
    [System.Array]::Copy($tile, (($minY + $y) * $cw + $minX) * 4, $outBytes, $y * $outData.Stride, $outW * 4)
}
[System.Runtime.InteropServices.Marshal]::Copy($outBytes, 0, $outData.Scan0, $outBytes.Length)
$bmp.UnlockBits($outData)
$bmp.Save((Join-Path $outDir 'fish_burbot.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

$touches = @()
if ($minX -le 0) { $touches += 'links' }
if ($maxX -ge $cw - 1) { $touches += 'rechts' }
if ($minY -le 0) { $touches += 'oben' }
if ($maxY -ge $ch - 1) { $touches += 'unten' }
$warn = if ($touches.Count -gt 0) { "  ACHTUNG beruehrt: $($touches -join ',')" } else { '' }

"burbot : $outW x $outH$warn"
