#requires -Version 5.1
<#
.SYNOPSIS
    M365 MFA Administration Tool - view, set up and delete MFA methods on behalf of other users.

.DESCRIPTION
    WPF user interface for Windows PowerShell 5.1. Start by double-clicking Start.cmd or run:
    powershell.exe -ExecutionPolicy Bypass -File .\Start-M365MfaTool.ps1

    All visible texts come from Languages\<code>.json and are retrieved via T '<key>'.
    In the XAML files, the Uid attribute refers to an element's text key.
#>
[CmdletBinding()]
param(
    # Set by Start.cmd: hide the console window. Windows Terminal ignores -WindowStyle and opens a tab,
    # so the script hides the window itself. Not set when started from a terminal by hand, because that
    # would hide the whole terminal window including other tabs.
    [switch]$HideConsole,

    # Headless mode: create the tenant MFA report as an Excel file without the GUI, e.g.
    #   powershell.exe -ExecutionPolicy Bypass -File .\Start-M365MfaTool.ps1 -Report -OutFile C:\Reports\MFA.xlsx
    # The sign-in is still interactive. -Group: group name (beginning) or object ID instead of all users.
    [switch]$Report,
    [string]$OutFile,
    [string]$Group,
    [switch]$IncludeDisabled,
    [switch]$IncludeGuests,
    [string]$Language
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($PSVersionTable.PSEdition -ne 'Desktop') {
    throw "This WPF tool requires Windows PowerShell 5.1: powershell.exe -ExecutionPolicy Bypass -File `"$PSCommandPath`""
}

#region Initialization

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

$script:AppRoot = Split-Path -Parent $PSCommandPath
$script:AppVersion = '1.3.0'
$script:RepoUrl = 'https://github.com/dominguez-posh/M365-MFA-Manager'
# -Global so that all modules can use each other's functions (T, Invoke-M365GraphRequest, etc.).
Import-Module (Join-Path $script:AppRoot 'Modules\Localization.psm1') -Force -Global
Import-Module (Join-Path $script:AppRoot 'Modules\Graph.psm1') -Force -Global
Import-Module (Join-Path $script:AppRoot 'Modules\Provisioning.psm1') -Force

if ($HideConsole) {
    # GA_ROOTOWNER (3): with Windows Terminal, the console window is a hidden pseudo window owned by the terminal.
    $consoleWindow = [M365MfaTool.NativeWindow]::GetAncestor([M365MfaTool.NativeWindow]::GetConsoleWindow(), 3)
    if ($consoleWindow -ne [IntPtr]::Zero) { [void][M365MfaTool.NativeWindow]::ShowWindow($consoleWindow, 0) }   # SW_HIDE
}
# -Global: the tenant report also reads the sending date of the MFA guide
Import-Module (Join-Path $script:AppRoot 'Modules\MfaGuideMail.psm1') -Force -Global
Import-Module (Join-Path $script:AppRoot 'Modules\TenantReport.psm1') -Force

# User settings: language and sender mailbox of the MFA guide
$script:SettingsPath = Join-Path $env:APPDATA 'M365MfaTool\settings.json'

# Daily log files (Logs\yyyy-MM-dd.log); fallback if the tool folder is not writable
$script:LogFolder = Join-Path $script:AppRoot 'Logs'
# Path::Combine instead of Join-Path: does not fail at startup if the drive does not exist
$script:FallbackLogFolder = [System.IO.Path]::Combine([string]$env:LOCALAPPDATA, 'M365MfaTool', 'Logs')
$script:LogFileDisabled = $false

function Read-Settings {
    try {
        if (Test-Path -LiteralPath $script:SettingsPath) {
            return (Get-Content -LiteralPath $script:SettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json)
        }
    }
    catch { }
    [pscustomobject]@{ Language = 'en'; GuideSender = '' }
}

function ConvertTo-HrdnrKeyMap {
    # settings.json: HrdnrKeys = { "<tenant ID>": "hrdnr-fakemfa:1:..." }
    param($Value)
    $map = @{}
    if ($null -ne $Value) {
        foreach ($p in $Value.PSObject.Properties) { if ($p.Value) { $map[[string]$p.Name] = [string]$p.Value } }
    }
    $map
}

function Save-Settings {
    try {
        $folder = Split-Path -Parent $script:SettingsPath
        if (-not (Test-Path -LiteralPath $folder)) { New-Item -ItemType Directory -Path $folder -Force | Out-Null }
        [pscustomobject]@{ Language = Get-UiLanguage; GuideSender = $script:GuideSender; HrdnrKeys = [pscustomobject]$script:HrdnrKeys } |
            ConvertTo-Json | Set-Content -LiteralPath $script:SettingsPath -Encoding UTF8
    }
    catch { }
}

$settings = Read-Settings
$script:GuideSender = if ($settings.PSObject.Properties['GuideSender']) { [string]$settings.GuideSender } else { '' }
# Public hrdnr key per tenant (fake MFA with the secret stored encrypted for hrdnr)
$script:HrdnrKeyTenant = ""
$script:HrdnrKeys = ConvertTo-HrdnrKeyMap $(if ($settings.PSObject.Properties['HrdnrKeys']) { $settings.HrdnrKeys } else { $null })
Initialize-Localization -Path (Join-Path $script:AppRoot 'Languages') -Language $(if ($settings.PSObject.Properties['Language']) { $settings.Language } else { 'en' })

if ($Report) {
    # Headless: tenant MFA report as Excel without the GUI (e.g. a scheduled run). The GUI is never loaded.
    if ($Language) { Set-UiLanguage -Language $Language }
    $exitCode = 0
    try {
        if (-not $OutFile) { $OutFile = Join-Path (Get-Location).Path ('MFA-Status_{0:yyyy-MM-dd}.xlsx' -f (Get-Date)) }
        Write-Host (T 'Log.SigningIn')
        $context = Connect-M365Graph
        Write-Host (T 'Log.SignedIn' $context.Account) -ForegroundColor Green

        $groupId = $null
        $scopeText = T 'Report.Scope.All'
        if ($Group) {
            $groups = @(Find-M365Group -SearchTerm $Group)
            if ($groups.Count -ne 1) { throw (T 'Headless.GroupAmbiguous' $Group $groups.Count) }
            $groupId = $groups[0].Id
            $scopeText = T 'Report.Scope.GroupName' $groups[0].DisplayName
        }
        if (-not $IncludeDisabled) { $scopeText += ', ' + (T 'Report.EnabledOnly') }
        if ($IncludeGuests) { $scopeText += ', ' + (T 'Report.IncludeGuests') }
        Write-Host (T 'Log.ReportStarted' $scopeText)

        $rows = New-Object System.Collections.Generic.List[object]
        $result = Invoke-M365TenantMfaReport -GroupId $groupId -IncludeDisabled:$IncludeDisabled -IncludeGuests:$IncludeGuests -IncludeSignIn `
            -OnProgress { param($Message) Write-Host $Message } `
            -OnWarning { param($Message) Write-Warning $Message } `
            -OnInfo { param($Message) Write-Host $Message } `
            -OnRows { param($Rows, $Done, $Total) foreach ($row in $Rows) { $rows.Add($row) } }
        if (-not $rows.Count) { throw (T 'Report.Status.NoUsers') }

        $tenantName = Get-M365OrganizationName
        $tenant = if ($tenantName) { '{0} ({1})' -f $tenantName, $context.TenantId } else { $context.TenantId }
        Export-M365MfaReportXlsx -Path $OutFile -Rows $rows.ToArray() -Tenant $tenant -ScopeText $scopeText -FilterText ''
        $levels = @{}
        foreach ($level in 'Red', 'Yellow', 'Green') { $levels[$level] = @($rows | Where-Object Level -eq $level).Count }
        Write-Host (T 'Log.ReportFinished' $result.Total $levels.Red $levels.Yellow $levels.Green) -ForegroundColor Green
        Write-Host (T 'Headless.Saved' $OutFile)
    }
    catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        $exitCode = 1
    }
    finally {
        Disconnect-M365Graph
    }
    exit $exitCode
}

[xml]$xaml = Get-Content -LiteralPath (Join-Path $script:AppRoot 'UI\MainWindow.xaml') -Raw -Encoding UTF8
$window = [Windows.Markup.XamlReader]::Load([System.Xml.XmlNodeReader]::new($xaml))
$window.Title = "M365 MFA Administration $($script:AppVersion)"

$controlNames = @(
    # Header and connection
    'BtnTenantReport', 'TxtConnectionStatus', 'TxtTenant', 'BtnTools', 'BtnTotpImport', 'BtnTokenInventory', 'BtnBulkTap', 'BtnBreakGlass', 'CmbLanguage', 'BtnLogin', 'BtnLogout'
    # User search (results in popup)
    'TxtSearch', 'BtnSearch', 'PopUsers', 'TxtUserHits', 'DgUsers'
    # MFA methods
    'GrpMethods', 'TxtNoUser', 'DgMethods', 'TxtMethodDetails', 'BtnRefreshMethods', 'BtnDeleteMethod'
    # Selected user
    'TxtSelectedName', 'TxtSelectedUpn', 'TxtSelectedId', 'BtnCopyUpn', 'BtnCopyId'
    'TxtMethodCount', 'TxtPreferredMethod', 'TxtSystemPreferred'
    'BdgMfa', 'DotMfa', 'TxtMfaLevel', 'TxtMfaHints', 'BtnSendGuide', 'TxtGuideStatus', 'TxtRoleSummary', 'BtnShowRoles', 'LstRoles'
    # Configure method
    'CmbMethod', 'PnlSerial', 'LblSerial', 'TxtSerial', 'PnlSecret', 'PwdSecret', 'CmbTotpAlgorithm', 'CmbTotpTimeStep', 'TxtMethodHint', 'BtnExecute'
    'PnlHrdnrKey', 'TxtHrdnrKey', 'BtnLoadHrdnrKey', 'TxtHrdnrKeyStatus'
    # Result: Temporary Access Pass
    'PnlTap', 'TxtTapUser', 'TxtTapValue', 'TxtTapValidity', 'BtnCopyTap', 'BtnHideTap'
    # Result: programmable TOTP card
    'PnlTotp', 'TxtTotpUser', 'ImgTotpQr', 'TxtTotpSecret', 'TxtTotpInfo', 'BtnCopyTotpSecret', 'BtnSaveTotpQr', 'BtnHideTotp'
    # Log and status
    'TxtLog', 'ProgressBar'
)
foreach ($name in $controlNames) {
    $control = $window.FindName($name)
    # Items of the tools menu are not in the window's logical tree: look them up in the menu
    if ($null -eq $control) { $control = $window.FindName('BtnTools').ContextMenu.Items | Where-Object { $_ -is [System.Windows.Controls.MenuItem] -and $_.Name -eq $name } }
    Set-Variable -Name $name -Value $control -Scope Script
}

$script:Context = $null
$script:SelectedUser = $null
$script:SelectedMethod = $null
$script:SelectedAssessment = $null   # MFA traffic light of the selected user
$script:GuideInfo = $null            # When the MFA guide was last sent to the selected user
$script:TapResult = $null
$script:TotpSetup = $null
$script:ColumnKeys = @{}
$script:ReportData = $null   # Last tenant MFA report (kept while signed in)
$script:Rpt = $null          # Controls and state of the open report window

# Input fields and hints per method (key = method ID from the Tag in the dropdown)
$script:MethodUi = @{
    Fido2            = @{ Serial = 'Config.Serial.Fido2'; Secret = $false; HrdnrKey = $false; Hint = 'Config.Hint.Fido2' }
    FixedTotp        = @{ Serial = 'Config.Serial.Card';  Secret = $true;  HrdnrKey = $false; Hint = 'Config.Hint.FixedTotp' }
    ProgrammableTotp = @{ Serial = 'Config.Serial.Card';  Secret = $false; HrdnrKey = $false; Hint = 'Config.Hint.ProgrammableTotp' }
    Tap              = @{ Serial = $null;                 Secret = $false; HrdnrKey = $false; Hint = 'Config.Hint.Tap' }
    FakeMfa          = @{ Serial = $null;                 Secret = $false; HrdnrKey = $true;  Hint = 'Config.Hint.FakeMfa' }
}

#endregion

#region UI translation

function Get-LogicalDescendants {
    param($Element)
    $Element
    foreach ($child in [System.Windows.LogicalTreeHelper]::GetChildren($Element)) {
        if ($child -is [System.Windows.DependencyObject]) { Get-LogicalDescendants $child }
    }
}

function Update-ElementTexts {
    <#
    .SYNOPSIS
        Sets the texts of all elements with a Uid (Text/Content/Header/Title) and their tooltips (<Uid>.ToolTip).
    #>
    param([Parameter(Mandatory)]$Root)
    foreach ($element in Get-LogicalDescendants $Root) {
        if ($element -isnot [System.Windows.UIElement] -or [string]::IsNullOrEmpty($element.Uid)) { continue }
        $key = $element.Uid
        if (Test-UiText $key) {
            $text = T $key
            if ($element -is [System.Windows.Window]) { $element.Title = $text }
            elseif ($element -is [System.Windows.Controls.TextBlock]) { $element.Text = $text }
            elseif ($element -is [System.Windows.Controls.HeaderedContentControl]) { $element.Header = $text }
            elseif ($element -is [System.Windows.Controls.ContentControl]) { $element.Content = $text }
        }
        if (Test-UiText "$key.ToolTip") { $element.ToolTip = T "$key.ToolTip" }
    }
}

function Update-UiTexts {
    Update-ElementTexts -Root $window
    # The tools menu is not part of the logical tree
    foreach ($item in $script:BtnTools.ContextMenu.Items) {
        if ($item -isnot [System.Windows.Controls.MenuItem] -or -not $item.Uid) { continue }
        $item.Header = T $item.Uid
        if (Test-UiText "$($item.Uid).ToolTip") { $item.ToolTip = T "$($item.Uid).ToolTip" }
    }

    # Column headers: the XAML contains the text key, which is remembered on the first call.
    foreach ($grid in $script:DgUsers, $script:DgMethods) {
        foreach ($column in $grid.Columns) {
            if (-not $script:ColumnKeys.ContainsKey($column)) { $script:ColumnKeys[$column] = [string]$column.Header }
            $column.Header = T $script:ColumnKeys[$column]
        }
    }
    # Date format of the "Created" column per language
    $createdColumn = $script:DgMethods.Columns | Where-Object { $script:ColumnKeys[$_] -eq 'Methods.Col.Created' }
    $binding = New-Object System.Windows.Data.Binding 'Created'
    $binding.StringFormat = T 'Format.DateTime'
    $createdColumn.Binding = $binding
}

function Update-DynamicTexts {
    # Re-apply state-dependent texts in the new language.
    Set-ConnectionStatus $script:Context
    Update-MethodInputs
    Update-MethodsHeader
    Update-RolesToggle
    Update-GuideView
    if ($null -ne $script:TapResult) { Show-TapResult -Tap $script:TapResult }
    if ($null -ne $script:TotpSetup) { Show-TotpResult -Setup $script:TotpSetup }
    if (@($script:DgUsers.ItemsSource).Count -gt 1) { Set-UserHitsText @($script:DgUsers.ItemsSource).Count }
}

#endregion

#region UI helpers

function Write-LogFile {
    <#
    .SYNOPSIS
        Appends a line to the daily log file (Logs\yyyy-MM-dd.log) immediately.
    .DESCRIPTION
        Each line is written and flushed right away, so the log survives crashes. The file is opened
        with shared read/write access, so it can be viewed in an editor while the tool is running.
        If the tool folder is not writable, %LOCALAPPDATA%\M365MfaTool\Logs is used instead.
    #>
    param([Parameter(Mandatory)][string]$Line)
    if ($script:LogFileDisabled) { return }

    foreach ($attempt in 1, 2) {
        try {
            if (-not (Test-Path -LiteralPath $script:LogFolder)) { New-Item -ItemType Directory -Path $script:LogFolder -Force | Out-Null }
            $file = Join-Path $script:LogFolder ('{0:yyyy-MM-dd}.log' -f (Get-Date))
            $stream = [System.IO.File]::Open($file, 'Append', 'Write', 'ReadWrite')
            try {
                $writer = New-Object System.IO.StreamWriter ($stream, [System.Text.UTF8Encoding]::new($false))
                $writer.WriteLine($Line)
                $writer.Flush()
            }
            finally {
                $stream.Dispose()
            }
            return
        }
        catch {
            if ($attempt -eq 1 -and $script:LogFolder -ne $script:FallbackLogFolder) {
                $script:LogFolder = $script:FallbackLogFolder
                continue
            }
            # Logging to file is not possible at all: keep the GUI log working, report it once.
            $script:LogFileDisabled = $true
            $script:TxtLog.AppendText(('{0} [WARNING] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), (T 'Log.FileFailed' $_.Exception.Message)) + [Environment]::NewLine)
            return
        }
    }
}

function Write-UiLog {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error')][string]$Level = 'Info'
    )
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level.ToUpperInvariant(), $Message
    $script:TxtLog.AppendText($line + [Environment]::NewLine)
    $script:TxtLog.ScrollToEnd()
    Write-LogFile -Line $line
}

function Show-Message {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$Title,
        [ValidateSet('Information', 'Warning', 'Error')][string]$Icon = 'Information'
    )
    [System.Windows.MessageBox]::Show($Text, $Title, 'OK', $Icon) | Out-Null
}

function Confirm-Action {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$Title,
        [ValidateSet('Warning', 'Question')][string]$Icon = 'Warning',
        [switch]$DefaultYes
    )
    $default = if ($DefaultYes) { 'Yes' } else { 'No' }
    [System.Windows.MessageBox]::Show($Text, $Title, 'YesNo', $Icon, $default) -eq 'Yes'
}

function Install-MissingModules {
    <#
    .SYNOPSIS
        Asks once in the GUI and installs all missing modules without console prompts.
        Returns $false if the user declined.
    #>
    $missing = @(Get-MissingModules)
    if (-not $missing.Count) { return $true }

    $list = ($missing | ForEach-Object { '• ' + $_.Name + $(if ($_.RequiredVersion) { " $($_.RequiredVersion)" } else { '' }) }) -join "`n"
    if (-not (Confirm-Action -Text (T 'Modules.ConfirmInstall' $list) -Title (T 'Title.Prerequisites') -Icon Question -DefaultYes)) {
        Write-UiLog (T 'Modules.Declined') 'Warning'
        return $false
    }

    $script:TxtConnectionStatus.Text = T 'Header.Installing'
    $script:TxtConnectionStatus.Foreground = '#FCD34D'
    $index = 0
    foreach ($module in $missing) {
        $index++
        Write-UiLog (T 'Modules.InstallingProgress' $index $missing.Count $module.Name)
        Install-RequiredModule -Name $module.Name -RequiredVersion $module.RequiredVersion -SkipPublisherCheck:$module.SkipPublisherCheck `
            -Wait { param($Milliseconds) Wait-Ui $Milliseconds }
        Write-UiLog (T 'Modules.Installed' $module.Name) 'Success'
    }
    $true
}

function Write-UiError {
    param([Parameter(Mandatory)][string]$Message, [Parameter(Mandatory)][string]$Title)
    Write-UiLog $Message 'Error'
    Show-Message -Text $Message -Title $Title -Icon Error
}

function Copy-ToClipboard {
    param([string]$Text, [Parameter(Mandatory)][string]$LogMessage)
    if ([string]::IsNullOrEmpty($Text)) { return }
    [System.Windows.Clipboard]::SetText($Text)
    Write-UiLog $LogMessage
}

function Set-Busy {
    param([bool]$Busy)
    $connected = Test-M365GraphConnection
    $hasUser = $null -ne $script:SelectedUser
    $canDelete = ($null -ne $script:SelectedMethod) -and $script:SelectedMethod.CanDelete

    $script:ProgressBar.Visibility       = if ($Busy) { 'Visible' } else { 'Collapsed' }
    $script:BtnLogin.IsEnabled           = -not $Busy -and -not $connected
    $script:BtnLogout.IsEnabled          = -not $Busy -and $connected
    $script:BtnTools.IsEnabled           = -not $Busy -and $connected
    $script:BtnTenantReport.IsEnabled    = -not $Busy -and $connected
    $script:CmbLanguage.IsEnabled        = -not $Busy
    $script:BtnSearch.IsEnabled          = -not $Busy -and $connected
    $script:BtnExecute.IsEnabled         = -not $Busy -and $hasUser
    $script:BtnRefreshMethods.IsEnabled  = -not $Busy -and $connected -and $hasUser
    $script:BtnDeleteMethod.IsEnabled    = -not $Busy -and $connected -and $canDelete
    $script:BtnCopyUpn.IsEnabled         = $hasUser
    $script:BtnCopyId.IsEnabled          = $hasUser
    $script:BtnSendGuide.IsEnabled       = -not $Busy -and $connected -and $hasUser
    [System.Windows.Forms.Application]::DoEvents()
}

function Wait-Ui {
    # Waits without freezing the UI.
    param([int]$Milliseconds)
    $until = (Get-Date).AddMilliseconds($Milliseconds)
    while ((Get-Date) -lt $until) {
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 100
    }
}

function Update-UiNow {
    # Draws pending changes (texts, log) before a call that blocks the UI thread, e.g. the sign-in.
    # Processing the queue once is not enough inside a click handler: WPF only presents the new frame
    # after the render thread has confirmed the previous one. Therefore keep processing messages briefly.
    Wait-Ui 300
}

function ConvertTo-BitmapImage {
    param([Parameter(Mandatory)][byte[]]$Bytes)
    $stream = New-Object System.IO.MemoryStream (, $Bytes)
    try {
        $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
        $bitmap.BeginInit()
        $bitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bitmap.StreamSource = $stream
        $bitmap.EndInit()
        $bitmap.Freeze()
        return $bitmap
    }
    finally {
        $stream.Dispose()
    }
}

function Format-UiDate {
    param($Date)
    if ($null -eq $Date) { return '-' }
    $Date.ToString((T 'Format.DateTime'))
}

function Get-SelectedMethodId {
    if ($script:CmbMethod.SelectedItem) { [string]$script:CmbMethod.SelectedItem.Tag } else { $null }
}

function Update-MethodInputs {
    $methodId = Get-SelectedMethodId
    $ui = if ($methodId) { $script:MethodUi[$methodId] } else { $null }

    $script:PnlSerial.Visibility = if ($ui -and $ui.Serial) { 'Visible' } else { 'Collapsed' }
    $script:PnlSecret.Visibility = if ($ui -and $ui.Secret) { 'Visible' } else { 'Collapsed' }
    $script:TxtMethodHint.Text = if ($ui) { T $ui.Hint } else { '' }
    if ($ui -and $ui.Serial) { $script:LblSerial.Text = T $ui.Serial }
    $script:PnlHrdnrKey.Visibility = if ($ui -and $ui.HrdnrKey) { 'Visible' } else { 'Collapsed' }
    if ($ui -and $ui.HrdnrKey) { Update-HrdnrKeyInput }
}

function Get-TenantHrdnrKey {
    # Key stored in settings.json for the connected tenant
    $tenantId = if ($script:Context) { [string]$script:Context.TenantId } else { '' }
    if ($tenantId -and $script:HrdnrKeys.ContainsKey($tenantId)) { $script:HrdnrKeys[$tenantId] } else { '' }
}

function Save-TenantHrdnrKey {
    param([string]$Key)
    $tenantId = if ($script:Context) { [string]$script:Context.TenantId } else { '' }
    if (-not $tenantId -or (Get-TenantHrdnrKey) -eq $Key) { return }
    $script:HrdnrKeys[$tenantId] = $Key
    Save-Settings
}

function Update-HrdnrKeyInput {
    # Prefills the key remembered for this tenant and shows which key is used
    param([string]$Status)
    if ([string]::IsNullOrWhiteSpace($script:TxtHrdnrKey.Text)) { $script:TxtHrdnrKey.Text = Get-TenantHrdnrKey }
    if ($Status) { $script:TxtHrdnrKeyStatus.Text = $Status; return }
    $text = $script:TxtHrdnrKey.Text.Trim()
    $script:TxtHrdnrKeyStatus.Text = if (-not $text) { T 'Config.HrdnrKey.None' }
        else {
            try { T 'Config.HrdnrKey.Ready' (ConvertFrom-HrdnrFakeMfaKey -Key $text).KeyId }
            catch { $_.Exception.Message }
        }
}

function Set-UserHitsText {
    param([int]$Count)
    $script:TxtUserHits.Text = (T 'Search.Hits' $Count) + $(if ($Count -ge 50) { ' ' + (T 'Search.HitsLimit') } else { '' })
}

#endregion

#region Result cards (TAP / TOTP card)

function Show-TapResult {
    param([Parameter(Mandatory)]$Tap)
    $script:TapResult = $Tap
    $usage = if ($Tap.IsUsableOnce) { T 'Tap.UsableOnce' } else { T 'Tap.UsableMultiple' }
    $script:TxtTapUser.Text = T 'Common.ForUser' $Tap.UserPrincipalName
    $script:TxtTapValue.Text = $Tap.Pass
    $script:TxtTapValidity.Text = T 'Tap.Validity' (Format-UiDate $Tap.ValidFrom) (Format-UiDate $Tap.ValidUntil) $Tap.LifetimeInMinutes $usage
    $script:PnlTap.Visibility = 'Visible'
}

function Hide-TapResult {
    $script:TapResult = $null
    $script:TxtTapValue.Text = ''
    $script:TxtTapUser.Text = '-'
    $script:TxtTapValidity.Text = '-'
    $script:PnlTap.Visibility = 'Collapsed'
}

function Show-TotpResult {
    param([Parameter(Mandatory)]$Setup)
    $script:TotpSetup = $Setup
    $script:TxtTotpUser.Text = T 'Common.ForUser' $Setup.UserPrincipalName
    $script:TxtTotpSecret.Text = $Setup.Secret
    $script:TxtTotpInfo.Text = T 'Totp.Info' $Setup.SerialNumber
    $script:ImgTotpQr.Source = if ($Setup.QrCodePng) { ConvertTo-BitmapImage -Bytes $Setup.QrCodePng } else { $null }
    $script:BtnSaveTotpQr.IsEnabled = [bool]$Setup.QrCodePng
    $script:PnlTotp.Visibility = 'Visible'
}

function Hide-TotpResult {
    $script:TotpSetup = $null
    $script:TxtTotpSecret.Text = ''
    $script:TxtTotpUser.Text = '-'
    $script:TxtTotpInfo.Text = '-'
    $script:ImgTotpQr.Source = $null
    $script:PnlTotp.Visibility = 'Collapsed'
}

function Hide-Results {
    Hide-TapResult
    Hide-TotpResult
}

#endregion

#region User and MFA view

# MFA traffic light colors: background, border, dot, text
$script:MfaLevelColors = @{
    Red     = @('#FEE2E2', '#FCA5A5', '#DC2626', '#991B1B')
    Yellow  = @('#FEF3C7', '#FCD34D', '#D97706', '#92400E')
    Green   = @('#DCFCE7', '#86EFAC', '#16A34A', '#166534')
    Neutral = @('#F1F5F9', '#CBD5E1', '#94A3B8', '#242424')
}

function Set-MfaIndicator {
    param($Assessment)
    $level = if ($Assessment) { $Assessment.Level } else { 'Neutral' }
    $colors = $script:MfaLevelColors[$level]
    $script:BdgMfa.Background = $colors[0]
    $script:BdgMfa.BorderBrush = $colors[1]
    $script:DotMfa.Fill = $colors[2]
    $script:TxtMfaLevel.Foreground = $colors[3]
    $script:TxtMfaLevel.Text = if ($Assessment) { $Assessment.Title } else { '-' }

    $hints = @(if ($Assessment) { $Assessment.Hints })
    $script:TxtMfaHints.Text = ($hints | ForEach-Object { "• $_" }) -join [Environment]::NewLine
    $script:TxtMfaHints.Visibility = if ($hints.Count) { 'Visible' } else { 'Collapsed' }
}

function Update-GuideView {
    <#
    .SYNOPSIS
        Shows the button for the MFA guide (users without or with weak MFA) and when it was last sent.
    #>
    $level = if ($script:SelectedAssessment) { $script:SelectedAssessment.Level } else { $null }
    $script:BtnSendGuide.Visibility = if ($level -in 'Red', 'Yellow') { 'Visible' } else { 'Collapsed' }

    $info = $script:GuideInfo
    if ($null -eq $script:SelectedAssessment) {
        $script:TxtGuideStatus.Visibility = 'Collapsed'
        return
    }
    $script:TxtGuideStatus.Text = if ($null -eq $info) { T 'Guide.Status.NotSent' }
        elseif ($info.Count -gt 1) { T 'Guide.Status.SentMultiple' (Format-UiDate $info.SentAt) $info.SentBy $info.Count }
        else { T 'Guide.Status.Sent' (Format-UiDate $info.SentAt) $info.SentBy }
    # Only of interest if the user still needs MFA or the guide was already sent
    $script:TxtGuideStatus.ToolTip = if ($info -and @($info.History).Count) {
        (T 'Guide.History.Title') + [Environment]::NewLine + (@($info.History | Where-Object SentAt | ForEach-Object { '{0} – {1}' -f (Format-UiDate $_.SentAt), $_.SentBy }) -join [Environment]::NewLine)
    } else { $null }
    $script:TxtGuideStatus.Visibility = if ($level -in 'Red', 'Yellow' -or $null -ne $info) { 'Visible' } else { 'Collapsed' }
}

function Update-RolesToggle {
    $script:BtnShowRoles.Content = if ($script:LstRoles.Visibility -eq 'Visible') { T 'User.HideRoles' } else { T 'User.ShowRoles' }
}

function Set-AdminRoles {
    param([object[]]$Roles, [string]$Status)
    $Roles = @($Roles | Where-Object { $null -ne $_ })
    $script:LstRoles.ItemsSource = $Roles
    $script:LstRoles.Visibility = 'Collapsed'
    Update-RolesToggle
    $script:BtnShowRoles.IsEnabled = $Roles.Count -gt 0
    $script:BtnShowRoles.Visibility = if ($Roles.Count) { 'Visible' } else { 'Collapsed' }

    if ($Status) {
        $script:TxtRoleSummary.Text = $Status
        $script:TxtRoleSummary.Foreground = $script:MfaLevelColors.Neutral[3]
        $script:TxtRoleSummary.FontWeight = 'Normal'
    }
    elseif (-not $Roles.Count) {
        $script:TxtRoleSummary.Text = T 'User.NoRoles'
        $script:TxtRoleSummary.Foreground = $script:MfaLevelColors.Neutral[3]
        $script:TxtRoleSummary.FontWeight = 'Normal'
    }
    else {
        $names = @($Roles | Select-Object -ExpandProperty RoleName -Unique)
        $script:TxtRoleSummary.Text = if ($names -contains 'Global Administrator') { T 'User.RoleCountWithGa' $names.Count } else { T 'User.RoleCount' $names.Count }
        $script:TxtRoleSummary.Foreground = $script:MfaLevelColors.Yellow[3]
        $script:TxtRoleSummary.FontWeight = 'SemiBold'
    }
}

function Clear-MfaView {
    $script:SelectedMethod = $null
    $script:DgMethods.ItemsSource = $null
    $script:TxtMethodDetails.Text = ''
    $script:TxtMethodCount.Text = '-'
    $script:TxtPreferredMethod.Text = '-'
    $script:TxtSystemPreferred.Text = '-'
    Set-MfaIndicator $null
    Set-AdminRoles -Roles @() -Status '-'
    $script:SelectedAssessment = $null
    $script:GuideInfo = $null
    Update-GuideView
}

function Update-MethodsHeader {
    $user = $script:SelectedUser
    $script:GrpMethods.Header = if ($user) { T 'Methods.GroupForUser' $user.DisplayName $user.UserPrincipalName } else { T 'Methods.Group' }
}

function Clear-SelectedUser {
    Hide-Results
    $script:SelectedUser = $null
    $script:TxtSelectedName.Text = '-'
    $script:TxtSelectedUpn.Text = '-'
    $script:TxtSelectedId.Text = '-'
    Update-MethodsHeader
    $script:TxtNoUser.Visibility = 'Visible'
    Clear-MfaView
}

function Select-User {
    param([Parameter(Mandatory)]$User)
    Hide-Results
    $script:SelectedUser = $User
    $script:TxtSelectedName.Text = $User.DisplayName
    $script:TxtSelectedUpn.Text = $User.UserPrincipalName
    $script:TxtSelectedId.Text = $User.Id
    Update-MethodsHeader
    $script:TxtNoUser.Visibility = 'Collapsed'
    Write-UiLog (T 'Log.UserSelected' $User.UserPrincipalName)
    Update-MfaView
}

function Set-ConnectionStatus {
    param($Context)
    $script:Context = $Context
    # the hrdnr key belongs to one tenant: drop it from the input when the tenant changes
    $tenantId = if ($null -ne $Context) { [string]$Context.TenantId } else { "" }
    if ($script:HrdnrKeyTenant -ne $tenantId) {
        $script:HrdnrKeyTenant = $tenantId
        if ($script:TxtHrdnrKey) { $script:TxtHrdnrKey.Clear(); if ($script:PnlHrdnrKey.Visibility -eq "Visible") { Update-HrdnrKeyInput } }
    }
    if ($null -eq $Context) {
        $script:TxtConnectionStatus.Text = T 'Header.NotConnected'
        $script:TxtConnectionStatus.Foreground = '#FCA5A5'
        $script:TxtTenant.Text = T 'Header.Tenant' '-'
    }
    else {
        $script:TxtConnectionStatus.Text = T 'Header.ConnectedAs' $Context.Account
        $script:TxtConnectionStatus.Foreground = '#4ADE80'
        $script:TxtTenant.Text = T 'Header.Tenant' $Context.TenantId
    }
}

function Update-MfaView {
    <#
    .SYNOPSIS
        Reloads the MFA methods of the selected user.
    .DESCRIPTION
        Graph replicates changes with a delay. If IDs are passed, waits until deleted
        methods have disappeared and new methods are visible (max. approx. 16 seconds).
    #>
    param(
        [string[]]$RemovedMethodIds = @(),
        [string[]]$AddedMethodIds = @()
    )

    Clear-MfaView
    if ($null -eq $script:SelectedUser) { return }

    $user = $script:SelectedUser
    $RemovedMethodIds = @($RemovedMethodIds | Where-Object { $_ })
    $AddedMethodIds = @($AddedMethodIds | Where-Object { $_ })

    $isPending = {
        param($list)
        $ids = @($list | ForEach-Object { $_.Id })
        @($RemovedMethodIds | Where-Object { $ids -contains $_ }).Count -gt 0 -or
        @($AddedMethodIds | Where-Object { $ids -notcontains $_ }).Count -gt 0
    }

    try {
        Set-Busy $true
        Write-UiLog (T 'Log.LoadingMethods' $user.UserPrincipalName)
        $methods = @(Get-M365UserAuthMethods -UserId $user.Id | Sort-Object TypeName, Created)

        for ($attempt = 1; $attempt -le 8 -and (& $isPending $methods); $attempt++) {
            if ($attempt -eq 1) { Write-UiLog (T 'Log.WaitingReplication') }
            Wait-Ui 2000
            $methods = @(Get-M365UserAuthMethods -UserId $user.Id | Sort-Object TypeName, Created)
        }
        if (& $isPending $methods) {
            Write-UiLog (T 'Log.ReplicationPending') 'Warning'
            $methods = @($methods | Where-Object { $RemovedMethodIds -notcontains $_.Id })
        }

        $script:DgMethods.ItemsSource = $methods
        $script:TxtMethodCount.Text = "$($methods.Count)"
        Write-UiLog (T 'Log.MethodsFound' $methods.Count $user.UserPrincipalName) 'Success'

        $roles = @()
        try {
            $roles = @(Get-M365UserAdminRoles -UserId $user.Id)
            Set-AdminRoles -Roles $roles
        }
        catch {
            Set-AdminRoles -Roles @() -Status (T 'Common.NotAvailable')
            Write-UiLog (T 'Log.RolesFailed' $_.Exception.Message) 'Warning'
        }

        $assessment = Get-M365MfaAssessment -Methods $methods -HasAdminRoles ($roles.Count -gt 0)
        Set-MfaIndicator $assessment
        $script:SelectedAssessment = $assessment
        try {
            $script:GuideInfo = Get-M365MfaGuideInfo -UserId $user.Id
        }
        catch {
            $script:GuideInfo = $null
            Write-UiLog (T 'Guide.InfoFailed' $_.Exception.Message) 'Warning'
        }
        Update-GuideView
        Write-UiLog (T 'Log.MfaStatus' $assessment.Title) $(if ($assessment.Level -eq 'Green') { 'Success' } else { 'Warning' })

        try {
            $prefs = Get-M365UserSignInPreferences -UserId $user.Id
            $script:TxtPreferredMethod.Text = $prefs.PreferredMethod
            $script:TxtSystemPreferred.Text = $prefs.SystemPreferredActive
        }
        catch {
            $script:TxtPreferredMethod.Text = T 'Common.NotAvailable'
            $script:TxtSystemPreferred.Text = T 'Common.NotAvailable'
            Write-UiLog (T 'Log.PreferencesFailed' $_.Exception.Message) 'Warning'
        }
    }
    catch {
        Write-UiError -Message (T 'Log.MethodsFailed' $_.Exception.Message) -Title (T 'Title.LoadError')
    }
    finally {
        Set-Busy $false
    }
}

#endregion

#region Events: language, connection and search

$CmbLanguage.Add_SelectionChanged({
    $selected = $CmbLanguage.SelectedItem
    if ($null -eq $selected -or $selected.Code -eq (Get-UiLanguage)) { return }
    $code = $selected.Code
    Set-UiLanguage -Language $code
    Save-Settings
    Update-UiTexts
    Update-DynamicTexts
    # Method names and traffic light texts come from the modules, so reload them.
    if ($null -ne $script:SelectedUser) { Update-MfaView }
})

$BtnTools.Add_Click({
    # Open the menu below the button (a context menu would otherwise need a right-click)
    $menu = $BtnTools.ContextMenu
    $menu.PlacementTarget = $BtnTools
    $menu.Placement = [System.Windows.Controls.Primitives.PlacementMode]::Bottom
    $menu.IsOpen = $true
})

$BtnLogin.Add_Click({
    try {
        Set-Busy $true
        # Install missing modules first, visibly in the GUI (instead of console prompts in the background)
        if (-not (Install-MissingModules)) { return }
        $TxtConnectionStatus.Text = T 'Header.SigningIn'
        $TxtConnectionStatus.Foreground = '#FCD34D'
        Write-UiLog (T 'Log.SigningIn')
        Update-UiNow
        $context = Connect-M365Graph
        Set-ConnectionStatus $context
        Write-UiLog (T 'Log.SignedIn' $context.Account) 'Success'
        $TxtSearch.Focus() | Out-Null
    }
    catch {
        Set-ConnectionStatus $script:Context
        Write-UiError -Message $_.Exception.Message -Title (T 'Title.SignInError')
    }
    finally {
        Set-Busy $false
    }
})

$BtnLogout.Add_Click({
    try {
        Disconnect-M365Graph
        $script:ReportData = $null
        $PopUsers.IsOpen = $false
        $DgUsers.ItemsSource = $null
        Clear-SelectedUser
        Set-ConnectionStatus $null
        Write-UiLog (T 'Log.SignedOut') 'Success'
    }
    catch {
        Write-UiLog $_.Exception.Message 'Error'
    }
    finally {
        Set-Busy $false
    }
})

$BtnSearch.Add_Click({
    $term = $TxtSearch.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($term)) {
        Show-Message -Text (T 'Search.Empty') -Title (T 'Title.Search')
        return
    }
    try {
        Set-Busy $true
        Write-UiLog (T 'Log.Searching' $term)
        $users = @(Find-M365User -SearchTerm $term)
        Write-UiLog (T 'Log.UsersFound' $users.Count) 'Success'
    }
    catch {
        Write-UiError -Message $_.Exception.Message -Title (T 'Title.SearchError')
        return
    }
    finally {
        Set-Busy $false
    }

    # A single result is selected directly; multiple results are shown in the popup below the search box.
    switch ($users.Count) {
        0 { Show-Message -Text (T 'Search.NoResults' $term) -Title (T 'Title.Search') }
        1 { $PopUsers.IsOpen = $false; Select-User -User $users[0] }
        default {
            $DgUsers.ItemsSource = $users
            Set-UserHitsText $users.Count
            $PopUsers.IsOpen = $true
        }
    }
})

$TxtSearch.Add_KeyDown({
    param($src, $keyArgs)
    if ($keyArgs.Key -eq 'Enter' -and $BtnSearch.IsEnabled) {
        $BtnSearch.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))
    }
})

$DgUsers.Add_SelectionChanged({
    $user = $DgUsers.SelectedItem
    if ($null -eq $user) { return }

    $PopUsers.IsOpen = $false
    # Reset the popup selection so the same entry can be selected again later.
    $DgUsers.Dispatcher.BeginInvoke([action]{ $script:DgUsers.UnselectAll() }) | Out-Null

    if ($null -ne $script:SelectedUser -and $script:SelectedUser.Id -eq $user.Id) { return }
    Select-User -User $user
})

# Clicking into the search box reopens the last results.
$TxtSearch.Add_PreviewMouseLeftButtonUp({
    if (-not $PopUsers.IsOpen -and @($DgUsers.ItemsSource).Count -gt 1) { $PopUsers.IsOpen = $true }
})

# Close the popup ourselves: StaysOpen="False" is unreliable when the popup is opened
# from a button click. Clicks inside the popup itself do not reach the window.
$window.Add_PreviewMouseDown({
    if ($PopUsers.IsOpen -and -not $TxtSearch.IsMouseOver -and -not $BtnSearch.IsMouseOver) { $PopUsers.IsOpen = $false }
})
$window.Add_PreviewKeyDown({
    param($src, $keyArgs)
    if ($keyArgs.Key -eq 'Escape' -and $PopUsers.IsOpen) { $PopUsers.IsOpen = $false; $keyArgs.Handled = $true }
})
$PopUsers.Add_KeyDown({
    param($src, $keyArgs)
    if ($keyArgs.Key -eq 'Escape') { $PopUsers.IsOpen = $false; $keyArgs.Handled = $true }
})
$window.Add_Deactivated({ $PopUsers.IsOpen = $false })
$window.Add_LocationChanged({ $PopUsers.IsOpen = $false })
$window.Add_SizeChanged({ $PopUsers.IsOpen = $false })

$BtnCopyUpn.Add_Click({
    if ($null -eq $script:SelectedUser) { return }
    Copy-ToClipboard -Text $script:SelectedUser.UserPrincipalName -LogMessage (T 'Log.UpnCopied' $script:SelectedUser.UserPrincipalName)
})

$BtnShowRoles.Add_Click({
    $LstRoles.Visibility = if ($LstRoles.Visibility -ne 'Visible') { 'Visible' } else { 'Collapsed' }
    Update-RolesToggle
})

$BtnCopyId.Add_Click({
    if ($null -eq $script:SelectedUser) { return }
    Copy-ToClipboard -Text $script:SelectedUser.Id -LogMessage (T 'Log.IdCopied' $script:SelectedUser.Id)
})

#endregion

#region Events: view and delete MFA methods

$DgMethods.Add_SelectionChanged({
    $script:SelectedMethod = $DgMethods.SelectedItem
    $TxtMethodDetails.Text = if ($null -ne $script:SelectedMethod) { $script:SelectedMethod.PropertyText } else { '' }
    Set-Busy $false
})

$BtnRefreshMethods.Add_Click({ Update-MfaView })

$BtnDeleteMethod.Add_Click({
    $user = $script:SelectedUser
    $method = $script:SelectedMethod
    if ($null -eq $user -or $null -eq $method) { return }

    $question = T 'Delete.Confirm' $user.UserPrincipalName $method.TypeName $method.DisplayName (Format-UiDate $method.Created) $method.Id
    if (-not (Confirm-Action -Text $question -Title (T 'Title.ConfirmDelete'))) { return }

    $deleted = $false
    try {
        Set-Busy $true
        Write-UiLog (T 'Log.Deleting' $method.TypeName $method.DisplayName $method.Id $user.UserPrincipalName) 'Warning'
        Remove-M365UserAuthMethod -UserId $user.Id -Method $method -Confirm:$false
        $deleted = $true
        Write-UiLog (T 'Log.Deleted' $method.TypeName $method.DisplayName) 'Success'
    }
    catch {
        Write-UiError -Message (T 'Log.DeleteFailed' $_.Exception.Message) -Title (T 'Title.DeleteFailed')
    }
    finally {
        Set-Busy $false
    }

    if ($deleted) { Update-MfaView -RemovedMethodIds $method.Id } else { Update-MfaView }
})

#endregion

#region Events: configure method

$CmbMethod.Add_SelectionChanged({ Update-MethodInputs })

$TxtHrdnrKey.Add_LostFocus({ Update-HrdnrKeyInput })

$BtnLoadHrdnrKey.Add_Click({
    # Public key that hrdnr stored in the tenant (organization extension com.hrdnr.fakeMfaKey)
    if ($null -eq $script:Context) { return }
    $found = $null
    try {
        Set-Busy $true
        Set-ConnectionStatus (Request-M365GraphScopes -Scopes @('Organization.Read.All'))
        $found = Get-HrdnrFakeMfaKeyFromTenant
    }
    catch {
        Write-UiError -Message $_.Exception.Message -Title (T 'Title.HrdnrKey')
    }
    finally {
        Set-Busy $false
    }
    if ($found) {
        $TxtHrdnrKey.Text = $found.Key
        Save-TenantHrdnrKey -Key $found.Key
        Update-HrdnrKeyInput -Status (T 'Config.HrdnrKey.FromTenant' $found.KeyId)
        Write-UiLog (T 'Config.HrdnrKey.FromTenant' $found.KeyId) 'Success'
    }
    else {
        Update-HrdnrKeyInput -Status (T 'Config.HrdnrKey.NotFound')
    }
})

$BtnExecute.Add_Click({
    if ($null -eq $script:SelectedUser) { return }
    $methodId = Get-SelectedMethodId
    if (-not $methodId) {
        Show-Message -Text (T 'Config.SelectMethod') -Title (T 'Title.Method')
        return
    }

    $user = $script:SelectedUser
    $methodName = [string]$CmbMethod.SelectedItem.Content
    $ui = $script:MethodUi[$methodId]

    # Validate input before asking for confirmation
    $options = @{}
    if ($ui.Serial) {
        if ([string]::IsNullOrWhiteSpace($TxtSerial.Text)) {
            Show-Message -Text (T 'Prov.MissingInput' (T $ui.Serial)) -Title (T 'Title.MissingInput')
            $TxtSerial.Focus() | Out-Null
            return
        }
        $options.SerialNumber = $TxtSerial.Text.Trim()
    }
    if ($ui.Secret) {
        if ([string]::IsNullOrWhiteSpace($PwdSecret.Password)) {
            Show-Message -Text (T 'Prov.MissingInput' (T 'Config.Secret')) -Title (T 'Title.MissingInput')
            $PwdSecret.Focus() | Out-Null
            return
        }
        $options.Secret = $PwdSecret.Password
        # Algorithm and time step of the card (printed on the order or in the seed file)
        $options.HashFunction = [string]$CmbTotpAlgorithm.SelectedItem.Tag
        $options.TimeStep = [int]$CmbTotpTimeStep.SelectedItem.Tag
    }
    $hrdnrKey = $null
    if ($ui.HrdnrKey) {
        # Pasted or remembered key; otherwise the key hrdnr stored in the tenant (if readable without new consent)
        $keyText = $TxtHrdnrKey.Text.Trim()
        try {
            $hrdnrKey = if ($keyText) { ConvertFrom-HrdnrFakeMfaKey -Key $keyText } else { Get-HrdnrFakeMfaKeyFromTenant }
        }
        catch {
            Show-Message -Text $_.Exception.Message -Title (T 'Title.HrdnrKey')
            $TxtHrdnrKey.Focus() | Out-Null
            return
        }
        if ($hrdnrKey) {
            $options.HrdnrKey = $hrdnrKey.Key
            if (-not $keyText) { $TxtHrdnrKey.Text = $hrdnrKey.Key; Update-HrdnrKeyInput -Status (T 'Config.HrdnrKey.FromTenant' $hrdnrKey.KeyId) }
        }
    }

    $question = T 'Config.Confirm' $methodName $user.UserPrincipalName
    if ($options.ContainsKey('SerialNumber')) { $question += "`n" + (T 'Config.ConfirmSerial' $options.SerialNumber) }
    if ($options.ContainsKey('HashFunction')) { $question += "`n" + (T 'Config.ConfirmTotp' ([string]$CmbTotpAlgorithm.SelectedItem.Content) $options.TimeStep) }
    if ($hrdnrKey) { $question += "`n`n" + (T 'Config.ConfirmHrdnr' $hrdnrKey.KeyId) }
    if ($methodId -eq 'Tap') {
        $existingTap = @($DgMethods.ItemsSource | Where-Object { $null -ne $_ -and $_.Type -eq '#microsoft.graph.temporaryAccessPassAuthenticationMethod' })
        if ($existingTap.Count) { $question += "`n`n" + (T 'Config.ConfirmReplaceTap') }
    }
    if (-not (Confirm-Action -Text $question -Title (T 'Title.ConfirmConfig'))) { return }

    $result = $null
    try {
        Set-Busy $true
        Hide-Results
        Write-UiLog (T 'Log.Provisioning' $methodName $user.UserPrincipalName) 'Warning'
        if ($methodId -eq 'Fido2') { Write-UiLog (T 'Fido2.Prompt') }
        # the encrypted secret is stored in an open extension on the user
        if ($hrdnrKey) { Set-ConnectionStatus (Request-M365GraphScopes -Scopes @('User.ReadWrite.All')) }

        $result = Invoke-MfaProvisioning -Method $methodId -User $user -Options $options
        if ($hrdnrKey) { Save-TenantHrdnrKey -Key $hrdnrKey.Key }

        # The TAP and TOTP secret are intentionally not logged, only displayed.
        Write-UiLog $result.Message 'Success'
        if ($null -ne $result.TemporaryAccessPass) { Show-TapResult -Tap $result.TemporaryAccessPass }
        if ($null -ne $result.TotpSetup) { Show-TotpResult -Setup $result.TotpSetup }
        $TxtSerial.Clear()
        $PwdSecret.Clear()
    }
    catch {
        Write-UiError -Message $_.Exception.Message -Title (T 'Title.ProvisioningError')
    }
    finally {
        Set-Busy $false
    }

    if ($null -ne $result) {
        Update-MfaView -AddedMethodIds $result.AddedMethodIds -RemovedMethodIds $result.RemovedMethodIds
    }
    else {
        Update-MfaView
    }
})

#endregion

#region Events: result cards

$BtnCopyTap.Add_Click({
    Copy-ToClipboard -Text $TxtTapValue.Text -LogMessage (T 'Log.TapCopied')
})

$BtnHideTap.Add_Click({ Hide-TapResult })

$BtnCopyTotpSecret.Add_Click({
    Copy-ToClipboard -Text $TxtTotpSecret.Text -LogMessage (T 'Log.SecretCopied')
})

$BtnSaveTotpQr.Add_Click({
    $setup = $script:TotpSetup
    if ($null -eq $setup -or -not $setup.QrCodePng) { return }

    $fileName = 'totp-{0}-{1}.png' -f $setup.UserPrincipalName, $setup.SerialNumber
    foreach ($char in [System.IO.Path]::GetInvalidFileNameChars()) { $fileName = $fileName.Replace([string]$char, '_') }

    $dialog = New-Object Microsoft.Win32.SaveFileDialog
    $dialog.Title = T 'Totp.SaveQr'
    $dialog.Filter = (T 'Totp.PngFilter') + ' (*.png)|*.png'
    $dialog.FileName = $fileName
    if ($dialog.ShowDialog($window)) {
        [System.IO.File]::WriteAllBytes($dialog.FileName, [byte[]]$setup.QrCodePng)
        Write-UiLog (T 'Log.QrSaved' $dialog.FileName) 'Warning'
    }
})

$BtnHideTotp.Add_Click({ Hide-TotpResult })

#endregion

#region MFA guide by email

function Update-GuidePreview {
    # Builds the email in the selected language and shows it in the preview.
    $d = $script:GuideDialog
    $language = if ($d.CmbGuideLanguage.SelectedItem) { $d.CmbGuideLanguage.SelectedItem.Code } else { $d.Recipient.Language }
    try {
        $d.Mail = New-M365MfaGuideMail -Recipient $d.Recipient -Language $language
        $d.TxtGuideSubject.Text = $d.Mail.Subject
        # The preview shows the images as data: URIs (the email itself uses inline attachments).
        [IO.File]::WriteAllText($d.PreviewFile, (Get-M365MfaGuidePreviewHtml -Mail $d.Mail), [Text.UTF8Encoding]::new($true))
        $d.WebGuidePreview.Navigate([Uri]$d.PreviewFile)
    }
    catch {
        $d.Mail = $null
        Show-Message -Text (T 'Guide.PreviewFailed' $_.Exception.Message) -Title (T 'Guide.Title') -Icon Error
    }
}

function Show-MfaGuideDialog {
    <#
    .SYNOPSIS
        Shows the email preview. Returns sender and email after "Send", otherwise $null.
    #>
    param([Parameter(Mandatory)]$Recipient)

    [xml]$dialogXaml = Get-Content -LiteralPath (Join-Path $script:AppRoot 'UI\MfaGuideDialog.xaml') -Raw -Encoding UTF8
    $dialog = [Windows.Markup.XamlReader]::Load([System.Xml.XmlNodeReader]::new($dialogXaml))
    $dialog.Owner = $window
    Update-ElementTexts -Root $dialog

    $script:GuideDialog = @{
        Window      = $dialog
        Recipient   = $Recipient
        Mail        = $null
        PreviewFile = Join-Path ([IO.Path]::GetTempPath()) ('M365MfaTool-guide-{0}.html' -f [guid]::NewGuid())
    }
    foreach ($name in 'TxtGuideTo', 'TxtGuideFrom', 'CmbGuideLanguage', 'TxtGuideLanguageHint', 'TxtGuideSubject', 'WebGuidePreview', 'BtnGuideSend') {
        $script:GuideDialog[$name] = $dialog.FindName($name)
    }
    $d = $script:GuideDialog

    $d.TxtGuideTo.Text = '{0} <{1}>' -f $Recipient.DisplayName, $Recipient.Mail
    $d.TxtGuideFrom.Text = if ($script:GuideSender) { $script:GuideSender } else { $script:Context.Account }
    $languages = @(Get-UiLanguages)
    $d.CmbGuideLanguage.ItemsSource = $languages
    $d.CmbGuideLanguage.SelectedItem = $languages | Where-Object Code -eq $Recipient.Language | Select-Object -First 1
    $d.TxtGuideLanguageHint.Text = switch ($Recipient.LanguageSource) {
        'User'         { T 'Guide.LanguageSource.User' $Recipient.PreferredLanguage }
        'Organization' { T 'Guide.LanguageSource.Organization' }
        default        { T 'Guide.LanguageSource.Default' }
    }

    $d.CmbGuideLanguage.Add_SelectionChanged({ Update-GuidePreview })
    $d.BtnGuideSend.Add_Click({
        $state = $script:GuideDialog
        if ($state.TxtGuideFrom.Text.Trim() -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$') {
            Show-Message -Text (T 'Guide.InvalidSender') -Title (T 'Guide.Title')
            $state.TxtGuideFrom.Focus() | Out-Null
            return
        }
        if ($null -eq $state.Mail) { return }
        $state.Window.DialogResult = $true
    })
    $dialog.Add_ContentRendered({ Update-GuidePreview })

    try {
        if (-not $dialog.ShowDialog()) { return $null }
        [pscustomobject]@{ Sender = $d.TxtGuideFrom.Text.Trim(); Mail = $d.Mail }
    }
    finally {
        $d.WebGuidePreview.Dispose()
        Remove-Item -LiteralPath $d.PreviewFile -Force -ErrorAction SilentlyContinue
        $script:GuideDialog = $null
    }
}

$BtnSendGuide.Add_Click({
    $user = $script:SelectedUser
    if ($null -eq $user) { return }

    try {
        Set-Busy $true
        $recipient = Get-M365MfaGuideRecipient -UserId $user.Id
    }
    catch {
        Write-UiError -Message (T 'Guide.PreviewFailed' $_.Exception.Message) -Title (T 'Guide.Title')
        return
    }
    finally {
        Set-Busy $false
    }
    if (-not $recipient.Mail) {
        Show-Message -Text (T 'Guide.NoMail' $recipient.UserPrincipalName) -Title (T 'Guide.Title') -Icon Warning
        return
    }

    $result = Show-MfaGuideDialog -Recipient $recipient
    if ($null -eq $result) { return }
    $languageName = (Get-UiLanguages | Where-Object Code -eq $result.Mail.Language | Select-Object -First 1).Name
    $question = T 'Guide.Confirm' $recipient.DisplayName $recipient.Mail $result.Sender $languageName
    if (-not (Confirm-Action -Text $question -Title (T 'Guide.Title') -Icon Question -DefaultYes)) { return }

    $sent = $false
    try {
        Set-Busy $true
        Write-UiLog (T 'Log.GuideScopes')
        Update-UiNow
        $sharedMailbox = $result.Sender -ne $script:Context.Account
        Set-ConnectionStatus (Request-M365GraphScopes -Scopes (Get-M365MfaGuideScopes -SharedMailbox $sharedMailbox))
        Send-M365MfaGuideMail -Sender $result.Sender -Recipient $recipient -Mail $result.Mail
        $sent = $true
        Write-UiLog (T 'Guide.Sent' $recipient.Mail $languageName $result.Sender) 'Success'

        # Remember the sender mailbox for the next time
        $script:GuideSender = $result.Sender
        Save-Settings

        Set-M365MfaGuideInfo -UserId $recipient.Id -SentBy $script:Context.Account -Language $result.Mail.Language
        $script:GuideInfo = Get-M365MfaGuideInfo -UserId $recipient.Id
        Update-GuideView
    }
    catch {
        if ($sent) {
            Write-UiError -Message (T 'Guide.AttributeFailed' $_.Exception.Message) -Title (T 'Guide.Title')
        }
        else {
            Write-UiError -Message ((T 'Guide.SendFailed' $_.Exception.Message) + "`n`n" + (T 'Guide.SendFailedHint')) -Title (T 'Guide.Title')
        }
    }
    finally {
        Set-Busy $false
    }
})

#endregion

#region Break-glass account

$script:BreakGlassScopes = @(
    'User.ReadWrite.All'                    # Create and rename users
    'Domain.Read.All'                       # Read domains for selection
    'RoleManagement.ReadWrite.Directory'    # Assign Global Administrator
)

function Show-BreakGlassDialog {
    <#
    .SYNOPSIS
        Shows the break-glass dialog. Returns the input or $null if cancelled.
    #>
    param([Parameter(Mandatory)][string[]]$Domains)

    [xml]$dialogXaml = Get-Content -LiteralPath (Join-Path $script:AppRoot 'UI\BreakGlassDialog.xaml') -Raw -Encoding UTF8
    $dialog = [Windows.Markup.XamlReader]::Load([System.Xml.XmlNodeReader]::new($dialogXaml))
    $dialog.Owner = $window
    Update-ElementTexts -Root $dialog

    $cmbDomain   = $dialog.FindName('CmbBgDomain')
    $txtUpnHint  = $dialog.FindName('TxtBgUpnHint')
    $chkAdmin    = $dialog.FindName('ChkBgGlobalAdmin')
    $chkFido2    = $dialog.FindName('ChkBgFido2')
    $pnlSerial   = $dialog.FindName('PnlBgSerial')
    $txtSerial   = $dialog.FindName('TxtBgSerial')
    $btnCreate   = $dialog.FindName('BtnBgCreate')

    $cmbDomain.ItemsSource = $Domains
    $cmbDomain.SelectedIndex = 0

    $upnHintTemplate = T 'BreakGlass.UpnHint'
    $updateHint = {
        $domain = [string]$cmbDomain.SelectedItem
        $txtUpnHint.Text = if ($domain) { $upnHintTemplate -f $domain } else { '' }
    }.GetNewClosure()
    & $updateHint
    $cmbDomain.Add_SelectionChanged($updateHint)
    $chkFido2.Add_Click({ $pnlSerial.IsEnabled = [bool]$chkFido2.IsChecked }.GetNewClosure())

    $missingSerialText = T 'Prov.MissingInput' (T 'Config.Serial.Fido2')
    $missingTitle = T 'Title.MissingInput'
    $btnCreate.Add_Click({
        if ($chkFido2.IsChecked -and [string]::IsNullOrWhiteSpace($txtSerial.Text)) {
            [System.Windows.MessageBox]::Show($missingSerialText, $missingTitle, 'OK', 'Information') | Out-Null
            $txtSerial.Focus() | Out-Null
            return
        }
        $dialog.DialogResult = $true
    }.GetNewClosure())

    if (-not $dialog.ShowDialog()) { return $null }

    [pscustomobject]@{
        Domain            = [string]$cmbDomain.SelectedItem
        AssignGlobalAdmin = [bool]$chkAdmin.IsChecked
        Fido2SerialNumber = if ($chkFido2.IsChecked) { $txtSerial.Text.Trim() } else { $null }
    }
}

$BtnBreakGlass.Add_Click({
    try {
        Set-Busy $true
        Write-UiLog (T 'Log.BreakGlassScopes')
        Update-UiNow
        Set-ConnectionStatus (Request-M365GraphScopes -Scopes $script:BreakGlassScopes)
        $domains = @(Get-M365VerifiedDomains)
        if (-not $domains.Count) { throw (T 'BG.NoDomains') }
    }
    catch {
        Write-UiError -Message $_.Exception.Message -Title (T 'BreakGlass.Title')
        return
    }
    finally {
        Set-Busy $false
    }

    $options = Show-BreakGlassDialog -Domains $domains
    if ($null -eq $options) { return }

    $fidoText = if ($options.Fido2SerialNumber) { $options.Fido2SerialNumber } else { T 'BG.Fido2Later' }
    $question = T 'BG.Confirm' $options.Domain $(if ($options.AssignGlobalAdmin) { T 'Common.Yes' } else { T 'Common.No' }) $fidoText
    if (-not (Confirm-Action -Text $question -Title (T 'BreakGlass.Title'))) { return }

    $result = $null
    try {
        Set-Busy $true
        Hide-Results
        $result = New-M365BreakGlassAccount -Domain $options.Domain -AssignGlobalAdmin:$options.AssignGlobalAdmin `
            -Fido2SerialNumber $options.Fido2SerialNumber `
            -OnProgress { param($Message) Write-UiLog "Breakglass: $Message" } `
            -Wait { param($Milliseconds) Wait-Ui $Milliseconds }
    }
    catch {
        Write-UiError -Message (T 'BG.Failed' $_.Exception.Message) -Title (T 'BreakGlass.Title')
    }
    finally {
        Set-Busy $false
    }
    if ($null -eq $result) { return }

    foreach ($warning in $result.Warnings) { Write-UiLog "Breakglass: $warning" 'Warning' }
    $gaStatus = if ($result.GlobalAdminAssigned) { T 'BG.Status.Assigned' } elseif ($options.AssignGlobalAdmin) { T 'BG.Status.Failed' } else { T 'Common.No' }
    $summary = @(
        T 'BG.Summary.Created' $result.User.UserPrincipalName
        ''
        T 'BG.Summary.GlobalAdmin' $gaStatus
        T 'BG.Summary.Fido2' $(if ($result.Fido2Registered) { T 'BG.Status.Registered' } else { T 'BG.Status.NotRegistered' })
        T 'BG.Summary.FakeMfa' $(if ($result.FakeMfaActive) { T 'BG.Status.Active' } else { T 'BG.Status.Inactive' })
    )
    if ($result.Warnings.Count) { $summary += @('', (T 'BG.Summary.Notes')) + @($result.Warnings | ForEach-Object { "- $_" }) }
    $summary += @('', (T 'BG.Summary.Reminder'))

    Write-UiLog (T 'BG.Summary.Created' $result.User.UserPrincipalName) 'Success'
    Show-Message -Text ($summary -join "`n") -Title (T 'BreakGlass.Title') -Icon $(if ($result.Warnings.Count) { 'Warning' } else { 'Information' })

    Select-User -User $result.User
})

#endregion

#region Tenant MFA report

function New-ReportData {
    [pscustomobject]@{
        TenantId   = if ($script:Context) { $script:Context.TenantId } else { '' }
        TenantName = $null
        ScopeText  = ''
        Rows       = New-Object System.Collections.ObjectModel.ObservableCollection[object]
        Counts     = @{ Red = 0; Yellow = 0; Green = 0; Unknown = 0; AdminsRed = 0; Inactive = 0 }
        SignInAvailable = $false
    }
}

function Set-ReportStatus {
    param([string]$Message)
    $script:Rpt.TxtRptStatus.Text = $Message
    [System.Windows.Forms.Application]::DoEvents()
}

function Set-ReportBusy {
    param([bool]$Busy)
    $r = $script:Rpt
    $r.Running = $Busy
    foreach ($control in $r.CmbRptScope, $r.PnlRptGroup, $r.ChkRptEnabledOnly, $r.ChkRptGuests, $r.BtnRptStart) {
        $control.IsEnabled = -not $Busy
    }
    $r.BtnRptCancel.IsEnabled = $Busy
    $r.BtnRptExport.IsEnabled = -not $Busy -and $script:ReportData.Rows.Count -gt 0
    $r.PrgRpt.Visibility = if ($Busy) { 'Visible' } else { 'Hidden' }
    [System.Windows.Forms.Application]::DoEvents()
}

function Update-ReportCounts {
    $r = $script:Rpt
    $data = $script:ReportData
    $r.TxtRptCountAll.Text = "$($data.Rows.Count)"
    $r.TxtRptCountRed.Text = "$($data.Counts.Red)"
    $r.TxtRptCountYellow.Text = "$($data.Counts.Yellow)"
    $r.TxtRptCountGreen.Text = "$($data.Counts.Green)"
    $r.TxtRptCountAdminsRed.Text = "$($data.Counts.AdminsRed)"
    # '-' when the last sign-in is not available (license or permission missing)
    $r.TxtRptCountInactive.Text = if ($data.SignInAvailable) { "$($data.Counts.Inactive)" } else { '-' }
    $r.TxtRptVisible.Text = if ($data.Rows.Count) { T 'Report.Status.Visible' $r.View.Count $data.Rows.Count } else { '' }
    $r.TxtRptEmpty.Visibility = if ($data.Rows.Count) { 'Collapsed' } else { 'Visible' }
}

function Update-ReportFilter {
    $r = $script:Rpt
    $r.SearchText = $r.TxtRptSearch.Text.Trim()
    $r.AdminsOnly = [bool]$r.ChkRptAdminsOnly.IsChecked
    $r.InactiveOnly = [bool]$r.ChkRptInactiveOnly.IsChecked
    $r.View.Refresh()
    Update-ReportCounts
}

function Get-ReportFilterText {
    # Description of the active filters for the Excel summary
    $r = $script:Rpt
    $parts = @(
        if ($r.LevelFilter) { T "Report.Tile.$($r.LevelFilter)" }
        if ($r.AdminsOnly) { T 'Report.AdminsOnly' }
        if ($r.InactiveOnly) { T 'Report.InactiveOnly' (Get-M365ReportInactiveDays) }
        if ($r.SearchText) { T 'Report.Summary.SearchFor' $r.SearchText }
    )
    $parts -join '; '
}

function Add-ReportRows {
    param([object[]]$Rows, [int]$Done, [int]$Total)
    $data = $script:ReportData
    foreach ($row in $Rows) {
        # One search string per row keeps the search filter fast
        $searchText = @($row.DisplayName, $row.UserPrincipalName, $row.Mail, $row.AdminRoles, $row.Methods, $row.Reason,
            $row.LevelText, $row.Department, $row.JobTitle, $row.UserType, $row.Id) -join ' '
        $row | Add-Member -NotePropertyName SearchText -NotePropertyValue $searchText
        $data.Rows.Add($row)
        $data.Counts[$row.Level]++
        if ($row.IsAdmin -and $row.Level -eq 'Red') { $data.Counts.AdminsRed++ }
        if ($row.IsInactive) { $data.Counts.Inactive++ }
        if ($row.SignInKnown) { $data.SignInAvailable = $true }
    }
    $script:Rpt.PrgRpt.IsIndeterminate = $false
    $script:Rpt.PrgRpt.Value = if ($Total) { 100 * $Done / $Total } else { 100 }
    Update-ReportCounts
    Set-ReportStatus (T 'Report.Progress.Methods' $Done $Total)
}

function Get-ReportTenantLabel {
    # "Contoso (tenant ID)" or only the tenant ID if the name could not be read
    $data = $script:ReportData
    if ($data.TenantName) { '{0} ({1})' -f $data.TenantName, $data.TenantId } else { $data.TenantId }
}

function Connect-ReportView {
    # Own view per window and collection: sorted red -> yellow -> green, filtered by tile, admins, inactivity and search.
    $r = $script:Rpt
    $view = [System.Windows.Data.ListCollectionView]::new($script:ReportData.Rows)
    $view.Filter = [Predicate[object]]{
        param($row)
        $state = $script:Rpt
        if ($state.LevelFilter -and $row.Level -ne $state.LevelFilter) { return $false }
        if ($state.AdminsOnly -and -not $row.IsAdmin) { return $false }
        if ($state.InactiveOnly -and -not $row.IsInactive) { return $false }
        if ($state.SearchText -and $row.SearchText.IndexOf($state.SearchText, [StringComparison]::OrdinalIgnoreCase) -lt 0) { return $false }
        $true
    }
    $r.View = $view
    $r.DgRpt.ItemsSource = $view
    # Only after ItemsSource: a visible DataGrid clears the sort order when its ItemsSource changes.
    $view.SortDescriptions.Add((New-Object System.ComponentModel.SortDescription 'LevelOrder', 'Ascending'))
    $view.SortDescriptions.Add((New-Object System.ComponentModel.SortDescription 'DisplayName', 'Ascending'))
    Update-ReportCounts
}

function Request-ReportScopes {
    <#
    .SYNOPSIS
        Requests the additional report permissions. Returns $true if the last sign-in can be read.
    .DESCRIPTION
        AuditLog.Read.All (last sign-in) is optional: if the consent fails, it is requested again
        without it. Without GroupMember.Read.All only roles assigned via groups are missing,
        but a group scope requires it.
    #>
    param([bool]$GroupRequired)
    Update-UiNow
    try {
        Set-ConnectionStatus (Request-M365GraphScopes -Scopes (Get-M365ReportScopes))
    }
    catch {
        Write-UiLog $_.Exception.Message 'Warning'
        try {
            Set-ConnectionStatus (Request-M365GraphScopes -Scopes @(Get-M365ReportScopes | Where-Object { $_ -ne 'AuditLog.Read.All' }))
        }
        catch {
            if ($GroupRequired) { throw }
            Write-UiLog $_.Exception.Message 'Warning'
        }
    }
    $canReadSignIn = @($script:Context.Scopes) -contains 'AuditLog.Read.All'
    if (-not $canReadSignIn) { Write-UiLog (T 'Report.SignInNoPermission') 'Warning' }
    $canReadSignIn
}

function Start-TenantReport {
    $r = $script:Rpt
    $groupId = $null
    if ([string]$r.CmbRptScope.SelectedItem.Tag -eq 'Group') {
        $group = $r.CmbRptGroup.SelectedItem
        if ($null -eq $group) {
            Show-Message -Text (T 'Report.SelectGroup') -Title (T 'Report.Title')
            return
        }
        $groupId = $group.Id
        $scopeText = T 'Report.Scope.GroupName' $group.DisplayName
    }
    else {
        $scopeText = T 'Report.Scope.All'
    }
    $enabledOnly = [bool]$r.ChkRptEnabledOnly.IsChecked
    $includeGuests = [bool]$r.ChkRptGuests.IsChecked
    if ($enabledOnly) { $scopeText += ', ' + (T 'Report.EnabledOnly') }
    if ($includeGuests) { $scopeText += ', ' + (T 'Report.IncludeGuests') }

    # Start with an empty list; the new collection gets its own view.
    $script:ReportData = New-ReportData
    $script:ReportData.ScopeText = $scopeText
    Connect-ReportView
    $r.Cancel = $false
    $r.PrgRpt.IsIndeterminate = $true
    $started = Get-Date

    try {
        Set-ReportBusy $true
        $includeSignIn = Request-ReportScopes -GroupRequired ([bool]$groupId)
        $script:ReportData.TenantId = $script:Context.TenantId
        $script:ReportData.TenantName = Get-M365OrganizationName
        $r.TxtRptTenant.Text = T 'Header.Tenant' (Get-ReportTenantLabel)
        Write-UiLog (T 'Log.ReportStarted' $scopeText)

        $result = Invoke-M365TenantMfaReport -GroupId $groupId -IncludeDisabled:(-not $enabledOnly) -IncludeGuests:$includeGuests -IncludeSignIn:$includeSignIn `
            -OnProgress { param($Message) Set-ReportStatus $Message } `
            -OnWarning { param($Message) Write-UiLog $Message 'Warning' } `
            -OnInfo { param($Message) Write-UiLog $Message } `
            -OnRows { param($Rows, $Done, $Total) Add-ReportRows -Rows $Rows -Done $Done -Total $Total } `
            -ShouldCancel { $script:Rpt.Cancel } `
            -Wait { param($Milliseconds) Wait-Ui $Milliseconds }

        $counts = $script:ReportData.Counts
        $duration = (Get-Date) - $started
        if ($result.Cancelled) {
            Set-ReportStatus (T 'Report.Status.Cancelled' $result.Done $result.Total)
            Write-UiLog (T 'Report.Status.Cancelled' $result.Done $result.Total) 'Warning'
        }
        else {
            Set-ReportStatus (T 'Report.Status.Done' $result.Total ('{0:hh\:mm\:ss}' -f $duration))
            Write-UiLog (T 'Log.ReportFinished' $result.Total $counts.Red $counts.Yellow $counts.Green) 'Success'
        }
        if (-not $result.Total) { $r.TxtRptEmpty.Text = T 'Report.Status.NoUsers' }
    }
    catch {
        Set-ReportStatus ''
        Write-UiError -Message (T 'Report.Failed' $_.Exception.Message) -Title (T 'Report.Title')
    }
    finally {
        Set-ReportBusy $false
        if ($r.CloseRequested) { $r.Window.Close() }
    }
}

function Find-ReportGroup {
    $r = $script:Rpt
    $term = $r.TxtRptGroupSearch.Text.Trim()
    if (-not $term) {
        Show-Message -Text (T 'Report.GroupSearchEmpty') -Title (T 'Report.Title')
        return
    }
    try {
        Set-ReportBusy $true
        Set-ConnectionStatus (Request-M365GraphScopes -Scopes (Get-M365ReportScopes))
        $groups = @(Find-M365Group -SearchTerm $term)
    }
    catch {
        Write-UiError -Message $_.Exception.Message -Title (T 'Report.Title')
        return
    }
    finally {
        Set-ReportBusy $false
    }

    $r.CmbRptGroup.ItemsSource = $groups
    if (-not $groups.Count) {
        Show-Message -Text (T 'Report.NoGroups' $term) -Title (T 'Report.Title')
        return
    }
    $r.CmbRptGroup.SelectedIndex = 0
    if ($groups.Count -gt 1) { $r.CmbRptGroup.IsDropDownOpen = $true }
    Set-ReportStatus (T 'Report.GroupsFound' $groups.Count)
}

function Export-TenantReport {
    $r = $script:Rpt
    $rows = @($r.View | ForEach-Object { $_ })
    if (-not $rows.Count) {
        Show-Message -Text (T 'Report.NothingToExport') -Title (T 'Report.Title')
        return
    }

    $data = $script:ReportData
    $fileName = 'MFA-Status_{0}_{1:yyyy-MM-dd}.xlsx' -f $(if ($data.TenantName) { $data.TenantName } else { $data.TenantId }), (Get-Date)
    foreach ($char in [System.IO.Path]::GetInvalidFileNameChars()) { $fileName = $fileName.Replace([string]$char, '_') }

    $dialog = New-Object Microsoft.Win32.SaveFileDialog
    $dialog.Title = T 'Report.Export'
    $dialog.Filter = (T 'Report.ExcelFilter') + ' (*.xlsx)|*.xlsx'
    $dialog.FileName = $fileName
    if (-not $dialog.ShowDialog($r.Window)) { return }

    try {
        Set-ReportBusy $true
        Set-ReportStatus (T 'Report.Exporting' $rows.Count)
        Export-M365MfaReportXlsx -Path $dialog.FileName -Rows $rows -Tenant (Get-ReportTenantLabel) -ScopeText $data.ScopeText -FilterText (Get-ReportFilterText)
        Set-ReportStatus (T 'Report.Exported' $dialog.FileName)
        Write-UiLog (T 'Report.Exported' $dialog.FileName) 'Success'
    }
    catch {
        Set-ReportStatus ''
        Write-UiError -Message (T 'Report.ExportFailed' $_.Exception.Message) -Title (T 'Report.Title')
        return
    }
    finally {
        Set-ReportBusy $false
    }

    if (Confirm-Action -Text (T 'Report.OpenFile' $dialog.FileName) -Title (T 'Report.Title') -Icon Question -DefaultYes) {
        Start-Process -FilePath $dialog.FileName
    }
}

function Show-TenantReportWindow {
    <#
    .SYNOPSIS
        Shows the tenant MFA report. Returns the user double-clicked in the list, otherwise $null.
    #>
    [xml]$reportXaml = Get-Content -LiteralPath (Join-Path $script:AppRoot 'UI\TenantReportWindow.xaml') -Raw -Encoding UTF8
    $dialog = [Windows.Markup.XamlReader]::Load([System.Xml.XmlNodeReader]::new($reportXaml))
    $dialog.Owner = $window
    Update-ElementTexts -Root $dialog

    $script:Rpt = @{
        Window = $dialog; View = $null; Running = $false; Cancel = $false; CloseRequested = $false
        LevelFilter = $null; AdminsOnly = $false; InactiveOnly = $false; SearchText = ''; SelectedUser = $null
    }
    foreach ($name in @(
        'TxtRptTenant', 'CmbRptScope', 'PnlRptGroup', 'TxtRptGroupSearch', 'BtnRptFindGroup', 'CmbRptGroup'
        'ChkRptEnabledOnly', 'ChkRptGuests', 'BtnRptStart', 'BtnRptCancel'
        'RbRptAll', 'RbRptRed', 'RbRptYellow', 'RbRptGreen'
        'TxtRptCountAll', 'TxtRptCountRed', 'TxtRptCountYellow', 'TxtRptCountGreen', 'TxtRptCountAdminsRed', 'TxtRptCountInactive', 'TxtRptInactiveLabel'
        'TxtRptSearch', 'ChkRptAdminsOnly', 'ChkRptInactiveOnly', 'TxtRptVisible', 'BtnRptExport', 'DgRpt', 'TxtRptEmpty', 'PrgRpt', 'TxtRptStatus'
    )) {
        $script:Rpt[$name] = $dialog.FindName($name)
    }
    $r = $script:Rpt

    # Column headers contain the text key; the date column uses the date format of the language.
    foreach ($column in $r.DgRpt.Columns) { $column.Header = T ([string]$column.Header) }
    $dateColumn = $r.DgRpt.Columns | Where-Object { $_.SortMemberPath -eq 'PasswordLastSet' }
    $binding = New-Object System.Windows.Data.Binding 'PasswordLastSet'
    $binding.StringFormat = T 'Format.DateTime'
    $dateColumn.Binding = $binding
    # Texts with the inactivity threshold
    $inactiveDays = Get-M365ReportInactiveDays
    $r.TxtRptInactiveLabel.Text = T 'Report.Tile.Inactive' $inactiveDays
    $r.ChkRptInactiveOnly.Content = T 'Report.InactiveOnly' $inactiveDays

    # Keep the last report of this tenant, so it is still there when the window is reopened.
    $tenantId = if ($script:Context) { $script:Context.TenantId } else { '' }
    if ($null -eq $script:ReportData -or $script:ReportData.TenantId -ne $tenantId) { $script:ReportData = New-ReportData }
    $r.TxtRptTenant.Text = T 'Header.Tenant' (Get-ReportTenantLabel)
    Connect-ReportView
    Set-ReportBusy $false
    Set-ReportStatus $(if ($script:ReportData.Rows.Count) { T 'Report.Status.Previous' $script:ReportData.ScopeText } else { '' })

    $r.CmbRptScope.Add_SelectionChanged({
        $script:Rpt.PnlRptGroup.Visibility = if ([string]$script:Rpt.CmbRptScope.SelectedItem.Tag -eq 'Group') { 'Visible' } else { 'Collapsed' }
    })

    $r.BtnRptFindGroup.Add_Click({ Find-ReportGroup })
    $r.TxtRptGroupSearch.Add_KeyDown({
        param($src, $keyArgs)
        if ($keyArgs.Key -eq 'Enter') { $script:Rpt.BtnRptFindGroup.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent)) }
    })

    $r.BtnRptStart.Add_Click({ Start-TenantReport })
    $r.BtnRptCancel.Add_Click({
        $script:Rpt.Cancel = $true
        $script:Rpt.BtnRptCancel.IsEnabled = $false
        Set-ReportStatus (T 'Report.Status.Cancelling')
    })
    $r.BtnRptExport.Add_Click({ Export-TenantReport })

    # Tiles filter by traffic light level
    foreach ($tile in @(
        @{ Button = $r.RbRptAll; Level = $null }
        @{ Button = $r.RbRptRed; Level = 'Red' }
        @{ Button = $r.RbRptYellow; Level = 'Yellow' }
        @{ Button = $r.RbRptGreen; Level = 'Green' }
    )) {
        $tile.Button.Tag = $tile.Level
        $tile.Button.Add_Checked({
            param($src)
            $script:Rpt.LevelFilter = if ($src.Tag) { [string]$src.Tag } else { $null }
            Update-ReportFilter
        })
    }
    $r.ChkRptAdminsOnly.Add_Click({ Update-ReportFilter })
    $r.ChkRptInactiveOnly.Add_Click({ Update-ReportFilter })

    # Search: filter shortly after the last keystroke
    $r.SearchTimer = New-Object System.Windows.Threading.DispatcherTimer
    $r.SearchTimer.Interval = [TimeSpan]::FromMilliseconds(300)
    $r.SearchTimer.Add_Tick({
        $script:Rpt.SearchTimer.Stop()
        Update-ReportFilter
    })
    $r.TxtRptSearch.Add_TextChanged({
        $script:Rpt.SearchTimer.Stop()
        $script:Rpt.SearchTimer.Start()
    })

    # Double-click on a row: close the report and open the user in the main window
    $r.DgRpt.Add_MouseDoubleClick({
        param($src, $mouseArgs)
        $element = $mouseArgs.OriginalSource
        while ($null -ne $element -and $element -isnot [System.Windows.Controls.DataGridRow]) {
            $element = if ($element -is [System.Windows.Media.Visual]) { [System.Windows.Media.VisualTreeHelper]::GetParent($element) } else { $null }
        }
        if ($null -eq $element -or $script:Rpt.Running) { return }
        $row = $element.Item
        $script:Rpt.SelectedUser = [pscustomobject]@{
            Id                = $row.Id
            DisplayName       = $row.DisplayName
            UserPrincipalName = $row.UserPrincipalName
            Mail              = $row.Mail
            AccountEnabled    = $row.AccountEnabled
        }
        $script:Rpt.Window.Close()
    })

    # Closing during a running report: cancel first, the window closes after the current batch.
    $dialog.Add_Closing({
        param($src, $closingArgs)
        if ($script:Rpt.Running) {
            $script:Rpt.Cancel = $true
            $script:Rpt.CloseRequested = $true
            $closingArgs.Cancel = $true
            Set-ReportStatus (T 'Report.Status.Cancelling')
        }
    })

    $dialog.ShowDialog() | Out-Null
    $r.SearchTimer.Stop()
    $script:Rpt.SelectedUser
}

