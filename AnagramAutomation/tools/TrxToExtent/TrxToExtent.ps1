param(
    [string]$Trx = "..\..\TestResults\anagram-results.trx",
    [string]$Out = "..\..\TestResults\AnagramExtentReport.html"
)

if (-not (Test-Path $Trx)) {
    Write-Error "TRX file not found: $Trx"
    exit 1
}

[xml]$doc = Get-Content $Trx
$ns = New-Object System.Xml.XmlNamespaceManager($doc.NameTable)
$ns.AddNamespace('t', 'http://microsoft.com/schemas/VisualStudio/TeamTest/2010')

$scenarioDisplay = @{
  'CheckIfTwoStringsAreAnagrams' = 'Check if two strings are anagrams'
  'ValidateViaAPIIfTwoStringsAreAnagrams' = 'Validate via API if two strings are anagrams'
  'ValidateViaAnagramAPIIfTwoStringsAreAnagrams' = 'Validate via API if two strings are anagrams'
}

$scenarioOrder = @(
  'Check if two strings are anagrams',
  'Validate via API if two strings are anagrams'
)

function ConvertTo-Seconds([string]$value) {
  if (-not $value) { return $null }
  try {
    $ts = [TimeSpan]::Parse($value)
    return [double]$ts.TotalSeconds
  }
  catch {
    return $null
  }
}

function Format-Duration([double]$seconds) {
  if ($null -eq $seconds) { return 'N/A' }
  if ($seconds -lt 60) {
    return ('{0:0.00}s' -f [math]::Max(0, $seconds))
  }
  $ts = [TimeSpan]::FromSeconds([math]::Max(0, $seconds))
  if ($ts.TotalHours -ge 1) {
    return '{0:00}:{1:00}:{2:00}' -f [int]$ts.TotalHours, $ts.Minutes, $ts.Seconds
  }
  return '{0:00}:{1:00}' -f [int]$ts.TotalMinutes, $ts.Seconds
}

