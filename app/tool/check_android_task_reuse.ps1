[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$Adb,
  [Parameter(Mandatory=$true)][string]$Device
)

# Run against an explicitly selected emulator with an ordinary Piko candidate.
# Exercises navigation only; never removes tasks, data or installed packages.
$ErrorActionPreference='Stop'
$taskPackage='io.github.nexa16.piko'
function Invoke-TaskAdb([string[]]$Arguments) {
  $taskOutput=@(& $Adb -s $Device @Arguments 2>&1)
  if ($LASTEXITCODE -ne 0) {throw 'Android task check failed; no fallback attempted.'}
  return ($taskOutput -join "`n")
}
function Assert-OnePikoTask([string]$Phase) {
  $taskDump=Invoke-TaskAdb @('shell','dumpsys','activity','recents')
  $taskHeads=[regex]::Matches($taskDump,'(?m)^\s*\* Recent #\d+: Task\{[^\r\n]+')
  $taskOwn=@($taskHeads | Where-Object {
    $_.Value -match '(?:I=io\.github\.nexa16\.piko/\.MainActivity|A=\d+:io\.github\.nexa16\.piko)(?:\s|\})'
  })
  if ($taskOwn.Count -ne 1) {throw "Expected exactly one Piko task after $Phase; observed $($taskOwn.Count)."}
  $taskId=[regex]::Match($taskOwn[0].Value,' #(\d+) ').Groups[1].Value
  if (!$taskId) {throw 'Missing task identity.'}
  [pscustomobject]@{phase=$Phase;tasks=1;taskId=$taskId}
}
if ($Device -notmatch '^emulator-\d+$') {
  throw 'This synthetic navigation check requires an explicitly named emulator.'
}
$taskRows=@()
foreach ($taskPhase in @('launcher','component','background-return','repeated-launcher')) {
  if ($taskPhase -eq 'background-return') {
    $null=Invoke-TaskAdb @('shell','input','keyevent','KEYCODE_HOME')
  }
  $taskArgs=@('shell','am','start','-W','-n',"$taskPackage/.MainActivity")
  if ($taskPhase -ne 'component') {
    $taskArgs+=@('-a','android.intent.action.MAIN','-c','android.intent.category.LAUNCHER')
  }
  $null=Invoke-TaskAdb $taskArgs
  $taskRows+=Assert-OnePikoTask $taskPhase
}
$taskIds=@($taskRows.taskId | Select-Object -Unique)
if ($taskIds.Count -ne 1) {throw 'Launcher/component paths created different tasks.'}
$taskRows | ConvertTo-Json