$BtnTenantReport.Add_Click({
    $user = Show-TenantReportWindow
    $script:Rpt = $null
    if ($null -ne $user) { Select-User -User $user }
})

#endregion

#region Bulk import of hardware OATH tokens

function Get-TiHashFunction {
    # Algorithm chosen in the import window, $null if none is selected yet
    $ti = $script:Ti
    if ($ti.RbTiSha256.IsChecked) { 'hmacsha256' } elseif ($ti.RbTiSha1.IsChecked) { 'hmacsha1' } else { $null }
}

function Set-TiBusy {
    param([bool]$Busy)
    $ti = $script:Ti
    $ti.Running = $Busy
    foreach ($control in $ti.BtnTiBrowse, $ti.BtnTiSample, $ti.RbTiSha1, $ti.RbTiSha256, $ti.CmbTiTimeStep, $ti.BtnTiTest, $ti.BtnTiClose,
                         $ti.CmbTiAssign, $ti.TxtTiGroupSearch, $ti.BtnTiFindGroup, $ti.CmbTiGroup, $ti.BtnTiUsersBrowse) {
        $control.IsEnabled = -not $Busy
    }
    $ready = @($ti.Results | Where-Object { $_.Status -in 'OK', 'Warning' }).Count
    $imported = @($ti.Results | Where-Object { $_.Status -eq 'Imported' -and $_.DeviceId }).Count
    $ti.BtnTiImport.IsEnabled = -not $Busy -and $ti.Tested -and $ready -gt 0
    $ti.BtnTiUndo.IsEnabled = -not $Busy -and $imported -gt 0
    $ti.BtnTiExport.IsEnabled = -not $Busy -and @($ti.Results).Count -gt 0
    $ti.BtnTiCancel.IsEnabled = $Busy
    $ti.PrgTi.Visibility = if ($Busy) { 'Visible' } else { 'Hidden' }
    [System.Windows.Forms.Application]::DoEvents()
}

