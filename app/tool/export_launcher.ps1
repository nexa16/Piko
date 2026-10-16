param([Parameter(Mandatory=$true)][string]$SourceProject)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$project = (Get-Content -Raw -LiteralPath $SourceProject | ConvertFrom-Json).piskel
if ($project.width -ne 64 -or $project.height -ne 64) { throw 'Expected the accepted 64x64 master.' }
$brandPath = Join-Path $PSScriptRoot '../assets/brand'
$resPath = Join-Path $PSScriptRoot '../android/app/src/main/res'
[IO.Directory]::CreateDirectory($brandPath) | Out-Null
function Read-Frame($layer, [int]$frame) {
  foreach ($chunk in $layer.chunks) {
    for ($x = 0; $x -lt $chunk.layout.Count; $x++) {
      for ($y = 0; $y -lt $chunk.layout[$x].Count; $y++) {
        if ($chunk.layout[$x][$y] -ne $frame) { continue }
        $stream = [IO.MemoryStream]::new([Convert]::FromBase64String(($chunk.base64PNG -split ',')[1]))
        $strip = [Drawing.Bitmap]::new($stream)
        try { return $strip.Clone([Drawing.Rectangle]::new($x*64,$y*64,64,64),[Drawing.Imaging.PixelFormat]::Format32bppArgb) }
        finally { $strip.Dispose(); $stream.Dispose() }
      }
    }
  }
  throw 'Missing source frame.'
}
function Save-Png($bitmap, [string]$path) {
  [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($path))) | Out-Null
  $bitmap.Save($path, [Drawing.Imaging.ImageFormat]::Png)
}
function Resize-Nearest($source, [int]$size) {
  $result = [Drawing.Bitmap]::new($size,$size,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
  for ($y=0; $y -lt $size; $y++) { for ($x=0; $x -lt $size; $x++) {
    $result.SetPixel($x,$y,$source.GetPixel([Math]::Min(63,[Math]::Floor(($x+0.5)*64/$size)),[Math]::Min(63,[Math]::Floor(($y+0.5)*64/$size))))
  }}
  return $result
}
$layers = @($project.layers | ForEach-Object { $_ | ConvertFrom-Json })
if ($layers.Count -ne 2 -or $layers[0].opacity -ne 1 -or $layers[1].opacity -ne 1) { throw 'Unexpected layer composition; inspect rather than approximate.' }
$background = Read-Frame $layers[0] 0
$foreground = Read-Frame $layers[1] 0
$icon = [Drawing.Bitmap]::new(64,64,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
try {
  $radius = 0.0
  for ($y=0; $y -lt 64; $y++) { for ($x=0; $x -lt 64; $x++) {
    $front = $foreground.GetPixel($x,$y)
    if ($front.A -ne 0 -and $front.A -ne 255) { throw 'Source has partial alpha; do not alter hand-edited pixels.' }
    $icon.SetPixel($x,$y, $(if ($front.A -eq 255) { $front } else { $background.GetPixel($x,$y) }))
    if ($front.A -gt 0) { $radius = [Math]::Max($radius,[Math]::Sqrt([Math]::Pow([Math]::Abs($x-31.5)+0.5,2)+[Math]::Pow([Math]::Abs($y-31.5)+0.5,2))) }
  }}
  Save-Png $icon (Join-Path $brandPath 'piko-app-icon.png')
  Save-Png $foreground (Join-Path $brandPath 'piko-app-icon-foreground.png')
  Save-Png $background (Join-Path $brandPath 'piko-app-icon-background.png')
  # Android's adaptive safe zone is a 66dp-diameter circle within 108dp.
  # Fit every opaque foreground pixel inside radius32dp, including rays/ears.
  $foregroundDp = [Math]::Min(64,64*32/$radius)
  foreach ($density in @(@('mdpi',1),@('hdpi',1.5),@('xhdpi',2),@('xxhdpi',3),@('xxxhdpi',4))) {
    $directory = Join-Path $resPath ('mipmap-'+$density[0])
    $legacy = Resize-Nearest $icon ([int](48*$density[1]))
    try { Save-Png $legacy (Join-Path $directory 'ic_launcher.png') } finally { $legacy.Dispose() }
    $size = [int](108*$density[1])
    $adaptiveBackground = Resize-Nearest $background $size
    $adaptiveForeground = [Drawing.Bitmap]::new($size,$size,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
      $scaledSize = [int][Math]::Floor($foregroundDp*$density[1])
      $scaled = Resize-Nearest $foreground $scaledSize
      try {
        $offset = [int][Math]::Floor(($size-$scaledSize)/2)
        for ($y=0; $y -lt $scaledSize; $y++) { for ($x=0; $x -lt $scaledSize; $x++) { $adaptiveForeground.SetPixel($x+$offset,$y+$offset,$scaled.GetPixel($x,$y)) }}
      } finally { $scaled.Dispose() }
      Save-Png $adaptiveForeground (Join-Path $directory 'ic_launcher_foreground.png')
      Save-Png $adaptiveBackground (Join-Path $directory 'ic_launcher_background.png')
    } finally { $adaptiveForeground.Dispose(); $adaptiveBackground.Dispose() }
  }
  Write-Output ('Exported source frame1 without pixel edits; adaptive foreground spans {0:N2}dp.' -f $foregroundDp)
} finally { $background.Dispose(); $foreground.Dispose(); $icon.Dispose() }
