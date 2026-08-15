Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$paper = [System.Drawing.ColorTranslator]::FromHtml('#F7F5EF')
$forest = [System.Drawing.ColorTranslator]::FromHtml('#315B4A')
$saffron = [System.Drawing.ColorTranslator]::FromHtml('#E5A73C')

function New-OnwardBitmap {
  param(
    [int]$Size,
    [bool]$Transparent = $false,
    [bool]$MarkOnly = $false
  )

  $bitmap = [System.Drawing.Bitmap]::new($Size, $Size)
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  if ($Transparent) {
    $graphics.Clear([System.Drawing.Color]::Transparent)
  } else {
    $graphics.Clear($forest)
  }

  $scale = $Size / 1024.0
  $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
  $path.AddLine(205 * $scale, 710 * $scale, 405 * $scale, 710 * $scale)
  $path.AddBezier(
    405 * $scale, 710 * $scale,
    530 * $scale, 710 * $scale,
    570 * $scale, 590 * $scale,
    650 * $scale, 500 * $scale
  )
  $path.AddLine(650 * $scale, 500 * $scale, 802 * $scale, 304 * $scale)

  $lineColor = if ($MarkOnly) { $forest } else { $paper }
  $pen = [System.Drawing.Pen]::new($lineColor, 86 * $scale)
  $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
  $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
  $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
  $graphics.DrawPath($pen, $path)

  $dot = 52 * $scale
  $graphics.FillEllipse(
    [System.Drawing.SolidBrush]::new($saffron),
    802 * $scale - $dot,
    304 * $scale - $dot,
    $dot * 2,
    $dot * 2
  )

  $pen.Dispose()
  $path.Dispose()
  $graphics.Dispose()
  return $bitmap
}

function Save-OnwardIcon {
  param([string]$Path, [int]$Size)
  $bitmap = New-OnwardBitmap -Size $Size
  $directory = Split-Path -Parent $Path
  [System.IO.Directory]::CreateDirectory($directory) | Out-Null
  $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
  $bitmap.Dispose()
}

$android = @{
  'mipmap-mdpi' = 48
  'mipmap-hdpi' = 72
  'mipmap-xhdpi' = 96
  'mipmap-xxhdpi' = 144
  'mipmap-xxxhdpi' = 192
}
foreach ($entry in $android.GetEnumerator()) {
  Save-OnwardIcon -Path (Join-Path $root "android/app/src/main/res/$($entry.Key)/ic_launcher.png") -Size $entry.Value
}

$ios = @{
  'Icon-App-20x20@1x.png' = 20
  'Icon-App-20x20@2x.png' = 40
  'Icon-App-20x20@3x.png' = 60
  'Icon-App-29x29@1x.png' = 29
  'Icon-App-29x29@2x.png' = 58
  'Icon-App-29x29@3x.png' = 87
  'Icon-App-40x40@1x.png' = 40
  'Icon-App-40x40@2x.png' = 80
  'Icon-App-40x40@3x.png' = 120
  'Icon-App-60x60@2x.png' = 120
  'Icon-App-60x60@3x.png' = 180
  'Icon-App-76x76@1x.png' = 76
  'Icon-App-76x76@2x.png' = 152
  'Icon-App-83.5x83.5@2x.png' = 167
  'Icon-App-1024x1024@1x.png' = 1024
}
$iosRoot = Join-Path $root 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
foreach ($entry in $ios.GetEnumerator()) {
  Save-OnwardIcon -Path (Join-Path $iosRoot $entry.Key) -Size $entry.Value
}

$web = @{
  'web/favicon.png' = 32
  'web/icons/Icon-192.png' = 192
  'web/icons/Icon-512.png' = 512
  'web/icons/Icon-maskable-192.png' = 192
  'web/icons/Icon-maskable-512.png' = 512
}
foreach ($entry in $web.GetEnumerator()) {
  Save-OnwardIcon -Path (Join-Path $root $entry.Key) -Size $entry.Value
}

$launchRoot = Join-Path $root 'ios/Runner/Assets.xcassets/LaunchImage.imageset'
foreach ($entry in @(
  @{ Name = 'LaunchImage.png'; Size = 168 },
  @{ Name = 'LaunchImage@2x.png'; Size = 336 },
  @{ Name = 'LaunchImage@3x.png'; Size = 504 }
)) {
  $bitmap = New-OnwardBitmap -Size $entry.Size -Transparent $true -MarkOnly $true
  $bitmap.Save(
    (Join-Path $launchRoot $entry.Name),
    [System.Drawing.Imaging.ImageFormat]::Png
  )
  $bitmap.Dispose()
}