function Set-TiStatus {
    param([string]$Message)
    $script:Ti.TxtTiStatus.Text = $Message
    [System.Windows.Forms.Application]::DoEvents()
}

function Reset-TiTest {
    # A changed file or algorithm invalidates the test import: the secrets are discarded.
    $ti = $script:Ti
    if (-not $ti.Tested) { return }
    $ti.Tested = $false
    foreach ($result in $ti.Results) { $result.Secret = $null }
    $ti.Results = @()
    $ti.DgTi.ItemsSource = $null
    Set-TiStatus (T 'Import.Status.TestAgain')
    Set-TiBusy $false
}

function Get-TiCounts {
    $results = @($script:Ti.Results)
    @{
        Total    = $results.Count
        OK       = @($results | Where-Object Status -eq 'OK').Count
        Warning  = @($results | Where-Object Status -eq 'Warning').Count
        Error    = @($results | Where-Object Status -eq 'Error').Count
        Imported = @($results | Where-Object Status -eq 'Imported').Count
        Failed   = @($results | Where-Object Status -eq 'Failed').Count
    }
}

function Save-TotpImportSample {
    $hashFunction = Get-TiHashFunction
    if (-not $hashFunction) { $hashFunction = 'hmacsha1' }
    $dialog = New-Object Microsoft.Win32.SaveFileDialog
    $dialog.Title = T 'Import.Sample'
    $dialog.Filter = (T 'Import.CsvFilter') + ' (*.csv)|*.csv'
    $dialog.FileName = 'TOTP-Import-Sample.csv'
    if (-not $dialog.ShowDialog($script:Ti.Window)) { return }

    $domain = if ($script:Context -and $script:Context.Account -match '@(.+)$') { $Matches[1] } else { 'contoso.com' }
    try {
        # UTF-8 with BOM, so that Excel shows umlauts in UPNs correctly
        $lines = @(Get-TotpImportSample -HashFunction $hashFunction -Domain $domain)
        [System.IO.File]::WriteAllLines($dialog.FileName, [string[]]$lines, [System.Text.UTF8Encoding]::new($true))
        Set-TiStatus (T 'Import.SampleSaved' $dialog.FileName)
    }
    catch {
        Write-UiError -Message $_.Exception.Message -Title (T 'Import.Title')
    }
}

