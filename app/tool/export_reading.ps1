param([Parameter(Mandatory=$true)][string]$SourceProject)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$project = (Get-Content -Raw -LiteralPath $SourceProject | ConvertFrom-Json).piskel
if ($project.width -ne 64 -or $project.height -ne 64) { throw 'Expected the approved 64x64 master.' }
$layers = @($project.layers | ForEach-Object { $_ | ConvertFrom-Json })
if ($layers.Count -ne 2 -or $layers[0].opacity -ne 1 -or $layers[1].opacity -ne 1) { throw 'Unexpected source layers; inspect rather than approximate.' }
function Read-ReadingFrame($layer) {
  foreach ($chunk in $layer.chunks) {
    for ($x=0; $x -lt $chunk.layout.Count; $x++) {
      for ($y=0; $y -lt $chunk.layout[$x].Count; $y++) {
        if ($chunk.layout[$x][$y] -ne 2) { continue }
        $stream = [IO.MemoryStream]::new([Convert]::FromBase64String(($chunk.base64PNG -split ',')[1]))
        $strip = [Drawing.Bitmap]::new($stream)
        try { return $strip.Clone([Drawing.Rectangle]::new($x*64,$y*64,64,64),[Drawing.Imaging.PixelFormat]::Format32bppArgb) }
        finally { $strip.Dispose(); $stream.Dispose() }
      }
    }
  }
  throw 'Missing source frame 3.'
}
$background = Read-ReadingFrame $layers[0]
$reading = Read-ReadingFrame $layers[1]
try {
  for ($y=0; $y -lt 64; $y++) { for ($x=0; $x -lt 64; $x++) {
    if ($background.GetPixel($x,$y).A -ne 0) { throw 'Reading background must be transparent.' }
    if ($reading.GetPixel($x,$y).A -notin @(0,255)) { throw 'Do not alter partially transparent source pixels.' }
  }}
  $destination = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../assets/brand/piko-reading.png'))
  $reading.Save($destination,[Drawing.Imaging.ImageFormat]::Png)
  # Decode the exported file and compare every pixel to the source frame.
  $exported = [Drawing.Bitmap]::new($destination)
  try {
    for ($y=0; $y -lt 64; $y++) { for ($x=0; $x -lt 64; $x++) {
      if ($reading.GetPixel($x,$y).ToArgb() -ne $exported.GetPixel($x,$y).ToArgb()) { throw 'Export changed an approved pixel.' }
    }}
  } finally { $exported.Dispose() }
  'Exported frame 3: all source pixels preserved; transparent 64x64 master.'
} finally { $background.Dispose(); $reading.Dispose() }
