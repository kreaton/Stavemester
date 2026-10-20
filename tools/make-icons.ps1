# Generates the app / home-screen icons for Stavemester.
# Run with Windows PowerShell (System.Drawing):  powershell -File tools\make-icons.ps1
param([string]$OutDir = (Join-Path $PSScriptRoot "..\src\Stavemester\wwwroot\icons"))

Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force $OutDir | Out-Null

function New-RoundedRect([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r * 2
    $p.AddArc($x, $y, $d, $d, 180, 90)
    $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $p.CloseFigure()
    return $p
}

function Color([string]$hex) { [System.Drawing.ColorTranslator]::FromHtml($hex) }

function New-Font([float]$px) {
    $font = New-Object System.Drawing.Font 'Arial Rounded MT Bold', $px, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
    if ($font.Name -ne 'Arial Rounded MT Bold') {
        $font = New-Object System.Drawing.Font 'Segoe UI', $px, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
    }
    return $font
}

# Draws letter tiles (like the game's letter boxes) centred on the icon.
# content: 1.0 = full size, 0.78 = keep inside the maskable safe zone
function Draw-Icon([int]$size, [string]$file, [float]$content = 1.0, [string[]]$letters = @('A', 'B', 'C')) {
    $S = [float]$size
    $bmp = New-Object System.Drawing.Bitmap $size, $size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.TextRenderingHint = 'AntiAliasGridFit'

    # Sky to sand, as in the game (full square, iOS applies its own rounded mask)
    $bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.PointF 0, 0), (New-Object System.Drawing.PointF 0, $S), (Color '#9fd8ff'), (Color '#fff3a3')
    $g.FillRectangle($bg, 0, 0, $S, $S)

    $colors = @('#fa5252', '#228be6', '#40c057')
    $n = $letters.Count
    $gap = $S * 0.04 * $content
    $tile = [Math]::Min($S * 0.27 * $content, ($S * 0.88 * $content - ($n - 1) * $gap) / $n)
    $tileH = $tile * 1.15
    $x0 = ($S - ($n * $tile + ($n - 1) * $gap)) / 2
    $y = ($S - $tileH) / 2
    $r = $tile * 0.2
    $shadow = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(64, 59, 42, 99))
    $white = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)
    $font = New-Font ([Math]::Max(1, $tile * 0.8))
    $fmt = New-Object System.Drawing.StringFormat
    $fmt.Alignment = 'Center'
    $fmt.LineAlignment = 'Center'

    for ($i = 0; $i -lt $n; $i++) {
        $x = $x0 + $i * ($tile + $gap)
        # Each tile tilts and bobs a little, like letters being placed.
        $dy = if ($i % 2) { -$tileH * 0.08 } else { $tileH * 0.04 }
        $g.FillPath($shadow, (New-RoundedRect $x ($y + $dy + $tileH * 0.07) $tile $tileH $r))
        $g.FillPath($white, (New-RoundedRect $x ($y + $dy) $tile $tileH $r))
        $txt = New-Object System.Drawing.SolidBrush (Color $colors[$i % $colors.Count])
        $rect = New-Object System.Drawing.RectangleF $x, ($y + $dy + $tileH * 0.04), $tile, $tileH
        $g.DrawString($letters[$i], $font, $txt, $rect, $fmt)
    }

    $g.Dispose()
    $bmp.Save((Join-Path $OutDir $file), [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host "  $file"
}

Write-Host "Writing icons to $OutDir"
Draw-Icon 180  'apple-touch-icon.png'
Draw-Icon 167  'apple-touch-icon-167.png'
Draw-Icon 152  'apple-touch-icon-152.png'
Draw-Icon 192  'icon-192.png'
Draw-Icon 512  'icon-512.png'
Draw-Icon 1024 'icon-1024.png'
Draw-Icon 512  'icon-512-maskable.png' 0.78
Draw-Icon 32   'favicon-32.png' 3.0 @('S')