function Select-TotpImportFile {
    $dialog = New-Object Microsoft.Win32.OpenFileDialog
    $dialog.Title = T 'Import.Browse'
    $dialog.Filter = (T 'Import.CsvFilter') + ' (*.csv;*.txt)|*.csv;*.txt'
    if (-not $dialog.ShowDialog($script:Ti.Window)) { return }
    Reset-TiTest
    $script:Ti.TxtTiFile.Text = $dialog.FileName
    Set-TiStatus ''
}

function Find-TiGroup {
    $ti = $script:Ti
    $term = $ti.TxtTiGroupSearch.Text.Trim()
    if (-not $term) {
        Show-Message -Text (T 'Report.GroupSearchEmpty') -Title (T 'Import.Title')
        return
    }
    try {
        Set-TiBusy $true
        $groups = @(Find-M365Group -SearchTerm $term)
    }
    catch {
        Write-UiError -Message $_.Exception.Message -Title (T 'Import.Title')
        return
    }
    finally {
        Set-TiBusy $false
    }
    Reset-TiTest
    $ti.CmbTiGroup.ItemsSource = $groups
    if (-not $groups.Count) {
        Show-Message -Text (T 'Report.NoGroups' $term) -Title (T 'Import.Title')
        return
    }
    $ti.CmbTiGroup.SelectedIndex = 0
    if ($groups.Count -gt 1) { $ti.CmbTiGroup.IsDropDownOpen = $true }
    Set-TiStatus (T 'Report.GroupsFound' $groups.Count)
}

