# ─────────────────────────────────────────────────────────────
# patch-management.ps1 — Simulated Windows patch workflow
#
# Demonstrates enterprise patch management concepts including
# compliance reporting, approval workflow, and change control.
# On-prem analogue to AWS SSM Patch Manager.
# ─────────────────────────────────────────────────────────────

#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [ValidateSet('Scan', 'Report', 'Apply', 'Full')]
    [string]$Mode = 'Full',

    [Parameter()]
    [string]$ReportPath = "$PSScriptRoot\..\docs\patch-report-$(Get-Date -Format 'yyyyMMdd').html",

    [Parameter()]
    [switch]$Force   # Skip approval prompt (for CI/automation)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Color helpers ────────────────────────────────────────────
function Write-Info  { param($Msg) Write-Host "[INFO]  $Msg" -ForegroundColor Cyan }
function Write-Ok    { param($Msg) Write-Host "[PASS]  $Msg" -ForegroundColor Green }
function Write-Warn  { param($Msg) Write-Host "[WARN]  $Msg" -ForegroundColor Yellow }
function Write-Err   { param($Msg) Write-Host "[ERROR] $Msg" -ForegroundColor Red }

# ── Simulated patch database ─────────────────────────────────
$SimulatedPatches = @(
    [PSCustomObject]@{ KB = 'KB5034441'; Title = 'Security Update for Windows Server 2022'; Severity = 'Critical'; Category = 'Security Updates';   Size = '245 MB'; Status = 'Pending' }
    [PSCustomObject]@{ KB = 'KB5035942'; Title = '.NET Framework 4.8.1 Cumulative Update';  Severity = 'Important'; Category = 'Update Rollups';    Size = '87 MB';  Status = 'Pending' }
    [PSCustomObject]@{ KB = 'KB5034765'; Title = 'Windows Defender Definition Update';       Severity = 'Important'; Category = 'Definition Updates'; Size = '3 MB';   Status = 'Pending' }
    [PSCustomObject]@{ KB = 'KB5033118'; Title = 'Cumulative Update for Windows Server 2022';Severity = 'Moderate';  Category = 'Update Rollups';    Size = '512 MB'; Status = 'Pending' }
    [PSCustomObject]@{ KB = 'KB890830';  Title = 'Malicious Software Removal Tool';          Severity = 'Low';       Category = 'Tools';              Size = '56 MB';  Status = 'Pending' }
)

# ── Step 1: Scan for available updates ──────────────────────
function Invoke-PatchScan {
    Write-Info "Scanning for available Windows updates (simulated)..."
    Start-Sleep -Milliseconds 800  # Simulate scan time

    $criticalCount  = ($SimulatedPatches | Where-Object Severity -eq 'Critical').Count
    $importantCount = ($SimulatedPatches | Where-Object Severity -eq 'Important').Count

    Write-Host ""
    Write-Host "  Available patches:" -ForegroundColor White
    $SimulatedPatches | Format-Table KB, Severity, Title, Size -AutoSize

    Write-Host "  Summary: $($SimulatedPatches.Count) patches — " -NoNewline
    Write-Host "$criticalCount Critical  " -ForegroundColor Red -NoNewline
    Write-Host "$importantCount Important" -ForegroundColor Yellow

    return $SimulatedPatches
}

# ── Step 2: Compliance report ────────────────────────────────
function New-ComplianceReport {
    param([array]$Patches)

    Write-Info "Generating compliance report..."

    $hostname    = $env:COMPUTERNAME
    $reportDate  = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $osVersion   = [System.Environment]::OSVersion.VersionString
    $lastPatch   = Get-Date (Get-Date).AddDays(-14) -Format 'yyyy-MM-dd'  # Simulated

    $criticalPatches  = $Patches | Where-Object Severity -eq 'Critical'
    $complianceStatus = if ($criticalPatches.Count -gt 0) { 'NON-COMPLIANT' } else { 'COMPLIANT' }
    $complianceColor  = if ($complianceStatus -eq 'COMPLIANT') { 'Green' } else { 'Red' }

    $report = [PSCustomObject]@{
        Hostname         = $hostname
        ReportDate       = $reportDate
        OSVersion        = $osVersion
        LastPatchDate    = $lastPatch
        TotalPatches     = $Patches.Count
        CriticalCount    = ($Patches | Where-Object Severity -eq 'Critical').Count
        ImportantCount   = ($Patches | Where-Object Severity -eq 'Important').Count
        ModerateCount    = ($Patches | Where-Object Severity -eq 'Moderate').Count
        LowCount         = ($Patches | Where-Object Severity -eq 'Low').Count
        ComplianceStatus = $complianceStatus
        Patches          = $Patches
    }

    Write-Host ""
    Write-Host "  ┌─────────────────────────────────────┐" -ForegroundColor Gray
    Write-Host "  │  COMPLIANCE REPORT                  │" -ForegroundColor Gray
    Write-Host "  ├─────────────────────────────────────┤" -ForegroundColor Gray
    Write-Host "  │  Host    : $($report.Hostname.PadRight(25))│" -ForegroundColor Gray
    Write-Host "  │  Date    : $($reportDate.PadRight(25))│" -ForegroundColor Gray
    Write-Host "  │  OS      : $(($osVersion.Substring(0, [Math]::Min(25, $osVersion.Length))).PadRight(25))│" -ForegroundColor Gray
    Write-Host "  │  Status  : $($complianceStatus.PadRight(25))│" -ForegroundColor $complianceColor
    Write-Host "  └─────────────────────────────────────┘" -ForegroundColor Gray

    # Write HTML report
    $htmlBody = $Patches | ConvertTo-Html -Property KB, Title, Severity, Category, Size, Status `
        -PreContent "<h2>Patch Compliance Report — $hostname — $reportDate</h2><p>Status: <strong>$complianceStatus</strong></p>" `
        -Title "Patch Report $hostname"
    $htmlBody | Out-File -FilePath $ReportPath -Encoding UTF8
    Write-Ok "Report written: $ReportPath"

    return $report
}