function Parse-DateSafe([string]$value) {
  if (-not $value) { return $null }
  try {
    return [DateTime]::Parse($value, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
  }
  catch {
    return $null
  }
}

function Get-ScenarioExampleOrder([string]$featurePath, [string]$scenarioTitle) {
  $order = @{}
  if (-not (Test-Path $featurePath)) { return $order }

  $lines = Get-Content $featurePath
  $inScenario = $false
  $inExamples = $false
  $headerRead = $false
  $index = 0

  foreach ($line in $lines) {
    if ($line -match '^\s*Scenario Outline:\s*(.+)$') {
      $current = $Matches[1].Trim()
      $inScenario = ($current -eq $scenarioTitle)
      $inExamples = $false
      $headerRead = $false
      continue
    }

    if (-not $inScenario) { continue }

    if ($line -match '^\s*Examples:\s*$') {
      $inExamples = $true
      continue
    }

    if ($inExamples -and $line -match '^\s*\|') {
      $parts = @($line.Trim() -split '\|') | Where-Object { $_ -ne '' } | ForEach-Object { $_.Trim() }
      if (-not $headerRead) {
        $headerRead = $true
        continue
      }
      if ($parts.Count -ge 3) {
        $key = "$($parts[0])|$($parts[1])|$($parts[2])"
        if (-not $order.ContainsKey($key)) {
          $index++
          $order[$key] = $index
        }
      }
      continue
    }

    if ($inExamples -and $line -match '^\s*$') { break }
  }

  return $order
}

$featurePath = Join-Path $PSScriptRoot "..\..\Features\Anagram_Checker.feature"
$logicExampleOrder = Get-ScenarioExampleOrder -featurePath $featurePath -scenarioTitle 'Check if two strings are anagrams'
$apiExampleOrder   = Get-ScenarioExampleOrder -featurePath $featurePath -scenarioTitle 'Validate via API if two strings are anagrams'
$expectedTotal = $logicExampleOrder.Count + $apiExampleOrder.Count

$rows = foreach ($r in $doc.SelectNodes('//t:UnitTestResult', $ns)) {
    $stdout = ''
    if ($r.Output -and $r.Output.StdOut) { $stdout = "$($r.Output.StdOut)" }
  $cleanName = $r.testName -replace ',\s*null\)', ')'

  $durationSeconds = ConvertTo-Seconds "$($r.duration)"
  $startTime = Parse-DateSafe "$($r.startTime)"
  $endTime = Parse-DateSafe "$($r.endTime)"
  if ($null -eq $durationSeconds -and $startTime -and $endTime) {
    $durationSeconds = [double]($endTime - $startTime).TotalSeconds
  }

  $scenarioKey = ''
  $scenarioName = 'Other'
  $input1 = ''
  $input2 = ''
  $expected = ''

  if ($cleanName -match '^(?<scenario>[^\(]+)\("(?<input1>.*?)","(?<input2>.*?)","(?<expected>.*?)"\)$') {
    $scenarioKey = $Matches['scenario']
    if ($scenarioDisplay.ContainsKey($scenarioKey)) {
      $scenarioName = $scenarioDisplay[$scenarioKey]
    }
    elseif ($scenarioKey -match '^ValidateVia.*APIIfTwoStringsAreAnagrams$') {
      $scenarioName = 'Validate via API if two strings are anagrams'
    }
    else {
      $scenarioName = $scenarioKey
    }
    $input1 = $Matches['input1']
    $input2 = $Matches['input2']
    $expected = $Matches['expected']
  }

  $exampleKey = "$input1|$input2|$expected"
  $exampleOrder = 9999
  if ($scenarioName -eq 'Check if two strings are anagrams' -and $logicExampleOrder.ContainsKey($exampleKey)) {
    $exampleOrder = [int]$logicExampleOrder[$exampleKey]
  }
  elseif ($scenarioName -eq 'Validate via API if two strings are anagrams' -and $apiExampleOrder.ContainsKey($exampleKey)) {
    $exampleOrder = [int]$apiExampleOrder[$exampleKey]
  }

    [PSCustomObject]@{
    Name         = $cleanName
    Outcome      = $r.outcome
    StdOut       = $stdout
    ScenarioName = $scenarioName
    Input1       = $input1
    Input2       = $input2
    Expected     = $expected
    ExampleOrder = $exampleOrder
    DurationSecs = $durationSeconds
    StartTime    = $startTime
    EndTime      = $endTime
    }
}

$total     = @($rows).Count
$passed    = @($rows | Where-Object { $_.Outcome -eq 'Passed' }).Count
$failed    = @($rows | Where-Object { $_.Outcome -eq 'Failed' }).Count
$other     = $total - $passed - $failed
$passRate  = if ($total -gt 0) { [math]::Round(($passed / $total) * 100) } else { 0 }
$generated = Get-Date -Format 'dd MMM yyyy  HH:mm:ss'
$missingCount = if ($expectedTotal -gt $total) { $expectedTotal - $total } else { 0 }

$runStart = $null
$runEnd = $null
$timesNode = $doc.SelectSingleNode('//t:TestRun/t:Times', $ns)
if ($timesNode) {
  $runStart = Parse-DateSafe "$($timesNode.start)"
  $runEnd = Parse-DateSafe "$($timesNode.finish)"
}

$totalSeconds = $null
if ($runStart -and $runEnd) {
  $totalSeconds = [double]($runEnd - $runStart).TotalSeconds
}
if ($null -eq $totalSeconds) {
  $totalSeconds = [double](($rows | Where-Object { $_.DurationSecs -ne $null } | Measure-Object -Property DurationSecs -Sum).Sum)
}
$totalExecutionTime = Format-Duration $totalSeconds

$scenarioStats = foreach ($scenario in $scenarioOrder) {
  $scenarioRows = @($rows | Where-Object { $_.ScenarioName -eq $scenario })
  if ($scenarioRows.Count -eq 0) { continue }
  $scenarioDurationSecs = [double](($scenarioRows | Where-Object { $_.DurationSecs -ne $null } | Measure-Object -Property DurationSecs -Sum).Sum)
  [PSCustomObject]@{
    Scenario = $scenario
    Total = $scenarioRows.Count
    Passed = @($scenarioRows | Where-Object { $_.Outcome -eq 'Passed' }).Count
    Failed = @($scenarioRows | Where-Object { $_.Outcome -eq 'Failed' }).Count
    Duration = (Format-Duration $scenarioDurationSecs)
  }
}

$timedRows = @($rows | Where-Object { $_.StartTime -and $_.EndTime } | Sort-Object StartTime)
$hasOverlap = $false
if ($timedRows.Count -gt 1) {
  $maxEnd = $timedRows[0].EndTime
  for ($idx = 1; $idx -lt $timedRows.Count; $idx++) {
    $current = $timedRows[$idx]
    if ($current.StartTime -lt $maxEnd) {
      $hasOverlap = $true
      break
    }
    if ($current.EndTime -gt $maxEnd) { $maxEnd = $current.EndTime }
  }
}
$observedExecutionMode = if ($hasOverlap) { 'Parallelizable (overlap observed)' } else { 'NonParallelizable / Sequential (no overlap observed)' }

function HtmlEncode([string]$s) {
    if (-not $s) { return '' }
    return ($s -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;' -replace '"', '&quot;' -replace "'", '&#39;')
}

# Parse SpecFlow StdOut into step objects and return HTML
function Build-StepsHtml([string]$stdout) {
    if (-not $stdout) { return '' }

    $lines = $stdout -split '[\r\n]+' | Where-Object { $_ -ne '' }
    $steps = [System.Collections.ArrayList]@()
    $cur   = $null

    foreach ($line in $lines) {
        if ($line -match '^(Given|When|Then|And|But)\b') {
            if ($cur) { $null = $steps.Add($cur) }
            $cur = @{ Text = $line; TableRows = [System.Collections.ArrayList]@()
                      Status = 'pending'; Time = ''; ErrorMsg = '' }
        }
        elseif ($cur -and $line -match '^\s*\|') {
            $null = $cur.TableRows.Add($line.Trim())
        }
        elseif ($cur -and $line -match '^->\s*done:.*\(([\d.]+s)\)') {
            $cur.Status = 'done'; $cur.Time = $Matches[1]
        }
        elseif ($cur -and $line -match '^->\s*error:(.*)') {
            $cur.Status = 'error'; $cur.ErrorMsg = $Matches[1].Trim()
        }
        elseif ($cur -and $line -match '^->\s*skipped') {
            $cur.Status = 'skipped'
        }
        # "--- table step argument ---" lines are ignored
    }
    if ($cur) { $null = $steps.Add($cur) }
    if ($steps.Count -eq 0) { return '' }

    $sb = [System.Text.StringBuilder]::new()
    foreach ($step in $steps) {
        $cls = 'step-and'
        if     ($step.Text -match '^Given') { $cls = 'step-given' }
        elseif ($step.Text -match '^When')  { $cls = 'step-when'  }
        elseif ($step.Text -match '^Then')  { $cls = 'step-then'  }

        # Split keyword from the rest of the line
        $kw = ''; $rest = $step.Text
        if ($step.Text -match '^(\w+)\s+(.+)$') { $kw = $Matches[1]; $rest = $Matches[2] }

        $icon = switch ($step.Status) {
            'done'    { "<span class='s-ok'>&#10003;</span> " }
            'error'   { "<span class='s-err'>&#10007;</span> " }
            'skipped' { "<span class='s-skip'>&#8212;</span> " }
            default   { '' }
        }
        $time = if ($step.Time) { " <span class='s-time'>($($step.Time))</span>" } else { '' }

        $null = $sb.Append("<div class='step $cls'>$icon<strong>$(HtmlEncode $kw)</strong> $(HtmlEncode $rest)$time</div>")

        foreach ($tr in $step.TableRows) {
            $null = $sb.Append("<div class='step-tbl'>$(HtmlEncode $tr)</div>")
        }
        if ($step.Status -eq 'error' -and $step.ErrorMsg) {
            $null = $sb.Append("<div class='s-errmsg'>$(HtmlEncode $step.ErrorMsg)</div>")
        }
    }
    return $sb.ToString()
}

# ── Static HTML header ─────────────────────────────────────────────────────
$html = @"
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>SMBC - Anagram Checker Test Report</title>
  <style>
    *{box-sizing:border-box;margin:0;padding:0}
    body{font-family:'Segoe UI',Arial,sans-serif;background:#f0f2f5;color:#333}

    /* Header */
    .header{background:linear-gradient(135deg,#1a1a2e 0%,#16213e 50%,#0f3460 100%);
            color:#fff;padding:32px 40px;display:flex;align-items:center;justify-content:space-between}
    .header h1{font-size:1.8rem;font-weight:700;letter-spacing:.5px}
    .header h1 span{color:#e94560}
    .header .meta{font-size:.8rem;color:#aac;text-align:right;line-height:1.8}

    /* Summary cards */
    .summary{display:flex;gap:16px;padding:24px 40px}
    .stat{flex:1;border-radius:10px;padding:20px 24px;color:#fff;box-shadow:0 4px 12px rgba(0,0,0,.15)}
    .stat-total{background:linear-gradient(135deg,#667eea,#764ba2)}
    .stat-pass {background:linear-gradient(135deg,#11998e,#38ef7d)}
    .stat-fail {background:linear-gradient(135deg,#e52d27,#b31217)}
    .stat-skip {background:linear-gradient(135deg,#f7971e,#ffd200)}
    .stat .number{font-size:2.4rem;font-weight:700;line-height:1}
    .stat .label{font-size:.75rem;text-transform:uppercase;letter-spacing:1px;opacity:.85;margin-top:4px}

    /* Progress bar */
    .progress-wrap{padding:0 40px 24px}
    .progress-bar{height:8px;border-radius:4px;background:#dde;overflow:hidden}
    .progress-fill{height:100%;background:linear-gradient(90deg,#11998e,#38ef7d);border-radius:4px}
    .progress-label{font-size:.78rem;color:#888;margin-top:6px}

    /* Table */
    .table-wrap{margin:0 40px 40px;background:#fff;border-radius:10px;
                box-shadow:0 2px 8px rgba(0,0,0,.08);overflow:hidden}
    table{width:100%;border-collapse:collapse}
    thead{background:#1a1a2e;color:#fff}
    th{padding:14px 18px;font-size:.78rem;text-transform:uppercase;letter-spacing:.8px;text-align:left}
    td{padding:13px 18px;border-bottom:1px solid #f0f2f5;font-size:.88rem;vertical-align:top}
    tr:last-child td{border-bottom:none}
    .test-name{font-weight:500;color:#1a1a2e;margin-bottom:2px}

    /* Badges */
    .badge{display:inline-block;padding:3px 12px;border-radius:20px;font-size:.75rem;font-weight:600;letter-spacing:.4px}
    .badge-pass{background:#d4f8e8;color:#0a7a4a}
    .badge-fail{background:#fde8e8;color:#c0392b}
    .badge-skip{background:#fff3cd;color:#856404}

    /* Steps toggle */
    details.steps{margin-top:6px}
    details.steps > summary{font-size:.74rem;color:#6c757d;cursor:pointer;list-style:none;
                             display:inline-flex;align-items:center;gap:5px;user-select:none;
                             padding:2px 8px;border-radius:4px;background:#f0f2f5;
                             border:1px solid #dee2e6}
    details.steps > summary::-webkit-details-marker{display:none}
    details.steps > summary::before{content:'▶';font-size:.5rem;transition:transform .2s}
    details[open].steps > summary::before{transform:rotate(90deg)}

    /* Steps block */
    .steps-block{margin-top:8px;padding:10px 14px;background:#f8f9fc;
                 border-radius:6px;border-left:3px solid #dee2e6}
    .step{font-family:'Cascadia Code','Consolas',monospace;font-size:.81rem;
          padding:4px 2px;line-height:1.6}
    .step-given{color:#7c3aed}
    .step-when {color:#d97706}
    .step-then {color:#059669}
    .step-and  {color:#6b7280}
    .step-tbl  {font-family:'Cascadia Code','Consolas',monospace;font-size:.76rem;
                color:#9ca3af;padding:1px 0 1px 20px}
    .s-ok   {color:#059669}
    .s-err  {color:#dc2626}
    .s-skip {color:#9ca3af}
    .s-time {color:#9ca3af;font-size:.72rem;font-weight:400}
    .s-errmsg{font-size:.78rem;color:#dc2626;background:#fef2f2;border-radius:4px;
              padding:4px 8px;margin-top:4px;font-family:'Cascadia Code','Consolas',monospace}

    .exec-wrap{margin:0 40px 24px;background:#fff;border-radius:10px;box-shadow:0 2px 8px rgba(0,0,0,.08);overflow:hidden}
    .exec-grid{display:grid;grid-template-columns:1fr 1fr;gap:12px;padding:16px 18px;border-bottom:1px solid #eef2f7}
    .exec-item{background:#f8f9fc;border:1px solid #e7ecf3;border-radius:8px;padding:10px 12px}
    .exec-key{font-size:.72rem;text-transform:uppercase;color:#708090;letter-spacing:.6px}
    .exec-val{font-size:.9rem;color:#1f2a37;margin-top:3px;font-weight:600}
    .scenario-time{width:100%;border-collapse:collapse}
    .scenario-time th,.scenario-time td{padding:10px 14px;border-bottom:1px solid #f0f2f5;font-size:.82rem;text-align:left}
    .scenario-time th{background:#f7f9fc;color:#4d5b6a;text-transform:uppercase;letter-spacing:.6px;font-size:.72rem}
    .scenario-time tr:last-child td{border-bottom:none}
  </style>
</head>
<body>

  <div class="header">
    <h1>SMBC - Anagram Checker <span>Test Report</span></h1>
    <div class="meta">
      <div>Generated: $generated</div>
      <div>Framework: SpecFlow + NUnit</div>
    </div>
  </div>

  <div class="summary">
    <div class="stat stat-total"><div class="number">$total</div><div class="label">Total Tests</div></div>
    <div class="stat stat-pass"> <div class="number">$passed</div><div class="label">Passed</div></div>
    <div class="stat stat-fail"> <div class="number">$failed</div><div class="label">Failed</div></div>
    <div class="stat stat-skip"> <div class="number">$other</div><div class="label">Skipped</div></div>
  </div>

  <div class="progress-wrap">
    <div class="progress-bar"><div class="progress-fill" style="width:$passRate%"></div></div>
    <div class="progress-label">$passRate% pass rate</div>
  </div>

  <div class="exec-wrap">
    <div class="exec-grid">
      <div class="exec-item">
        <div class="exec-key">Observed Mode</div>
        <div class="exec-val">$(HtmlEncode $observedExecutionMode)</div>
      </div>
      <div class="exec-item">
        <div class="exec-key">Total Execution Time</div>
        <div class="exec-val">$(HtmlEncode $totalExecutionTime)</div>
      </div>
    </div>
    <table class="scenario-time">
      <thead>
        <tr><th>Scenario</th><th>Total</th><th>Passed</th><th>Failed</th><th>Execution Time</th></tr>
      </thead>
      <tbody>
$(
  ($scenarioStats | ForEach-Object {
    "        <tr><td>$(HtmlEncode $_.Scenario)</td><td>$($_.Total)</td><td>$($_.Passed)</td><td>$($_.Failed)</td><td>$(HtmlEncode $_.Duration)</td></tr>"
  }) -join "`n"
)
      </tbody>
    </table>
  </div>

  $(if ($missingCount -gt 0) {
@"
  <div style="margin:0 40px 18px;padding:10px 14px;border-radius:8px;background:#fff3cd;border:1px solid #ffe69c;color:#856404;font-size:.82rem;">
    Warning: $missingCount expected test(s) are missing from this report (expected $expectedTotal from feature examples, found $total in TRX). This usually means the run did not execute all tests.
  </div>
"@
} else { '' })

  <div style="padding:0 40px; font-size:.82rem; color:#6b7280; margin-bottom:10px;">
    Results are grouped by scenario outline and shown data-row-wise.
  </div>
"@

# ── Grouped per-scenario HTML ───────────────────────────────────────────────
foreach ($scenario in $scenarioOrder) {
    $scenarioRows = @(
        $rows |
        Where-Object { $_.ScenarioName -eq $scenario } |
        Sort-Object -Property @{ Expression = 'ExampleOrder'; Ascending = $true }, @{ Expression = 'Input1'; Ascending = $true }
    )

    if ($scenarioRows.Count -eq 0) { continue }

    $html += @"
  <div class="table-wrap">
    <table>
      <thead>
        <tr>
          <th colspan="6" style="text-transform:none;font-size:.9rem;letter-spacing:.2px;">Scenario Outline: $(HtmlEncode $scenario)</th>
        </tr>
        <tr><th>#</th><th>Input 1</th><th>Input 2</th><th>Expected</th><th>Result</th><th>Details</th></tr>
      </thead>
      <tbody>
"@

    $i = 1
    foreach ($row in $scenarioRows) {
        $badge = 'badge-skip'
        if     ($row.Outcome -eq 'Passed') { $badge = 'badge-pass' }
        elseif ($row.Outcome -eq 'Failed') { $badge = 'badge-fail' }

        $stepsHtml    = Build-StepsHtml $row.StdOut
        $stepsSection = ''
        if ($stepsHtml) {
            $stepsSection = "<details class='steps'><summary>Steps</summary><div class='steps-block'>$stepsHtml</div></details>"
        }

        $html += @"
        <tr>
          <td style="color:#aaa;font-size:.8rem;white-space:nowrap">$i</td>
          <td>$(HtmlEncode $row.Input1)</td>
          <td>$(HtmlEncode $row.Input2)</td>
          <td>$(HtmlEncode $row.Expected)</td>
          <td style="white-space:nowrap"><span class="badge $badge">$($row.Outcome)</span></td>
          <td>$stepsSection</td>
        </tr>
"@
        $i++
    }

    $html += @"
      </tbody>
    </table>
  </div>
"@
}

$html += @"
</body>
</html>
"@

$outDir = Split-Path -Parent $Out
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

Set-Content -Path $Out -Value $html -Encoding UTF8
Write-Host "Report generated: $Out"