function Get-TiAssignUsers {
    # Users that get the tokens without UPN: members of the chosen group or the users of a CSV list; @() = inventory only
    $ti = $script:Ti
    switch ([string]$ti.CmbTiAssign.SelectedItem.Tag) {
        'Group' {
            $group = $ti.CmbTiGroup.SelectedItem
            if ($null -eq $group) { throw (T 'Report.SelectGroup') }
            @(Get-M365ReportUsers -GroupId $group.Id | Sort-Object UserPrincipalName)
        }
        'Users' {
            if (-not $ti.TxtTiUsersFile.Text) { throw (T 'Import.NoFile') }
            $rows = @(Read-UpnListFile -Path $ti.TxtTiUsersFile.Text)
            $map = Resolve-M365UsersByUpn -Upns @($rows | ForEach-Object { $_.Upn }) -Wait { param($Milliseconds) Wait-Ui $Milliseconds }
            @($rows | ForEach-Object { $map[$_.Upn] } | Where-Object { $null -ne $_ })
        }
        default { @() }
    }
}

function Start-TotpImportTest {
    $ti = $script:Ti
    $path = $ti.TxtTiFile.Text
    $hashFunction = Get-TiHashFunction
    if (-not $path) {
        Show-Message -Text (T 'Import.NoFile') -Title (T 'Import.Title')
        return
    }
    if (-not $hashFunction) {
        Show-Message -Text (T 'Import.NoAlgorithm') -Title (T 'Import.Title')
        return
    }

    Reset-TiTest
    $ti.Cancel = $false
    try {
        Set-TiBusy $true
        $ti.PrgTi.IsIndeterminate = $true
        Set-TiStatus (T 'Import.Status.Reading')
        $rows = @(Read-TotpImportFile -Path $path)
        Set-ConnectionStatus (Request-M365GraphScopes -Scopes @('Policy.ReadWrite.AuthenticationMethod', 'UserAuthenticationMethod.ReadWrite.All', 'User.Read.All'))
        $assignTo = @(Get-TiAssignUsers)
        $ti.Results = @(Test-TotpImport -Rows $rows -HashFunction $hashFunction -AssignTo $assignTo -OnProgress {
            param($Done, $Total)
            if ($Done % 10 -eq 0 -or $Done -eq $Total) { Set-TiStatus (T 'Import.Status.Testing' $Done $Total) }
        } -ShouldCancel { $script:Ti.Cancel } -Wait { param($Milliseconds) Wait-Ui $Milliseconds })
        $ti.DgTi.ItemsSource = $ti.Results
        if ($ti.Cancel) {
            # An incomplete test is not a basis for the import
            Set-TiStatus (T 'Import.TestCancelled')
            return
        }
        $ti.Tested = $true
        $counts = Get-TiCounts
        $summary = T 'Import.TestDone' $counts.Total $counts.OK $counts.Warning $counts.Error
        if ($assignTo.Count) {
            # How many tokens were handed out automatically, how many users are left without one
            $autoCount = @($ti.Results | Where-Object AutoAssigned).Count
            $targets = @($assignTo | Where-Object { $_.AccountEnabled } | Sort-Object Id -Unique).Count
            $inventoryOnly = @($ti.Results | Where-Object { -not $_.Upn }).Count
            $summary += ' ' + (T 'Import.AutoAssignSummary' $autoCount ([Math]::Max(0, $targets - $autoCount)) $inventoryOnly)
        }
        Set-TiStatus $summary
        Write-UiLog ('{0}: {1} ({2})' -f (T 'Import.Title'), $summary, [System.IO.Path]::GetFileName($path))
    }
    catch {
        Set-TiStatus ''
        Write-UiError -Message (T 'Import.Failed' $_.Exception.Message) -Title (T 'Import.Title')
    }
    finally {
        $ti.PrgTi.IsIndeterminate = $false
        Set-TiBusy $false
        if ($ti.CloseRequested) { $ti.Window.Close() }
    }
}

