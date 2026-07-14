param(
  [ValidateSet('send', 'send-image', 'wait')]
  [string]$Mode = 'send',
  [string]$Action = '',
  [string]$Payload = '',
  [switch]$Base64,
  [string]$RequestId = '',
  [string]$Target = '',
  [string]$ImagePath = '',
  [int]$WaitSeconds = 30
)

$ErrorActionPreference = 'Stop'
$Hdc = 'C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
$Bundle = 'com.example.glma2uicard'
$Ability = 'EntryAbility'

if (-not (Test-Path -LiteralPath $Hdc)) {
  throw "HDC not found: $Hdc"
}

function Invoke-Hdc {
  param([string[]]$Arguments)
  & $Hdc @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "HDC command failed with exit code $LASTEXITCODE"
  }
}

function Resolve-Target {
  if ($Target.Length -gt 0) {
    return $Target
  }
  $lines = @(& $Hdc list targets -v)
  $connected = @($lines | Where-Object { $_ -match '\sConnected\s' -and $_ -notmatch '^COM' })
  if ($connected.Count -ne 1) {
    throw 'Specify -Target when HDC does not expose exactly one connected device.'
  }
  return (($connected[0] -split '\s+')[0]).Trim()
}

function New-RequestId {
  return 'ps-' + [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds().ToString()
}

function Find-AbilityRecordId {
  param([string]$ResolvedTarget)
  $raw = (& $Hdc -t $ResolvedTarget shell aa dump -l) -join "`n"
  $blocks = $raw -split '(?=\s+Mission ID #)'
  foreach ($block in $blocks) {
    if ($block -match "bundle name \[$Bundle\]" -and $block -match 'AbilityRecord ID #(\d+)') {
      return $Matches[1]
    }
  }
  return ''
}

function Read-DebugResult {
  param(
    [string]$ResolvedTarget,
    [string]$WantedRequestId
  )
  $recordId = Find-AbilityRecordId -ResolvedTarget $ResolvedTarget
  if ($recordId.Length -eq 0) {
    return ''
  }
  $dump = (& $Hdc -t $ResolvedTarget shell aa dump -i $recordId -c) -join "`n"
  $matches = @($dump -split "`n" | Where-Object {
    $_ -match 'HDC_DEBUG_RESULT' -and $_ -match [regex]::Escape($WantedRequestId) -and
      ($_ -match '"status":"succeeded"' -or $_ -match '"status":"failed"')
  })
  if ($matches.Count -gt 0) {
    return $matches[$matches.Count - 1].Trim()
  }
  return ''
}

function Send-DebugCommand {
  param(
    [string]$ResolvedTarget,
    [string]$CommandAction,
    [string]$CommandPayload,
    [string]$CommandRequestId,
    [switch]$UseBase64
  )
  $args = @('-t', $ResolvedTarget, 'shell', 'aa', 'start', '-a', $Ability, '-b', $Bundle,
    '--ps', 'debugAction', $CommandAction, '--ps', 'debugRequestId', $CommandRequestId)
  if ($UseBase64) {
    $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($CommandPayload))
    $args += @('--ps', 'debugPayloadBase64', $encoded)
  } elseif ($CommandPayload.Length -gt 0) {
    $args += @('--ps', 'debugPayload', $CommandPayload)
  }
  Invoke-Hdc -Arguments $args
}

function Convert-ImageToJpeg {
  param([string]$SourcePath, [string]$OutputPath)
  Add-Type -AssemblyName System.Drawing
  $image = [System.Drawing.Image]::FromFile($SourcePath)
  try {
    $width = 480
    $height = [int]($image.Height * $width / $image.Width)
    $bitmap = [System.Drawing.Bitmap]::new($width, $height)
    try {
      $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
      try {
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.DrawImage($image, 0, 0, $width, $height)
      } finally {
        $graphics.Dispose()
      }
      $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
        Where-Object { $_.MimeType -eq 'image/jpeg' }
      $encoderParams = [System.Drawing.Imaging.EncoderParameters]::new(1)
      $encoderParams.Param[0] = [System.Drawing.Imaging.EncoderParameter]::new(
        [System.Drawing.Imaging.Encoder]::Quality, [long]25)
      $bitmap.Save($OutputPath, $codec, $encoderParams)
    } finally {
      $bitmap.Dispose()
    }
  } finally {
    $image.Dispose()
  }
}

$resolvedTarget = Resolve-Target
if ($RequestId.Length -eq 0) {
  $RequestId = New-RequestId
}

if ($Mode -eq 'send') {
  if ($Action.Length -eq 0) {
    throw '-Action is required in send mode.'
  }
  Send-DebugCommand -ResolvedTarget $resolvedTarget -CommandAction $Action -CommandPayload $Payload `
    -CommandRequestId $RequestId -UseBase64:$Base64
  Write-Output "requestId=$RequestId target=$resolvedTarget action=$Action"
}

if ($Mode -eq 'send-image') {
  if ($ImagePath.Length -eq 0 -or -not (Test-Path -LiteralPath $ImagePath)) {
    throw '-ImagePath must point to an existing image.'
  }
  $tempImage = Join-Path $env:TEMP ('glm-hdc-' + $RequestId + '.jpg')
  Convert-ImageToJpeg -SourcePath $ImagePath -OutputPath $tempImage
  try {
    $imageBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($tempImage))
    $chunkSize = 10000
    $total = [int][Math]::Ceiling($imageBase64.Length / $chunkSize)
    if ($total -gt 32) {
      throw 'compressed image requires too many HDC chunks.'
    }
    Send-DebugCommand -ResolvedTarget $resolvedTarget -CommandAction 'resetForgeImageTransfer' `
      -CommandPayload '' -CommandRequestId ($RequestId + '-reset')
    for ($index = 0; $index -lt $total; $index++) {
      $start = $index * $chunkSize
      $length = [Math]::Min($chunkSize, $imageBase64.Length - $start)
      $chunk = $imageBase64.Substring($start, $length)
      $chunkPayload = @{ index = $index; total = $total; data = $chunk } | ConvertTo-Json -Compress
      Send-DebugCommand -ResolvedTarget $resolvedTarget -CommandAction 'appendForgeImageChunk' `
        -CommandPayload $chunkPayload -CommandRequestId ($RequestId + '-chunk-' + $index.ToString()) -UseBase64
    }
    Send-DebugCommand -ResolvedTarget $resolvedTarget -CommandAction 'finishForgeImageTransfer' `
      -CommandPayload '' -CommandRequestId $RequestId
    Write-Output "requestId=$RequestId target=$resolvedTarget action=finishForgeImageTransfer chunks=$total"
  } finally {
    Remove-Item -LiteralPath $tempImage -Force -ErrorAction SilentlyContinue
  }
}

if ($Mode -eq 'wait') {
  $deadline = [DateTime]::UtcNow.AddSeconds([Math]::Max(1, [Math]::Min($WaitSeconds, 300)))
  do {
    $line = Read-DebugResult -ResolvedTarget $resolvedTarget -WantedRequestId $RequestId
    if ($line.Length -gt 0) {
      Write-Output $line
      exit 0
    }
    Start-Sleep -Milliseconds 500
  } while ([DateTime]::UtcNow -lt $deadline)
  throw "Timed out waiting for requestId=$RequestId"
}