# ── Step 3: Approval workflow ────────────────────────────────
function Request-PatchApproval {
    param([array]$Patches, [PSCustomObject]$Report)

    if ($Force) {
        Write-Warn "Force flag set — skipping approval prompt (CI mode)."
        return $true
    }

    Write-Host ""
    Write-Warn "Change Control — Patch Approval Required"
    Write-Host "  In a production environment this would:"
    Write-Host "    1. Create a ServiceNow/Jira change request"
    Write-Host "    2. Notify the change advisory board (CAB)"
    Write-Host "    3. Require sign-off from system owner"
    Write-Host "    4. Schedule during approved maintenance window"
    Write-Host ""
    Write-Host "  Critical patches require immediate escalation to security team."
    Write-Host ""

    $criticalPatches = $Patches | Where-Object Severity -eq 'Critical'
    if ($criticalPatches.Count -gt 0) {
        Write-Err "  $($criticalPatches.Count) CRITICAL patch(es) require emergency change process!"
        $criticalPatches | ForEach-Object { Write-Host "    - $($_.KB): $($_.Title)" -ForegroundColor Red }
        Write-Host ""
    }

    $response = Read-Host "  Approve patch installation? (yes/no)"
    return $response -eq 'yes'
}

# ── Step 4: Apply patches (simulated) ───────────────────────
function Install-Patches {
    param([array]$Patches)

    Write-Info "Applying patches (simulated — no actual changes made)..."
    Write-Host ""

    $total   = $Patches.Count
    $current = 0

    foreach ($patch in $Patches) {
        $current++
        $pct = [int](($current / $total) * 100)
        $bar = '#' * [int]($pct / 5)
        $pad = ' ' * (20 - $bar.Length)

        Write-Host "  [$bar$pad] $pct% — Installing $($patch.KB)" -NoNewline
        Start-Sleep -Milliseconds 400  # Simulate installation time
        $patch.Status = 'Installed'
        Write-Host "`r  [$bar$pad] $pct% — Installed  $($patch.KB)  " -ForegroundColor Green
    }

    Write-Host ""
    Write-Ok "All $total patches installed (simulated)."
}

# ── Step 5: Reboot check ─────────────────────────────────────
function Test-RebootRequired {
    param([array]$Patches)

    $rebootKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    $rebootRequired = Test-Path $rebootKey

    # Also simulate reboot requirement for critical/important patches
    $requiresReboot = $rebootRequired -or ($Patches | Where-Object { $_.Severity -in 'Critical','Important' }).Count -gt 0

    if ($requiresReboot) {
        Write-Warn "REBOOT REQUIRED to complete patch installation."
        Write-Host "  Schedule reboot during next maintenance window."
        Write-Host "  In production, use: Restart-Computer -Force (with appropriate scheduling)"
    } else {
        Write-Ok "No reboot required."
    }

    return $requiresReboot
}

# ── Main ─────────────────────────────────────────────────────
function Main {
    Write-Host ""
    Write-Host "════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  NexusMidplane — Patch Management Workflow" -ForegroundColor Cyan
    Write-Host "  Mode: $Mode | Host: $env:COMPUTERNAME" -ForegroundColor Cyan
    Write-Host "════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""

    $patches = Invoke-PatchScan

    if ($Mode -in 'Report', 'Full') {
        $report = New-ComplianceReport -Patches $patches
    }

    if ($Mode -in 'Apply', 'Full') {
        $approved = Request-PatchApproval -Patches $patches -Report $report
        if ($approved) {
            Install-Patches -Patches $patches
            $rebootNeeded = Test-RebootRequired -Patches $patches
        } else {
            Write-Warn "Patch installation declined. Patches remain pending."
            exit 0
        }
    }

    Write-Host ""
    Write-Host "════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Ok   "Patch management workflow complete."
    Write-Host "  AWS equivalent: AWS Systems Manager Patch Manager" -ForegroundColor Gray
    Write-Host "  Enterprise:     SCCM / WSUS / Ansible patching    " -ForegroundColor Gray
    Write-Host "════════════════════════════════════════════════════" -ForegroundColor Cyan
}

Main