function Start-TotpImport {
    $ti = $script:Ti
    $hashFunction = Get-TiHashFunction
    $timeStep = [int]$ti.CmbTiTimeStep.SelectedItem.Tag
    $counts = Get-TiCounts
    $ready = $counts.OK + $counts.Warning
    $algorithm = if ($hashFunction -eq 'hmacsha256') { 'SHA-256' } else { 'SHA-1' }
    $question = T 'Import.Confirm' $ready $algorithm $timeStep (Get-TiTenantLabel)
    if ($counts.Error) { $question += "`n`n" + (T 'Import.ConfirmSkipErrors' $counts.Error) }
    if (-not (Confirm-Action -Text $question -Title (T 'Import.Title'))) { return }

    $ti.Cancel = $false
    $ti.Tested = $false   # the secrets are used up: a new import needs a new test
    try {
        Set-TiBusy $true
        $ti.PrgTi.Value = 0
        Write-UiLog (T 'Import.Log.Started' $ready $algorithm $timeStep) 'Warning'
        Invoke-TotpImport -Results $ti.Results -HashFunction $hashFunction -TimeIntervalInSeconds $timeStep `
            -OnProgress {
                param($Result, $Done, $Total)
                # Secrets are never logged, only UPN and serial number.
                if ($Result.Status -eq 'Imported') { Write-UiLog (T 'Import.Log.Imported' $Result.SerialNumber $Result.Upn) 'Success' }
                else { Write-UiLog (T 'Import.Log.Failed' $Result.SerialNumber $Result.Upn $Result.Message) 'Error' }
                $script:Ti.PrgTi.Value = if ($Total) { 100 * $Done / $Total } else { 100 }
                $script:Ti.DgTi.Items.Refresh()
                Set-TiStatus (T 'Import.Status.Importing' $Done $Total)
            } `
            -ShouldCancel { $script:Ti.Cancel } `
            -Wait { param($Milliseconds) Wait-Ui $Milliseconds }
    }
    catch {
        Write-UiError -Message (T 'Import.Failed' $_.Exception.Message) -Title (T 'Import.Title')
    }
    finally {
        # Not imported (cancelled or error before the start): discard the secrets as well
        foreach ($result in $ti.Results) { $result.Secret = $null }
        $ti.DgTi.Items.Refresh()
        Set-TiBusy $false
    }

    $counts = Get-TiCounts
    $summary = T 'Import.Done' $counts.Imported $counts.Failed ($ready - $counts.Imported - $counts.Failed)
    Set-TiStatus $summary
    Write-UiLog $summary $(if ($counts.Failed) { 'Warning' } else { 'Success' })
    if ($ti.CloseRequested) { $ti.Window.Close() }
}

function Get-TiTenantLabel {
    if ($script:Context) { $script:Context.TenantId } else { '-' }
}

function Get-TiSettingsText {
    # "SHA-256, 60 s" for the confirmation and the export
    $hashFunction = Get-TiHashFunction
    $algorithm = if ($hashFunction -eq 'hmacsha256') { 'SHA-256' } else { 'SHA-1' }
    '{0}, {1} s' -f $algorithm, [int]$script:Ti.CmbTiTimeStep.SelectedItem.Tag
}

function Undo-LastTotpImport {
    $ti = $script:Ti
    $count = @($ti.Results | Where-Object { $_.Status -eq 'Imported' -and $_.DeviceId }).Count
    if (-not $count) { return }
    if (-not (Confirm-Action -Text (T 'Import.UndoConfirm' $count) -Title (T 'Import.Title'))) { return }

    $ti.Cancel = $false
    try {
        Set-TiBusy $true
        $ti.PrgTi.Value = 0
        Write-UiLog (T 'Import.Log.UndoStarted' $count) 'Warning'
        Undo-TotpImport -Results $ti.Results -OnProgress {
            param($Result, $Done, $Total)
            if ($Result.Status -eq 'Reverted') { Write-UiLog (T 'Import.Log.Reverted' $Result.SerialNumber $Result.Upn) 'Success' }
            else { Write-UiLog (T 'Import.Log.UndoFailed' $Result.SerialNumber $Result.Upn $Result.Message) 'Error' }
            $script:Ti.PrgTi.Value = if ($Total) { 100 * $Done / $Total } else { 100 }
            $script:Ti.DgTi.Items.Refresh()
            Set-TiStatus (T 'Import.Status.Undoing' $Done $Total)
        } -ShouldCancel { $script:Ti.Cancel }
    }
    catch {
        Write-UiError -Message (T 'Import.Failed' $_.Exception.Message) -Title (T 'Import.Title')
    }
    finally {
        $ti.DgTi.Items.Refresh()
        Set-TiBusy $false
    }

    $reverted = @($ti.Results | Where-Object Status -eq 'Reverted').Count
    $failed = @($ti.Results | Where-Object Status -eq 'UndoFailed').Count
    $summary = T 'Import.UndoDone' $reverted $failed
    Set-TiStatus $summary
    Write-UiLog $summary $(if ($failed) { 'Warning' } else { 'Success' })
    if ($ti.CloseRequested) { $ti.Window.Close() }
}

function Export-TotpImportResults {
    $ti = $script:Ti
    $rows = @($ti.Results)
    if (-not $rows.Count) {
        Show-Message -Text (T 'Report.NothingToExport') -Title (T 'Import.Title')
        return
    }
    $dialog = New-Object Microsoft.Win32.SaveFileDialog
    $dialog.Title = T 'Report.Export'
    $dialog.Filter = (T 'Report.ExcelFilter') + ' (*.xlsx)|*.xlsx'
    $dialog.FileName = 'TOTP-Import_{0:yyyy-MM-dd_HHmm}.xlsx' -f (Get-Date)
    if (-not $dialog.ShowDialog($ti.Window)) { return }

    try {
        Export-TotpImportXlsx -Path $dialog.FileName -Rows $rows -Tenant (Get-TiTenantLabel) `
            -FileName ([System.IO.Path]::GetFileName($ti.TxtTiFile.Text)) -Settings (Get-TiSettingsText)
        Write-UiLog (T 'Import.Exported' $dialog.FileName)
    }
    catch {
        Write-UiError -Message (T 'Report.ExportFailed' $_.Exception.Message) -Title (T 'Import.Title')
        return
    }
    if (Confirm-Action -Text (T 'Report.OpenFile' $dialog.FileName) -Title (T 'Import.Title') -Icon Question -DefaultYes) {
        Start-Process -FilePath $dialog.FileName
    }
}

function Show-TotpImportWindow {
    [xml]$importXaml = Get-Content -LiteralPath (Join-Path $script:AppRoot 'UI\TotpImportWindow.xaml') -Raw -Encoding UTF8
    $dialog = [Windows.Markup.XamlReader]::Load([System.Xml.XmlNodeReader]::new($importXaml))
    $dialog.Owner = $window
    Update-ElementTexts -Root $dialog

    $script:Ti = @{ Window = $dialog; Results = @(); Tested = $false; Running = $false; Cancel = $false; CloseRequested = $false }
    foreach ($name in @(
        'TxtTiTenant', 'TxtTiFile', 'BtnTiBrowse', 'BtnTiSample', 'RbTiSha1', 'RbTiSha256', 'CmbTiTimeStep'
        'CmbTiAssign', 'PnlTiGroup', 'TxtTiGroupSearch', 'BtnTiFindGroup', 'CmbTiGroup', 'PnlTiUsers', 'TxtTiUsersFile', 'BtnTiUsersBrowse'
        'DgTi', 'TxtTiStatus', 'PrgTi', 'BtnTiTest', 'BtnTiImport', 'BtnTiUndo', 'BtnTiExport', 'BtnTiCancel', 'BtnTiClose'
    )) {
        $script:Ti[$name] = $dialog.FindName($name)
    }
    $ti = $script:Ti
    foreach ($column in $ti.DgTi.Columns) { $column.Header = T ([string]$column.Header) }
    $ti.TxtTiTenant.Text = T 'Header.Tenant' (Get-TiTenantLabel)
    Set-TiBusy $false

    $ti.BtnTiBrowse.Add_Click({ Select-TotpImportFile })
    $ti.BtnTiSample.Add_Click({ Save-TotpImportSample })
    $ti.BtnTiTest.Add_Click({ Start-TotpImportTest })
    $ti.BtnTiImport.Add_Click({ Start-TotpImport })
    $ti.BtnTiUndo.Add_Click({ Undo-LastTotpImport })
    $ti.BtnTiExport.Add_Click({ Export-TotpImportResults })
    $ti.BtnTiClose.Add_Click({ $script:Ti.Window.Close() })
    $ti.BtnTiCancel.Add_Click({
        $script:Ti.Cancel = $true
        $script:Ti.BtnTiCancel.IsEnabled = $false
        Set-TiStatus (T 'Import.Status.Cancelling')
    })
    # The algorithm and time step must match the tokens: changing them requires a new test.
    foreach ($control in $ti.RbTiSha1, $ti.RbTiSha256) { $control.Add_Checked({ Reset-TiTest }) }
    $ti.CmbTiTimeStep.Add_SelectionChanged({ Reset-TiTest })

    # Assignment of tokens without UPN: group or user list, also invalidates the test
    $ti.CmbTiAssign.Add_SelectionChanged({
        $mode = [string]$script:Ti.CmbTiAssign.SelectedItem.Tag
        $script:Ti.PnlTiGroup.Visibility = if ($mode -eq 'Group') { 'Visible' } else { 'Collapsed' }
        $script:Ti.PnlTiUsers.Visibility = if ($mode -eq 'Users') { 'Visible' } else { 'Collapsed' }
        Reset-TiTest
    })
    $ti.BtnTiFindGroup.Add_Click({ Find-TiGroup })
    $ti.TxtTiGroupSearch.Add_KeyDown({
        param($src, $keyArgs)
        if ($keyArgs.Key -eq 'Enter') { Find-TiGroup }
    })
    $ti.CmbTiGroup.Add_SelectionChanged({ Reset-TiTest })
    $ti.BtnTiUsersBrowse.Add_Click({
        $open = New-Object Microsoft.Win32.OpenFileDialog
        $open.Title = T 'Import.Browse'
        $open.Filter = (T 'Import.CsvFilter') + ' (*.csv;*.txt)|*.csv;*.txt'
        if (-not $open.ShowDialog($script:Ti.Window)) { return }
        Reset-TiTest
        $script:Ti.TxtTiUsersFile.Text = $open.FileName
    })

    # Closing during a running import: cancel first, the window closes after the current token.
    $dialog.Add_Closing({
        param($src, $closingArgs)
        if ($script:Ti.Running) {
            $script:Ti.Cancel = $true
            $script:Ti.CloseRequested = $true
            $closingArgs.Cancel = $true
            Set-TiStatus (T 'Import.Status.Cancelling')
        }
    })

    $dialog.ShowDialog() | Out-Null
    foreach ($result in $script:Ti.Results) { $result.Secret = $null }
}

$BtnTotpImport.Add_Click({
    Show-TotpImportWindow
    $script:Ti = $null
    # Imported tokens of the selected user should show up right away
    if ($null -ne $script:SelectedUser) { Update-MfaView }
})

#endregion

#region Token inventory

function Set-InvBusy {
    param([bool]$Busy)
    $inv = $script:Inv
    $inv.Running = $Busy
    foreach ($control in $inv.BtnInvRefresh, $inv.TxtInvSearch, $inv.CmbInvFilter, $inv.BtnInvClose) { $control.IsEnabled = -not $Busy }
    $selected = @($inv.DgInv.SelectedItems | Where-Object { $null -ne $_ })
    $inv.BtnInvAssign.IsEnabled = -not $Busy -and $selected.Count -eq 1 -and -not $selected[0].IsAssigned
    $inv.BtnInvActivate.IsEnabled = -not $Busy -and $selected.Count -eq 1 -and $selected[0].IsAssigned -and $selected[0].Status -ne 'activated'
    $inv.BtnInvUnassign.IsEnabled = -not $Busy -and $selected.Count -gt 0 -and @($selected | Where-Object IsAssigned).Count -eq $selected.Count
    $inv.BtnInvDelete.IsEnabled = -not $Busy -and $selected.Count -gt 0
    $inv.BtnInvBulkAssign.IsEnabled = -not $Busy -and @($inv.Devices | Where-Object { -not $_.IsAssigned }).Count -gt 0
    $inv.PrgInv.Visibility = if ($Busy) { 'Visible' } else { 'Hidden' }
    [System.Windows.Forms.Application]::DoEvents()
}

function Set-InvStatus {
    param([string]$Message)
    $script:Inv.TxtInvStatus.Text = $Message
    [System.Windows.Forms.Application]::DoEvents()
}

function Update-InvCounts {
    $inv = $script:Inv
    $all = @($inv.Devices)
    $free = @($all | Where-Object { -not $_.IsAssigned }).Count
    $inv.TxtInvCount.Text = T 'Inventory.Count' $all.Count $free $inv.View.Count
    $inv.TxtInvEmpty.Visibility = if ($all.Count) { 'Collapsed' } else { 'Visible' }
}

function Update-InvFilter {
    $inv = $script:Inv
    $inv.SearchText = $inv.TxtInvSearch.Text.Trim()
    $inv.Filter = [string]$inv.CmbInvFilter.SelectedItem.Tag
    $inv.View.Refresh()
    Update-InvCounts
}

function Connect-InvView {
    # Sorted by serial number, filtered by free/assigned and search text
    $inv = $script:Inv
    $view = [System.Windows.Data.ListCollectionView]::new($inv.Devices)
    $view.Filter = [Predicate[object]]{
        param($device)
        $state = $script:Inv
        if ($state.Filter -eq 'Free' -and $device.IsAssigned) { return $false }
        if ($state.Filter -eq 'Assigned' -and -not $device.IsAssigned) { return $false }
        if ($state.SearchText -and $device.SearchText.IndexOf($state.SearchText, [StringComparison]::OrdinalIgnoreCase) -lt 0) { return $false }
        $true
    }
    $inv.View = $view
    $inv.DgInv.ItemsSource = $view
    $view.SortDescriptions.Add((New-Object System.ComponentModel.SortDescription 'SerialNumber', 'Ascending'))
    Update-InvCounts
}

function Update-TokenInventory {
    $inv = $script:Inv
    try {
        Set-InvBusy $true
        Set-InvStatus (T 'Inventory.Loading')
        $devices = New-Object System.Collections.ObjectModel.ObservableCollection[object]
        foreach ($device in @(Get-M365HardwareOathDevices)) { $devices.Add($device) }
        $inv.Devices = $devices
        Connect-InvView
        Set-InvStatus (T 'Inventory.Loaded' $devices.Count)
    }
    catch {
        Set-InvStatus ''
        Write-UiError -Message (T 'Inventory.Failed' $_.Exception.Message) -Title (T 'Inventory.Title')
    }
    finally {
        Set-InvBusy $false
    }
}

function Invoke-InvAssign {
    # Assigns the selected free token to the user selected in the main window; the code shown on the token activates it.
    $inv = $script:Inv
    $device = $inv.DgInv.SelectedItem
    $user = $script:SelectedUser
    if ($null -eq $device -or $device.IsAssigned) { return }
    if ($null -eq $user) {
        Show-Message -Text (T 'Inventory.NoUser') -Title (T 'Inventory.Title')
        return
    }
    Add-Type -AssemblyName Microsoft.VisualBasic
    $code = [Microsoft.VisualBasic.Interaction]::InputBox((T 'Inventory.CodePrompt' $device.SerialNumber $user.UserPrincipalName), (T 'Inventory.Assign'), '')
    if ([string]::IsNullOrWhiteSpace($code)) { return }
    if ($code.Trim() -notmatch '^\d{6,8}$') {
        Show-Message -Text (T 'Inventory.InvalidCode') -Title (T 'Inventory.Title') -Icon Warning
        return
    }
    try {
        Set-InvBusy $true
        Set-InvStatus (T 'Inventory.Assigning' $device.SerialNumber $user.UserPrincipalName)
        Set-M365HardwareOathAssignment -Device $device -User $user -VerificationCode $code
        $inv.Changed = $true
        Write-UiLog (T 'Inventory.Assigned' $device.SerialNumber $user.UserPrincipalName) 'Success'
    }
    catch {
        Write-UiError -Message (T 'Inventory.AssignFailed' $device.SerialNumber $_.Exception.Message) -Title (T 'Inventory.Title')
    }
    finally {
        Set-InvBusy $false
    }
    Update-TokenInventory
}

function Invoke-InvActivate {
    # Activates a token that is assigned but not activated yet (e.g. after a bulk assignment), with the code shown on the token
    $inv = $script:Inv
    $device = $inv.DgInv.SelectedItem
    if ($null -eq $device -or -not $device.IsAssigned) { return }
    Add-Type -AssemblyName Microsoft.VisualBasic
    $code = [Microsoft.VisualBasic.Interaction]::InputBox((T 'Inventory.ActivatePrompt' $device.SerialNumber $device.AssignedToName), (T 'Inventory.Activate'), '')
    if ([string]::IsNullOrWhiteSpace($code)) { return }
    if ($code.Trim() -notmatch '^\d{6,8}$') {
        Show-Message -Text (T 'Inventory.InvalidCode') -Title (T 'Inventory.Title') -Icon Warning
        return
    }
    try {
        Set-InvBusy $true
        Enable-M365HardwareOathDevice -Device $device -VerificationCode $code
        $inv.Changed = $true
        Write-UiLog (T 'Inventory.Activated' $device.SerialNumber $device.AssignedToName) 'Success'
    }
    catch {
        Write-UiError -Message (T 'Inventory.ActivateFailed' $device.SerialNumber $_.Exception.Message) -Title (T 'Inventory.Title')
    }
    finally {
        Set-InvBusy $false
    }
    Update-TokenInventory
}

function Show-AssignTokensDialog {
    <#
    .SYNOPSIS
        Asks for the users (group or CSV list) that get the free tokens. Returns Users and SourceText, or $null if cancelled.
    #>
    param([int]$FreeCount)

    [xml]$dialogXaml = Get-Content -LiteralPath (Join-Path $script:AppRoot 'UI\AssignTokensDialog.xaml') -Raw -Encoding UTF8
    $dialog = [Windows.Markup.XamlReader]::Load([System.Xml.XmlNodeReader]::new($dialogXaml))
    $dialog.Owner = $script:Inv.Window
    Update-ElementTexts -Root $dialog

    $at = @{ Window = $dialog; Result = $null }
    foreach ($name in 'TxtAtFree', 'RbAtGroup', 'RbAtCsv', 'PnlAtGroup', 'TxtAtGroupSearch', 'BtnAtFindGroup', 'CmbAtGroup', 'PnlAtCsv', 'TxtAtFile', 'BtnAtBrowse', 'BtnAtStart') {
        $at[$name] = $dialog.FindName($name)
    }
    $at.TxtAtFree.Text = T 'Inventory.BulkAssign.Free' $FreeCount

    $updateSource = {
        $group = [bool]$at.RbAtGroup.IsChecked
        $at.PnlAtGroup.Visibility = if ($group) { 'Visible' } else { 'Collapsed' }
        $at.PnlAtCsv.Visibility = if ($group) { 'Collapsed' } else { 'Visible' }
    }.GetNewClosure()
    $at.RbAtGroup.Add_Checked($updateSource)
    $at.RbAtCsv.Add_Checked($updateSource)

    $findGroup = {
        $term = $at.TxtAtGroupSearch.Text.Trim()
        if (-not $term) { return }
        try { $groups = @(Find-M365Group -SearchTerm $term) }
        catch { Show-Message -Text $_.Exception.Message -Title (T 'Inventory.BulkAssign.Title') -Icon Error; return }
        $at.CmbAtGroup.ItemsSource = $groups
        if (-not $groups.Count) { Show-Message -Text (T 'Report.NoGroups' $term) -Title (T 'Inventory.BulkAssign.Title'); return }
        $at.CmbAtGroup.SelectedIndex = 0
        if ($groups.Count -gt 1) { $at.CmbAtGroup.IsDropDownOpen = $true }
    }.GetNewClosure()
    $at.BtnAtFindGroup.Add_Click($findGroup)
    $at.TxtAtGroupSearch.Add_KeyDown({
        param($src, $keyArgs)
        if ($keyArgs.Key -eq 'Enter') { & $findGroup; $keyArgs.Handled = $true }
    }.GetNewClosure())
    $at.BtnAtBrowse.Add_Click({
        $open = New-Object Microsoft.Win32.OpenFileDialog
        $open.Title = T 'Import.Browse'
        $open.Filter = (T 'Import.CsvFilter') + ' (*.csv;*.txt)|*.csv;*.txt'
        if ($open.ShowDialog($at.Window)) { $at.TxtAtFile.Text = $open.FileName }
    }.GetNewClosure())

    $at.BtnAtStart.Add_Click({
        try {
            if ($at.RbAtGroup.IsChecked) {
                $group = $at.CmbAtGroup.SelectedItem
                if ($null -eq $group) { throw (T 'Report.SelectGroup') }
                $users = @(Get-M365ReportUsers -GroupId $group.Id | Sort-Object UserPrincipalName)
                $source = T 'Report.Scope.GroupName' $group.DisplayName
            }
            else {
                if (-not $at.TxtAtFile.Text) { throw (T 'Import.NoFile') }
                $rows = @(Read-UpnListFile -Path $at.TxtAtFile.Text)
                $map = Resolve-M365UsersByUpn -Upns @($rows | ForEach-Object { $_.Upn }) -Wait { param($Milliseconds) Wait-Ui $Milliseconds }
                $users = @($rows | ForEach-Object { $map[$_.Upn] } | Where-Object { $null -ne $_ })
                $source = [System.IO.Path]::GetFileName($at.TxtAtFile.Text)
            }
            if (-not $users.Count) { throw (T 'Report.Status.NoUsers') }
            $at.Result = @{ Users = $users; SourceText = $source }
            $at.Window.DialogResult = $true
        }
        catch {
            Show-Message -Text $_.Exception.Message -Title (T 'Inventory.BulkAssign.Title') -Icon Warning
        }
    }.GetNewClosure())

    if (-not $dialog.ShowDialog()) { return $null }
    $at.Result
}

function Invoke-InvBulkAssign {
    # Hands out the free tokens to the members of a group or a user list (one each, without activation) and offers the list as Excel
    $inv = $script:Inv
    $free = @($inv.Devices | Where-Object { -not $_.IsAssigned })
    if (-not $free.Count) {
        Show-Message -Text (T 'Inventory.BulkAssign.NoFree') -Title (T 'Inventory.Title')
        return
    }
    $choice = Show-AssignTokensDialog -FreeCount $free.Count
    if ($null -eq $choice) { return }
    $targets = @($choice.Users | Where-Object { $_.AccountEnabled } | Sort-Object Id -Unique).Count
    $assignments = [Math]::Min($free.Count, $targets)
    if (-not (Confirm-Action -Text (T 'Inventory.BulkAssign.Confirm' $free.Count $targets $assignments $choice.SourceText) -Title (T 'Inventory.BulkAssign.Title'))) { return }

    $results = @()
    try {
        Set-InvBusy $true
        Write-UiLog (T 'Inventory.BulkAssign.Started' $assignments $choice.SourceText) 'Warning'
        $results = @(Invoke-TokenBulkAssignment -Devices $free -Users $choice.Users -OnProgress {
            param($Result, $Done, $Total)
            if ($Result.Status -eq 'Assigned') { Write-UiLog (T 'Inventory.BulkAssign.Log' $Result.SerialNumber $Result.Upn) 'Success' }
            else { Write-UiLog (T 'Inventory.BulkAssign.LogFailed' $Result.SerialNumber $Result.Upn $Result.Message) 'Error' }
            Set-InvStatus (T 'Inventory.BulkAssign.Assigning' $Done $Total)
            $script:Inv.Changed = $true
        } -Wait { param($Milliseconds) Wait-Ui $Milliseconds })
    }
    catch {
        Write-UiError -Message (T 'Inventory.Failed' $_.Exception.Message) -Title (T 'Inventory.Title')
    }
    finally {
        Set-InvBusy $false
    }
    Update-TokenInventory
    if (-not $results.Count) { return }

    $assigned = @($results | Where-Object Status -eq 'Assigned').Count
    $failed = @($results | Where-Object Status -eq 'Failed').Count
    $withoutToken = @($results | Where-Object Status -eq 'Warning').Count
    $summary = T 'Inventory.BulkAssign.Done' $assigned $failed $withoutToken
    Set-InvStatus $summary
    Write-UiLog $summary $(if ($failed) { 'Warning' } else { 'Success' })

    # The assignment list is the hand-out document: offer it right away
    if (-not (Confirm-Action -Text ($summary + "`n`n" + (T 'Inventory.BulkAssign.ExportQuestion')) -Title (T 'Inventory.BulkAssign.Title') -Icon Question -DefaultYes)) { return }
    $dialog = New-Object Microsoft.Win32.SaveFileDialog
    $dialog.Title = T 'Report.Export'
    $dialog.Filter = (T 'Report.ExcelFilter') + ' (*.xlsx)|*.xlsx'
    $dialog.FileName = 'TOTP-Zuordnung_{0:yyyy-MM-dd_HHmm}.xlsx' -f (Get-Date)
    if (-not $dialog.ShowDialog($inv.Window)) { return }
    try {
        Export-TokenAssignmentXlsx -Path $dialog.FileName -Rows $results -Tenant (Get-TiTenantLabel) -Source $choice.SourceText
        Write-UiLog (T 'Inventory.BulkAssign.Exported' $dialog.FileName)
    }
    catch {
        Write-UiError -Message (T 'Report.ExportFailed' $_.Exception.Message) -Title (T 'Inventory.Title')
        return
    }
    if (Confirm-Action -Text (T 'Report.OpenFile' $dialog.FileName) -Title (T 'Inventory.Title') -Icon Question -DefaultYes) {
        Start-Process -FilePath $dialog.FileName
    }
}

function Invoke-InvUnassign {
    $inv = $script:Inv
    $devices = @($inv.DgInv.SelectedItems | Where-Object { $null -ne $_ -and $_.IsAssigned })
    if (-not $devices.Count) { return }
    if (-not (Confirm-Action -Text (T 'Inventory.UnassignConfirm' $devices.Count) -Title (T 'Inventory.Title'))) { return }
    try {
        Set-InvBusy $true
        foreach ($device in $devices) {
            try {
                Remove-M365HardwareOathAssignment -Device $device
                $inv.Changed = $true
                Write-UiLog (T 'Inventory.Unassigned' $device.SerialNumber $device.AssignedToName) 'Success'
            }
            catch {
                Write-UiLog (T 'Inventory.ActionFailed' $device.SerialNumber $_.Exception.Message) 'Error'
            }
        }
    }
    finally {
        Set-InvBusy $false
    }
    Update-TokenInventory
}

function Invoke-InvDelete {
    $inv = $script:Inv
    $devices = @($inv.DgInv.SelectedItems | Where-Object { $null -ne $_ })
    if (-not $devices.Count) { return }
    $assigned = @($devices | Where-Object IsAssigned).Count
    $question = T 'Inventory.DeleteConfirm' $devices.Count
    if ($assigned) { $question += "`n`n" + (T 'Inventory.DeleteConfirmAssigned' $assigned) }
    if (-not (Confirm-Action -Text $question -Title (T 'Inventory.Title'))) { return }
    try {
        Set-InvBusy $true
        foreach ($device in $devices) {
            try {
                Remove-M365HardwareOathDevice -Device $device
                $inv.Changed = $true
                Write-UiLog (T 'Inventory.Deleted' $device.SerialNumber) 'Success'
            }
            catch {
                Write-UiLog (T 'Inventory.ActionFailed' $device.SerialNumber $_.Exception.Message) 'Error'
            }
        }
    }
    finally {
        Set-InvBusy $false
    }
    Update-TokenInventory
}

function Show-TokenInventoryWindow {
    <#
    .SYNOPSIS
        Shows the hardware OATH token inventory. Returns $true if tokens were changed.
    #>
    [xml]$inventoryXaml = Get-Content -LiteralPath (Join-Path $script:AppRoot 'UI\TokenInventoryWindow.xaml') -Raw -Encoding UTF8
    $dialog = [Windows.Markup.XamlReader]::Load([System.Xml.XmlNodeReader]::new($inventoryXaml))
    $dialog.Owner = $window
    Update-ElementTexts -Root $dialog

    $script:Inv = @{ Window = $dialog; Devices = (New-Object System.Collections.ObjectModel.ObservableCollection[object]); View = $null
                     Running = $false; Filter = 'All'; SearchText = ''; Changed = $false }
    foreach ($name in @(
        'TxtInvTenant', 'TxtInvSearch', 'CmbInvFilter', 'TxtInvCount', 'BtnInvRefresh', 'DgInv', 'TxtInvEmpty'
        'TxtInvStatus', 'PrgInv', 'BtnInvBulkAssign', 'BtnInvAssign', 'BtnInvActivate', 'BtnInvUnassign', 'BtnInvDelete', 'BtnInvClose'
    )) {
        $script:Inv[$name] = $dialog.FindName($name)
    }
    $inv = $script:Inv
    foreach ($column in $inv.DgInv.Columns) { $column.Header = T ([string]$column.Header) }
    $inv.TxtInvTenant.Text = T 'Header.Tenant' (Get-TiTenantLabel)
    $inv.BtnInvAssign.ToolTip = T 'Inventory.Assign.ToolTip'
    $inv.BtnInvActivate.ToolTip = T 'Inventory.Activate.ToolTip'
    $inv.BtnInvBulkAssign.ToolTip = T 'Inventory.BulkAssign.ToolTip'
    Connect-InvView
    Set-InvBusy $false

    $inv.BtnInvRefresh.Add_Click({ Update-TokenInventory })
    $inv.BtnInvAssign.Add_Click({ Invoke-InvAssign })
    $inv.BtnInvActivate.Add_Click({ Invoke-InvActivate })
    $inv.BtnInvBulkAssign.Add_Click({ Invoke-InvBulkAssign })
    $inv.BtnInvUnassign.Add_Click({ Invoke-InvUnassign })
    $inv.BtnInvDelete.Add_Click({ Invoke-InvDelete })
    $inv.BtnInvClose.Add_Click({ $script:Inv.Window.Close() })
    $inv.CmbInvFilter.Add_SelectionChanged({ Update-InvFilter })
    $inv.DgInv.Add_SelectionChanged({ if (-not $script:Inv.Running) { Set-InvBusy $false } })

    # Search: filter shortly after the last keystroke
    $inv.SearchTimer = New-Object System.Windows.Threading.DispatcherTimer
    $inv.SearchTimer.Interval = [TimeSpan]::FromMilliseconds(300)
    $inv.SearchTimer.Add_Tick({
        $script:Inv.SearchTimer.Stop()
        Update-InvFilter
    })
    $inv.TxtInvSearch.Add_TextChanged({
        $script:Inv.SearchTimer.Stop()
        $script:Inv.SearchTimer.Start()
    })

    # Load after the window is visible, so the progress is shown
    $dialog.Add_Loaded({ Update-TokenInventory })
    $dialog.Add_Closing({
        param($src, $closingArgs)
        if ($script:Inv.Running) { $closingArgs.Cancel = $true }
    })

    $dialog.ShowDialog() | Out-Null
    $inv.SearchTimer.Stop()
    $script:Inv.Changed
}

$BtnTokenInventory.Add_Click({
    $changed = Show-TokenInventoryWindow
    $script:Inv = $null
    if ($changed -and $null -ne $script:SelectedUser) { Update-MfaView }
})

#endregion

#region Bulk Temporary Access Pass

function Set-BtBusy {
    param([bool]$Busy)
    $bt = $script:Bt
    $bt.Running = $Busy
    foreach ($control in $bt.RbBtCsv, $bt.RbBtGroup, $bt.BtnBtBrowse, $bt.TxtBtGroupSearch, $bt.BtnBtFindGroup, $bt.CmbBtGroup,
                         $bt.TxtBtLifetime, $bt.ChkBtUsableOnce, $bt.BtnBtTest, $bt.BtnBtClose) {
        $control.IsEnabled = -not $Busy
    }
    $ready = @($bt.Results | Where-Object { $_.Status -in 'OK', 'Warning' }).Count
    $bt.BtnBtStart.IsEnabled = -not $Busy -and $bt.Tested -and $ready -gt 0
    $bt.BtnBtExport.IsEnabled = -not $Busy -and @($bt.Results).Count -gt 0
    $bt.BtnBtCancel.IsEnabled = $Busy
    $bt.PrgBt.Visibility = if ($Busy) { 'Visible' } else { 'Hidden' }
    [System.Windows.Forms.Application]::DoEvents()
}

function Set-BtStatus {
    param([string]$Message)
    $script:Bt.TxtBtStatus.Text = $Message
    [System.Windows.Forms.Application]::DoEvents()
}

function Reset-BtTest {
    # A changed source invalidates the test
    $bt = $script:Bt
    if (-not $bt.Tested) { return }
    $bt.Tested = $false
    $bt.Results = @()
    $bt.DgBt.ItemsSource = $null
    Set-BtStatus (T 'Import.Status.TestAgain')
    Set-BtBusy $false
}

function Get-BtSourceText {
    # "file.csv" or "group 'Name'" for the confirmation and the export
    $bt = $script:Bt
    if ($bt.RbBtGroup.IsChecked) {
        $group = $bt.CmbBtGroup.SelectedItem
        if ($group) { T 'Report.Scope.GroupName' $group.DisplayName } else { '' }
    }
    else {
        [System.IO.Path]::GetFileName([string]$bt.TxtBtFile.Text)
    }
}

function Get-BtRows {
    # Users to process: Line and UPN from the CSV or the (transitive) members of the group
    $bt = $script:Bt
    if ($bt.RbBtGroup.IsChecked) {
        $group = $bt.CmbBtGroup.SelectedItem
        if ($null -eq $group) { throw (T 'Report.SelectGroup') }
        $line = 0
        foreach ($user in @(Get-M365ReportUsers -GroupId $group.Id | Sort-Object UserPrincipalName)) {
            $line++
            [pscustomobject]@{ Line = $line; Upn = $user.UserPrincipalName }
        }
    }
    else {
        if (-not $bt.TxtBtFile.Text) { throw (T 'Import.NoFile') }
        Read-UpnListFile -Path $bt.TxtBtFile.Text
    }
}

function Get-BtLifetime {
    # Lifetime in minutes (Graph allows 10 to 43200), $null if invalid
    $text = $script:Bt.TxtBtLifetime.Text.Trim()
    $minutes = 0
    if ([int]::TryParse($text, [ref]$minutes) -and $minutes -ge 10 -and $minutes -le 43200) { $minutes } else { $null }
}

function Find-BtGroup {
    $bt = $script:Bt
    $term = $bt.TxtBtGroupSearch.Text.Trim()
    if (-not $term) {
        Show-Message -Text (T 'Report.GroupSearchEmpty') -Title (T 'BulkTap.Title')
        return
    }
    try {
        Set-BtBusy $true
        $groups = @(Find-M365Group -SearchTerm $term)
    }
    catch {
        Write-UiError -Message $_.Exception.Message -Title (T 'BulkTap.Title')
        return
    }
    finally {
        Set-BtBusy $false
    }
    Reset-BtTest
    $bt.CmbBtGroup.ItemsSource = $groups
    if (-not $groups.Count) {
        Show-Message -Text (T 'Report.NoGroups' $term) -Title (T 'BulkTap.Title')
        return
    }
    $bt.CmbBtGroup.SelectedIndex = 0
    if ($groups.Count -gt 1) { $bt.CmbBtGroup.IsDropDownOpen = $true }
    Set-BtStatus (T 'Report.GroupsFound' $groups.Count)
}

function Start-BtTest {
    $bt = $script:Bt
    if ($null -eq (Get-BtLifetime)) {
        Show-Message -Text (T 'BulkTap.InvalidLifetime') -Title (T 'BulkTap.Title')
        $bt.TxtBtLifetime.Focus() | Out-Null
        return
    }
    Reset-BtTest
    try {
        Set-BtBusy $true
        $bt.PrgBt.IsIndeterminate = $true
        Set-BtStatus (T 'Import.Status.Reading')
        $rows = @(Get-BtRows)
        if (-not $rows.Count) { throw (T 'Import.EmptyFile') }
        $bt.Results = @(Test-TapBulk -Rows $rows -Wait { param($Milliseconds) Wait-Ui $Milliseconds })
        $bt.DgBt.ItemsSource = $bt.Results
        $bt.Tested = $true
        $counts = @{ OK = 0; Warning = 0; Error = 0 }
        foreach ($result in $bt.Results) { $counts[$result.Status]++ }
        $summary = T 'Import.TestDone' $bt.Results.Count $counts.OK $counts.Warning $counts.Error
        Set-BtStatus $summary
        Write-UiLog ('{0}: {1} ({2})' -f (T 'BulkTap.Title'), $summary, (Get-BtSourceText))
    }
    catch {
        Set-BtStatus ''
        Write-UiError -Message (T 'BulkTap.Failed' $_.Exception.Message) -Title (T 'BulkTap.Title')
    }
    finally {
        $bt.PrgBt.IsIndeterminate = $false
        Set-BtBusy $false
    }
}

function Start-BtCreate {
    $bt = $script:Bt
    $lifetime = Get-BtLifetime
    if ($null -eq $lifetime) {
        Show-Message -Text (T 'BulkTap.InvalidLifetime') -Title (T 'BulkTap.Title')
        return
    }
    $usableOnce = [bool]$bt.ChkBtUsableOnce.IsChecked
    $ready = @($bt.Results | Where-Object { $_.Status -in 'OK', 'Warning' }).Count
    $onceText = if ($usableOnce) { T 'Tap.UsableOnce' } else { T 'Tap.UsableMultiple' }
    $question = T 'BulkTap.Confirm' $ready $lifetime $onceText (Get-TiTenantLabel)
    if (-not (Confirm-Action -Text $question -Title (T 'BulkTap.Title'))) { return }

    $bt.Cancel = $false
    $bt.Tested = $false   # a second run needs a new test (the TAPs would be replaced)
    try {
        Set-BtBusy $true
        $bt.PrgBt.Value = 0
        Write-UiLog (T 'BulkTap.Log.Started' $ready $lifetime $onceText) 'Warning'
        Invoke-TapBulk -Results $bt.Results -LifetimeMinutes $lifetime -UsableOnce:$usableOnce `
            -OnProgress {
                param($Result, $Done, $Total)
                # The TAP itself is never logged
                if ($Result.Status -eq 'Created') { Write-UiLog (T 'BulkTap.Log.Created' $Result.Upn $Result.ValidText) 'Success' }
                else { Write-UiLog (T 'BulkTap.Log.Failed' $Result.Upn $Result.Message) 'Error' }
                $script:Bt.PrgBt.Value = if ($Total) { 100 * $Done / $Total } else { 100 }
                $script:Bt.DgBt.Items.Refresh()
                Set-BtStatus (T 'BulkTap.Status.Creating' $Done $Total)
            } `
            -ShouldCancel { $script:Bt.Cancel } `
            -Wait { param($Milliseconds) Wait-Ui $Milliseconds }
    }
    catch {
        Write-UiError -Message (T 'BulkTap.Failed' $_.Exception.Message) -Title (T 'BulkTap.Title')
    }
    finally {
        $bt.DgBt.Items.Refresh()
        Set-BtBusy $false
    }

    $created = @($bt.Results | Where-Object Status -eq 'Created').Count
    $failed = @($bt.Results | Where-Object Status -eq 'Failed').Count
    $summary = T 'BulkTap.Done' $created $failed ($ready - $created - $failed)
    Set-BtStatus $summary
    Write-UiLog $summary $(if ($failed) { 'Warning' } else { 'Success' })
    if ($bt.CloseRequested) { $bt.Window.Close() }
}

function Export-BtResults {
    $bt = $script:Bt
    $rows = @($bt.Results)
    if (-not $rows.Count) {
        Show-Message -Text (T 'Report.NothingToExport') -Title (T 'BulkTap.Title')
        return
    }
    # The file contains the passes in clear text
    if (@($rows | Where-Object Status -eq 'Created').Count -and -not (Confirm-Action -Text (T 'BulkTap.ExportWarning') -Title (T 'BulkTap.Title'))) { return }

    $dialog = New-Object Microsoft.Win32.SaveFileDialog
    $dialog.Title = T 'Report.Export'
    $dialog.Filter = (T 'Report.ExcelFilter') + ' (*.xlsx)|*.xlsx'
    $dialog.FileName = 'TAP_{0:yyyy-MM-dd_HHmm}.xlsx' -f (Get-Date)
    if (-not $dialog.ShowDialog($bt.Window)) { return }

    try {
        $onceText = if ($bt.ChkBtUsableOnce.IsChecked) { T 'Tap.UsableOnce' } else { T 'Tap.UsableMultiple' }
        Export-TapBulkXlsx -Path $dialog.FileName -Rows $rows -Tenant (Get-TiTenantLabel) -Source (Get-BtSourceText) `
            -Settings ('{0} min, {1}' -f $bt.TxtBtLifetime.Text.Trim(), $onceText)
        Write-UiLog (T 'BulkTap.Exported' $dialog.FileName) 'Warning'
    }
    catch {
        Write-UiError -Message (T 'Report.ExportFailed' $_.Exception.Message) -Title (T 'BulkTap.Title')
        return
    }
    if (Confirm-Action -Text (T 'Report.OpenFile' $dialog.FileName) -Title (T 'BulkTap.Title') -Icon Question -DefaultYes) {
        Start-Process -FilePath $dialog.FileName
    }
}

function Show-BulkTapWindow {
    [xml]$tapXaml = Get-Content -LiteralPath (Join-Path $script:AppRoot 'UI\BulkTapWindow.xaml') -Raw -Encoding UTF8
    $dialog = [Windows.Markup.XamlReader]::Load([System.Xml.XmlNodeReader]::new($tapXaml))
    $dialog.Owner = $window
    Update-ElementTexts -Root $dialog

    $script:Bt = @{ Window = $dialog; Results = @(); Tested = $false; Running = $false; Cancel = $false; CloseRequested = $false }
    foreach ($name in @(
        'TxtBtTenant', 'RbBtCsv', 'RbBtGroup', 'PnlBtCsv', 'TxtBtFile', 'BtnBtBrowse', 'PnlBtGroup', 'TxtBtGroupSearch', 'BtnBtFindGroup', 'CmbBtGroup'
        'TxtBtLifetime', 'ChkBtUsableOnce', 'DgBt', 'TxtBtStatus', 'PrgBt', 'BtnBtTest', 'BtnBtStart', 'BtnBtExport', 'BtnBtCancel', 'BtnBtClose'
    )) {
        $script:Bt[$name] = $dialog.FindName($name)
    }
    $bt = $script:Bt
    foreach ($column in $bt.DgBt.Columns) { $column.Header = T ([string]$column.Header) }
    $bt.TxtBtTenant.Text = T 'Header.Tenant' (Get-TiTenantLabel)
    Set-BtBusy $false

    $updateSource = {
        $group = [bool]$script:Bt.RbBtGroup.IsChecked
        $script:Bt.PnlBtCsv.Visibility = if ($group) { 'Collapsed' } else { 'Visible' }
        $script:Bt.PnlBtGroup.Visibility = if ($group) { 'Visible' } else { 'Collapsed' }
        Reset-BtTest
    }
    $bt.RbBtCsv.Add_Checked($updateSource)
    $bt.RbBtGroup.Add_Checked($updateSource)
    $bt.BtnBtBrowse.Add_Click({
        $open = New-Object Microsoft.Win32.OpenFileDialog
        $open.Title = T 'Import.Browse'
        $open.Filter = (T 'Import.CsvFilter') + ' (*.csv;*.txt)|*.csv;*.txt'
        if (-not $open.ShowDialog($script:Bt.Window)) { return }
        Reset-BtTest
        $script:Bt.TxtBtFile.Text = $open.FileName
        Set-BtStatus ''
    })
    $bt.BtnBtFindGroup.Add_Click({ Find-BtGroup })
    $bt.TxtBtGroupSearch.Add_KeyDown({
        param($src, $keyArgs)
        if ($keyArgs.Key -eq 'Enter') { Find-BtGroup }
    })
    $bt.CmbBtGroup.Add_SelectionChanged({ Reset-BtTest })
    $bt.TxtBtLifetime.Add_TextChanged({ Reset-BtTest })
    $bt.ChkBtUsableOnce.Add_Click({ Reset-BtTest })
    $bt.BtnBtTest.Add_Click({ Start-BtTest })
    $bt.BtnBtStart.Add_Click({ Start-BtCreate })
    $bt.BtnBtExport.Add_Click({ Export-BtResults })
    $bt.BtnBtClose.Add_Click({ $script:Bt.Window.Close() })
    $bt.BtnBtCancel.Add_Click({
        $script:Bt.Cancel = $true
        $script:Bt.BtnBtCancel.IsEnabled = $false
        Set-BtStatus (T 'Import.Status.Cancelling')
    })

    # Closing during a run: cancel first, the window closes after the current user.
    $dialog.Add_Closing({
        param($src, $closingArgs)
        if ($script:Bt.Running) {
            $script:Bt.Cancel = $true
            $script:Bt.CloseRequested = $true
            $closingArgs.Cancel = $true
            Set-BtStatus (T 'Import.Status.Cancelling')
        }
    })

    $dialog.ShowDialog() | Out-Null
    # The passes are not kept after the window is closed
    foreach ($result in $script:Bt.Results) { $result.Pass = '' }
}

$BtnBulkTap.Add_Click({
    Show-BulkTapWindow
    $script:Bt = $null
    if ($null -ne $script:SelectedUser) { Update-MfaView }
})

#endregion

#region Update check

function Start-UpdateCheck {
    # Compares the version with the latest GitHub release in the background; the result is only a log line.
    try {
        $script:UpdateJob = Start-Job -ArgumentList $script:RepoUrl -ScriptBlock {
            param($RepoUrl)
            [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
            $api = $RepoUrl -replace '^https://github\.com/', 'https://api.github.com/repos/'
            $release = Invoke-RestMethod -Uri "$api/releases/latest" -Headers @{ 'User-Agent' = 'M365MfaTool' } -TimeoutSec 15
            [pscustomobject]@{ Tag = [string]$release.tag_name; Url = [string]$release.html_url }
        }
    }
    catch { return }

    $script:UpdateTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:UpdateTimer.Interval = [TimeSpan]::FromSeconds(3)
    $script:UpdateTimer.Tag = 0
    $script:UpdateTimer.Add_Tick({
        $timer = $script:UpdateTimer
        $job = $script:UpdateJob
        $timer.Tag = [int]$timer.Tag + 1
        if ($job.State -in 'NotStarted', 'Running' -and [int]$timer.Tag -lt 20) { return }
        $timer.Stop()
        try {
            $release = Receive-Job -Job $job -ErrorAction Stop
            $latest = [version](([string]$release.Tag) -replace '^v', '')
            if ($latest -gt [version]$script:AppVersion) { Write-UiLog (T 'Update.Available' $release.Tag $release.Url) 'Warning' }
        }
        catch { }   # No internet, API limit etc.: silently ignored
        finally { Remove-Job -Job $job -Force -ErrorAction SilentlyContinue }
    })
    $script:UpdateTimer.Start()
}

#endregion

#region Start

$window.Add_Closing({
    if (Test-M365GraphConnection) { Disconnect-M365Graph }
})

# Fill the language selection and set all texts
$languages = @(Get-UiLanguages)
$CmbLanguage.ItemsSource = $languages
$CmbLanguage.SelectedItem = $languages | Where-Object Code -eq (Get-UiLanguage) | Select-Object -First 1
Update-UiTexts
Set-ConnectionStatus $null
Clear-SelectedUser
Update-MethodInputs
Set-Busy $false

# Separator in the log file so that several sessions per day can be told apart
Write-LogFile -Line ('{0} ===== M365 MFA Administration Tool {4} started by {1}\{2} on {3} =====' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $env:USERDOMAIN, $env:USERNAME, $env:COMPUTERNAME, $script:AppVersion)
Write-UiLog (T 'Log.Started')
Write-UiLog (T 'App.Version' $script:AppVersion)
if (-not $script:LogFileDisabled) { Write-UiLog (T 'Log.FileLocation' $script:LogFolder) }
Start-UpdateCheck
$window.ShowDialog() | Out-Null

#endregion
