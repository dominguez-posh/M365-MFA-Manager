<#
.SYNOPSIS
    Sets up MFA methods on behalf of a user.

.DESCRIPTION
    FIDO2 (DSInternals.Passkeys), hardware OATH/TOTP (fixed and programmable cards, fake MFA)
    and Temporary Access Pass. Requires the Graph functions from Graph.psm1
    (Invoke-M365GraphRequest, ConvertTo-LocalDate), which must be loaded globally.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Excel export of the bulk results
Import-Module (Join-Path $PSScriptRoot 'Xlsx.psm1') -Force

# Methods are addressed by language-independent IDs (see Invoke-MfaProvisioning);
# the display names come from the language files (Languages/*.json).

$script:TapLifetimeMinutes  = 120
$script:OathManufacturer    = 'unique projects'
$script:OathIssuer          = 'Microsoft 365'
$script:Base32Alphabet      = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'
$script:Fido2ModuleVersion  = '1.0.6'   # Newer DSInternals.Passkeys versions have a changed API
$script:AuthMethodPolicyUrl = 'https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/AdminAuthMethods'

#region General helpers

function New-ProvisioningResult {
    # AddedMethodIds/RemovedMethodIds: IDs of the created or removed methods.
    # After provisioning, the GUI uses them to wait until Graph returns the new state.
    param(
        [Parameter(Mandatory)][string]$Message,
        $TemporaryAccessPass = $null,
        $TotpSetup = $null,
        [string[]]$AddedMethodIds = @(),
        [string[]]$RemovedMethodIds = @()
    )
    [pscustomobject]@{
        Message             = $Message
        TemporaryAccessPass = $TemporaryAccessPass
        TotpSetup           = $TotpSetup
        AddedMethodIds      = $AddedMethodIds
        RemovedMethodIds    = $RemovedMethodIds
    }
}

function Get-RequiredOption {
    param([hashtable]$Options, [string]$Name, [string]$Label)
    $value = if ($Options -and $Options.ContainsKey($Name)) { [string]$Options[$Name] } else { '' }
    if ([string]::IsNullOrWhiteSpace($value)) { throw (T 'Prov.MissingInput' (T $Label)) }
    return $value.Trim()
}

function Import-RequiredModule {
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$RequiredVersion,
        [switch]$SkipPublisherCheck
    )
    $loaded = Get-Module -Name $Name
    if ($loaded -and (-not $RequiredVersion -or $loaded.Version -eq [version]$RequiredVersion)) { return }

    $available = @(Get-Module -ListAvailable -Name $Name |
        Where-Object { -not $RequiredVersion -or $_.Version -eq [version]$RequiredVersion })
    if (-not $available.Count) {
        # Normally already installed at sign-in; otherwise install now without console prompts.
        Install-RequiredModule -Name $Name -RequiredVersion $RequiredVersion -SkipPublisherCheck:$SkipPublisherCheck
    }

    if ($loaded) { Remove-Module -Name $Name -Force -ErrorAction SilentlyContinue }
    $importParams = @{ Name = $Name; ErrorAction = 'Stop' }
    if ($RequiredVersion) { $importParams.RequiredVersion = $RequiredVersion }
    try { Import-Module @importParams }
    catch { throw (T 'Module.LoadFailed' $Name $_.Exception.Message) }
}

#endregion

#region TOTP / Base32

function New-RandomBase32 {
    param([int]$Length)
    $bytes = New-Object byte[] $Length
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    -join ($bytes | ForEach-Object { $script:Base32Alphabet[$_ % 32] })
}

function ConvertTo-Base32 {
    param([Parameter(Mandatory)][byte[]]$Bytes)
    $output = New-Object System.Text.StringBuilder
    $buffer = 0
    $bitCount = 0
    foreach ($b in $Bytes) {
        $buffer = (($buffer -shl 8) -bor $b) -band 0xFFFF
        $bitCount += 8
        while ($bitCount -ge 5) {
            [void]$output.Append($script:Base32Alphabet[($buffer -shr ($bitCount - 5)) -band 0x1F])
            $bitCount -= 5
        }
    }
    if ($bitCount -gt 0) {
        [void]$output.Append($script:Base32Alphabet[($buffer -shl (5 - $bitCount)) -band 0x1F])
    }
    $output.ToString()
}

function ConvertFrom-Base32 {
    param([Parameter(Mandatory)][string]$Secret)
    $bytes = New-Object System.Collections.Generic.List[byte]
    $buffer = 0
    $bitCount = 0
    foreach ($char in $Secret.ToCharArray()) {
        $value = $script:Base32Alphabet.IndexOf($char)
        if ($value -lt 0) { throw (T 'Totp.InvalidChar' $char) }
        $buffer = (($buffer -shl 5) -bor $value) -band 0xFFFF
        $bitCount += 5
        if ($bitCount -ge 8) {
            $bytes.Add([byte](($buffer -shr ($bitCount - 8)) -band 0xFF))
            $bitCount -= 8
        }
    }
    $bytes.ToArray()
}

function ConvertTo-NormalizedTotpSecret {
    param([Parameter(Mandatory)][string]$Secret)
    $normalized = ($Secret -replace '[\s\-=]', '').ToUpperInvariant()
    if ($normalized -notmatch '^[A-Z2-7]+$') { throw (T 'Totp.InvalidSecret') }
    if ($normalized.Length -lt 16) { throw (T 'Totp.SecretTooShort') }
    $normalized
}

function New-TotpSecret {
    param([int]$ByteLength = 20) # 160 bits of entropy is the standard
    $bytes = New-Object byte[] $ByteLength
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    ConvertTo-Base32 -Bytes $bytes
}

function Get-TotpCode {
    param(
        [Parameter(Mandatory)][string]$Secret,
        [int]$TimeStepSeconds = 30,
        [ValidateSet('hmacsha1', 'hmacsha256')][string]$HashFunction = 'hmacsha1',
        [DateTimeOffset]$Timestamp = [DateTimeOffset]::UtcNow
    )
    $key = ConvertFrom-Base32 -Secret $Secret
    $counter = [int64][Math]::Floor($Timestamp.ToUnixTimeSeconds() / $TimeStepSeconds)
    $counterBytes = [BitConverter]::GetBytes($counter)
    if ([BitConverter]::IsLittleEndian) { [Array]::Reverse($counterBytes) }

    $hmacType = if ($HashFunction -eq 'hmacsha256') { 'System.Security.Cryptography.HMACSHA256' } else { 'System.Security.Cryptography.HMACSHA1' }
    $hmac = New-Object $hmacType -ArgumentList (, $key)
    $hash = $hmac.ComputeHash($counterBytes)
    $hmac.Dispose()

    $offset = $hash[$hash.Length - 1] -band 0xF
    $binary = (($hash[$offset] -band 0x7F) -shl 24) -bor
              (($hash[$offset + 1] -band 0xFF) -shl 16) -bor
              (($hash[$offset + 2] -band 0xFF) -shl 8) -bor
              ($hash[$offset + 3] -band 0xFF)
    ($binary % 1000000).ToString().PadLeft(6, '0')
}

function New-TotpQrCodePng {
    param([Parameter(Mandatory)][string]$Text)
    # QRCodeGenerator ships QRCoder; the QR code is generated in memory only (no file containing the secret on disk).
    Import-RequiredModule -Name 'QRCodeGenerator'
    $generator = New-Object -TypeName QRCoder.QRCodeGenerator
    $data = $generator.CreateQrCode($Text, 'Q')
    $code = New-Object -TypeName QRCoder.PngByteQRCode -ArgumentList ($data)
    [byte[]]$code.GetGraphic(8)
}

function Find-HardwareOathDevice {
    param([Parameter(Mandatory)][string]$SerialNumber)
    $uri = 'beta/directory/authenticationMethodDevices/hardwareOathDevices'
    while ($uri) {
        $response = Invoke-M365GraphRequest -Uri $uri
        foreach ($device in @($response['value'])) {
            if ($null -ne $device -and [string]$device['serialNumber'] -eq $SerialNumber) { return $device }
        }
        $uri = $response['@odata.nextLink']
    }
    return $null
}

function New-HardwareOathTotp {
    <#
        Creates a hardware OATH device (or reuses an existing, unassigned one),
        assigns it to the user and activates it with a code calculated from the secret.
        Returns MethodId and DeviceId. Rolls back on errors.
        Devices: serial number -> device, loaded once by the bulk import (instead of searching per token).
    #>
    param(
        $User,   # $null with InventoryOnly
        [Parameter(Mandatory)][string]$SerialNumber,
        [Parameter(Mandatory)][string]$SecretKey,
        [Parameter(Mandatory)][string]$DisplayName,
        [Parameter(Mandatory)][string]$Model,
        [string]$Manufacturer = $script:OathManufacturer,
        [ValidateSet('hmacsha1', 'hmacsha256')][string]$HashFunction = 'hmacsha1',
        [ValidateSet(30, 60)][int]$TimeIntervalInSeconds = 30,
        [hashtable]$Devices,
        [switch]$ReuseExistingDevice,
        [switch]$InventoryOnly   # only create the device; it is assigned later (token inventory)
    )

    $userPart = if ($null -ne $User) { [uri]::EscapeDataString($User.Id) } else { '' }
    $devicesUri = 'beta/directory/authenticationMethodDevices/hardwareOathDevices'
    $deviceId = $null
    $createdDevice = $false
    $assignedMethodId = $null

    try {
        $existing = if ($null -ne $Devices) { $Devices[$SerialNumber] } else { Find-HardwareOathDevice -SerialNumber $SerialNumber }
        if ($null -ne $existing) {
            $assignedTo = $existing['assignedTo']
            if ($assignedTo -is [System.Collections.IDictionary] -and $assignedTo['id']) {
                throw (T 'Totp.AlreadyAssigned' $SerialNumber $assignedTo['displayName'])
            }
            if ($ReuseExistingDevice) {
                $deviceId = [string]$existing['id']
            }
            else {
                # New secret -> replace the existing, unassigned entry.
                Invoke-M365GraphRequest -Method DELETE -Uri "$devicesUri/$([uri]::EscapeDataString([string]$existing['id']))" | Out-Null
            }
        }

        if (-not $deviceId) {
            $device = Invoke-M365GraphRequest -Method POST -Uri $devicesUri -Body @{
                displayName           = $DisplayName
                serialNumber          = $SerialNumber
                manufacturer          = $Manufacturer
                model                 = $Model
                secretKey             = $SecretKey
                timeIntervalInSeconds = $TimeIntervalInSeconds
                hashFunction          = $HashFunction
            }
            $deviceId = [string]$device['id']
            $createdDevice = $true
        }
        if ($InventoryOnly) { return [pscustomobject]@{ MethodId = $null; DeviceId = $deviceId } }

        $method = Invoke-M365GraphRequest -Method POST -Uri "beta/users/$userPart/authentication/hardwareOathMethods" -Body @{
            device = @{ id = $deviceId }
        }
        $assignedMethodId = [string]$method['id']
        if (-not $assignedMethodId) { $assignedMethodId = $deviceId }

        Invoke-M365GraphRequest -Method POST -Uri "beta/users/$userPart/authentication/hardwareOathMethods/$([uri]::EscapeDataString($assignedMethodId))/activate" -Body @{
            verificationCode = Get-TotpCode -Secret $SecretKey -TimeStepSeconds $TimeIntervalInSeconds -HashFunction $HashFunction
            displayName      = $DisplayName
        } | Out-Null

        return [pscustomobject]@{ MethodId = $assignedMethodId; DeviceId = $deviceId }
    }
    catch {
        $message = $_.Exception.Message
        # Roll back so that no half-configured tokens remain.
        if ($assignedMethodId) {
            try { Invoke-M365GraphRequest -Method DELETE -Uri "beta/users/$userPart/authentication/hardwareOathMethods/$([uri]::EscapeDataString($assignedMethodId))" | Out-Null } catch { }
        }
        if ($createdDevice -and $deviceId) {
            try { Invoke-M365GraphRequest -Method DELETE -Uri "$devicesUri/$([uri]::EscapeDataString($deviceId))" | Out-Null } catch { }
        }
        throw (T 'Totp.SetupFailed' $message)
    }
}

#endregion

#region Provisioning methods

function Start-Fido2Provisioning {
    param([Parameter(Mandatory)]$User, [hashtable]$Options = @{})

    $serial = Get-RequiredOption -Options $Options -Name 'SerialNumber' -Label 'Config.Serial.Fido2'
    $upn = [string]$User.UserPrincipalName
    if ($upn.Length -gt 64) {
        throw (T 'Fido2.UpnTooLong' $upn.Length)
    }

    Import-RequiredModule -Name 'DSInternals.Passkeys' -RequiredVersion $script:Fido2ModuleVersion -SkipPublisherCheck

    $displayName = "FIDO2-$serial"
    $fido2Uri = "beta/users/$([uri]::EscapeDataString($User.Id))/authentication/fido2Methods"
    $before = @((Invoke-M365GraphRequest -Uri $fido2Uri)['value'] | Where-Object { $null -ne $_ } | ForEach-Object { [string]$_['id'] })

    try {
        # Object ID instead of UPN: after a UPN change (e.g. break-glass account) the ID resolves reliably right away.
        $registrationOptions = Get-PasskeyRegistrationOptions -UserId $User.Id -ErrorAction Stop
        # Opens the Windows Security dialog (PIN / touch of the key).
        $passkey = New-Passkey -Options $registrationOptions -DisplayName $displayName -ErrorAction Stop
        $registered = Register-Passkey -Passkey $passkey -UserId $User.Id -ErrorAction Stop
    }
    catch {
        $details = if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $_.ErrorDetails.Message } else { '' }
        $inner = $_.Exception
        while ($inner.InnerException) { $inner = $inner.InnerException }
        $text = "$details $($_.Exception.Message) $($inner.Message)"
        if ($text -like '*Fido credential policy*') {
            throw (T 'Fido2.PolicyDisabled' $script:AuthMethodPolicyUrl)
        }
        throw (T 'Fido2.Failed' $(if ($details) { $details } else { $inner.Message }))
    }

    $addedId = $null
    if ($null -ne $registered -and $registered.PSObject.Properties['Id'] -and $registered.Id) {
        $addedId = [string]$registered.Id
    }
    else {
        $after = @((Invoke-M365GraphRequest -Uri $fido2Uri)['value'] | Where-Object { $null -ne $_ } | ForEach-Object { [string]$_['id'] })
        $addedId = $after | Where-Object { $before -notcontains $_ } | Select-Object -First 1
    }

    $model = if ($null -ne $registered -and $registered.PSObject.Properties['Model']) { $registered.Model } else { $null }
    $message = if ($model) { T 'Fido2.RegisteredWithModel' $displayName $upn $model } else { T 'Fido2.Registered' $displayName $upn }
    New-ProvisioningResult -Message $message -AddedMethodIds @($addedId)
}

function Start-FixedSecretTotpProvisioning {
    param([Parameter(Mandatory)]$User, [hashtable]$Options = @{})

    $serial = Get-RequiredOption -Options $Options -Name 'SerialNumber' -Label 'Config.Serial.Card'
    $secret = ConvertTo-NormalizedTotpSecret -Secret (Get-RequiredOption -Options $Options -Name 'Secret' -Label 'Config.Secret')

    $hashFunction = if ($Options.ContainsKey('HashFunction') -and $Options.HashFunction) { [string]$Options.HashFunction } else { 'hmacsha1' }
    $timeStep = if ($Options.ContainsKey('TimeStep') -and $Options.TimeStep) { [int]$Options.TimeStep } else { 30 }

    $token = New-HardwareOathTotp -User $User -SerialNumber $serial -SecretKey $secret `
        -DisplayName "TOTP card $serial" -Model 'TOTP card (fixed secret)' -ReuseExistingDevice `
        -HashFunction $hashFunction -TimeIntervalInSeconds $timeStep
    $secret = $null

    New-ProvisioningResult -Message (T 'Prov.FixedTotp.Done' $serial $User.UserPrincipalName) -AddedMethodIds @($token.MethodId)
}

function Start-ProgrammableTotpProvisioning {
    param([Parameter(Mandatory)]$User, [hashtable]$Options = @{})

    $serial = Get-RequiredOption -Options $Options -Name 'SerialNumber' -Label 'Config.Serial.Card'
    $secret = New-TotpSecret

    $token = New-HardwareOathTotp -User $User -SerialNumber $serial -SecretKey $secret `
        -DisplayName "TOTP card $serial" -Model 'TOTP Generic'

    $account = [string]$User.UserPrincipalName
    $issuer = [uri]::EscapeDataString($script:OathIssuer)
    $otpUri = 'otpauth://totp/{0}:{1}?secret={2}&issuer={0}&algorithm=SHA1&digits=6&period=30' -f $issuer, [uri]::EscapeDataString($account), $secret

    $qrPng = $null
    $qrWarning = ''
    try { $qrPng = New-TotpQrCodePng -Text $otpUri }
    catch { $qrWarning = ' ' + (T 'Prov.QrFailed' $_.Exception.Message) }

    $setup = [pscustomobject]@{
        UserPrincipalName = $account
        SerialNumber      = $serial
        Secret            = $secret
        OtpAuthUri        = $otpUri
        QrCodePng         = $qrPng
    }

    New-ProvisioningResult -Message ((T 'Prov.ProgTotp.Done' $serial $account) + $qrWarning) `
        -TotpSetup $setup -AddedMethodIds @($token.MethodId)
}

function New-FakeMfaToken {
    # TOTP with a random secret that is discarded after activation:
    # at sign-in, an MFA method is requested that nobody can satisfy.
    # The secret is returned only so it can be stored encrypted for hrdnr (see Start-FakeMfaProvisioning).
    param([Parameter(Mandatory)]$User)
    $serial = 'FAKE-' + (New-RandomBase32 -Length 16)
    $secret = New-TotpSecret
    $token = New-HardwareOathTotp -User $User -SerialNumber $serial -SecretKey $secret `
        -DisplayName 'Fake-MFA' -Model 'Fake-MFA'
    $token | Add-Member -NotePropertyName SerialNumber -NotePropertyValue $serial
    $token | Add-Member -NotePropertyName Secret -NotePropertyValue $secret -PassThru
}

#region hrdnr: fake MFA secret stored encrypted

# hrdnr keeps one RSA key pair per tenant. With its public key, the secret of a
# fake MFA token is stored encrypted (RSA-OAEP-SHA256) in the open extension com.hrdnr.fakeMfa on the user; only
# hrdnr can decrypt it and show the current 6-digit code in an emergency. The public key comes either from the tenant
# (open extension com.hrdnr.fakeMfaKey on the organization, written by hrdnr) or is pasted from hrdnr.
# Format: hrdnr-fakemfa:1:<keyId>:<modulus Base64>:<exponent Base64>
$script:HrdnrSecretExtension = 'com.hrdnr.fakeMfa'
$script:HrdnrKeyExtension    = 'com.hrdnr.fakeMfaKey'

function ConvertFrom-HrdnrFakeMfaKey {
    # Checks the key and returns KeyId, Modulus and Exponent (bytes). Throws on an invalid key.
    param([Parameter(Mandatory)][string]$Key)
    $parts = $Key.Trim() -split ':'
    $valid = $parts.Count -eq 5 -and $parts[0] -eq 'hrdnr-fakemfa' -and $parts[1] -eq '1' -and $parts[2] -match '^[0-9a-f]{16}$'
    if ($valid) {
        try {
            $modulus = [Convert]::FromBase64String($parts[3])
            $exponent = [Convert]::FromBase64String($parts[4])
            $valid = $modulus.Length -ge 256 -and $exponent.Length -ge 1 -and $exponent.Length -le 8
        }
        catch { $valid = $false }
    }
    if (-not $valid) { throw (T 'Prov.Fake.HrdnrInvalid') }
    [pscustomobject]@{ KeyId = $parts[2]; Modulus = $modulus; Exponent = $exponent; Key = $Key.Trim() }
}

function Protect-HrdnrFakeMfaSecret {
    # Base32 secret, encrypted RSA-OAEP-SHA256 with the hrdnr key of the tenant, as Base64.
    # RSACng: RSACryptoServiceProvider (Windows PowerShell 5.1 default) only supports OAEP with SHA-1.
    param([Parameter(Mandatory)][string]$Secret, [Parameter(Mandatory)]$HrdnrKey)
    $rsa = New-Object System.Security.Cryptography.RSACng
    try {
        $parameters = New-Object System.Security.Cryptography.RSAParameters
        $parameters.Modulus = $HrdnrKey.Modulus
        $parameters.Exponent = $HrdnrKey.Exponent
        $rsa.ImportParameters($parameters)
        $plain = [Text.Encoding]::ASCII.GetBytes($Secret)
        try { [Convert]::ToBase64String($rsa.Encrypt($plain, [System.Security.Cryptography.RSAEncryptionPadding]::OaepSHA256)) }
        finally { [Array]::Clear($plain, 0, $plain.Length) }
    }
    finally { $rsa.Dispose() }
}

function Set-HrdnrFakeMfaSecret {
    # Writes (or replaces) the open extension com.hrdnr.fakeMfa on the user.
    param(
        [Parameter(Mandatory)]$User,
        [Parameter(Mandatory)][string]$SerialNumber,
        [Parameter(Mandatory)][string]$KeyId,
        [Parameter(Mandatory)][string]$EncryptedSecret
    )
    $userPart = [uri]::EscapeDataString($User.Id)
    $body = @{
        serialNumber    = $SerialNumber
        keyId           = $KeyId
        secret          = $EncryptedSecret
        algorithm       = 'RSA-OAEP-256'
        createdDateTime = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    }
    $exists = $false
    try { $exists = $null -ne (Invoke-M365GraphRequest -Uri "v1.0/users/$userPart/extensions/$script:HrdnrSecretExtension") }
    catch { $exists = $false }
    if ($exists) {
        Invoke-M365GraphRequest -Method PATCH -Uri "v1.0/users/$userPart/extensions/$script:HrdnrSecretExtension" -Body $body | Out-Null
    }
    else {
        $body['@odata.type'] = '#microsoft.graph.openTypeExtension'
        $body['extensionName'] = $script:HrdnrSecretExtension
        Invoke-M365GraphRequest -Method POST -Uri "v1.0/users/$userPart/extensions" -Body $body | Out-Null
    }
}

function Get-HrdnrFakeMfaKeyFromTenant {
    # Public hrdnr key stored in the tenant (organization extension), or $null if there is none or it cannot be read
    # (reading organization extensions may need Organization.Read.All).
    try {
        $org = @((Invoke-M365GraphRequest -Uri 'v1.0/organization?$select=id')['value'])[0]
        if (-not $org) { return $null }
        $ext = Invoke-M365GraphRequest -Uri "v1.0/organization/$([uri]::EscapeDataString([string]$org['id']))/extensions/$script:HrdnrKeyExtension"
        $key = [string]$ext['key']
        if (-not $key) { return $null }
        ConvertFrom-HrdnrFakeMfaKey -Key $key
    }
    catch { $null }
}

#endregion

function Remove-HardwareOathToken {
    # Removes a token from the user and from the device inventory.
    param([Parameter(Mandatory)]$User, [Parameter(Mandatory)]$Token)
    $userPart = [uri]::EscapeDataString($User.Id)
    Invoke-M365GraphRequest -Method DELETE -Uri "beta/users/$userPart/authentication/hardwareOathMethods/$([uri]::EscapeDataString($Token.MethodId))" | Out-Null
    Invoke-M365GraphRequest -Method DELETE -Uri "beta/directory/authenticationMethodDevices/hardwareOathDevices/$([uri]::EscapeDataString($Token.DeviceId))" | Out-Null
}

function Start-FakeMfaProvisioning {
    param([Parameter(Mandatory)]$User, [hashtable]$Options = @{})

    # Options.HrdnrKey: public hrdnr key of the tenant -> store the secret encrypted for hrdnr instead of discarding it
    $hrdnrKey = if ($Options['HrdnrKey']) { ConvertFrom-HrdnrFakeMfaKey -Key $Options['HrdnrKey'] } else { $null }

    $token = New-FakeMfaToken -User $User
    $message = T 'Prov.Fake.Done' $token.SerialNumber $User.UserPrincipalName
    if ($hrdnrKey) {
        try {
            $encrypted = Protect-HrdnrFakeMfaSecret -Secret $token.Secret -HrdnrKey $hrdnrKey
            Set-HrdnrFakeMfaSecret -User $User -SerialNumber $token.SerialNumber -KeyId $hrdnrKey.KeyId -EncryptedSecret $encrypted
            $message = T 'Prov.Fake.DoneHrdnr' $token.SerialNumber $User.UserPrincipalName $hrdnrKey.KeyId
        }
        catch {
            $message += ' ' + (T 'Prov.Fake.HrdnrFailed' $_.Exception.Message)
        }
    }
    $token.Secret = $null
    New-ProvisioningResult -Message $message -AddedMethodIds @($token.MethodId)
}

function Start-TemporaryAccessPassProvisioning {
    param([Parameter(Mandatory)]$User, [hashtable]$Options = @{})

    $userPart = [uri]::EscapeDataString($User.Id)
    $baseUri = "v1.0/users/$userPart/authentication/temporaryAccessPassMethods"

    # A user can only have one TAP -> remove existing ones first (the GUI asks for confirmation).
    $existing = @((Invoke-M365GraphRequest -Uri $baseUri)['value'] | Where-Object { $null -ne $_ })
    $removedIds = @()
    foreach ($tap in $existing) {
        Invoke-M365GraphRequest -Method DELETE -Uri "$baseUri/$([uri]::EscapeDataString([string]$tap['id']))" | Out-Null
        $removedIds += [string]$tap['id']
    }

    # Without startDateTime, the TAP is valid immediately. Lifetime and single use: bulk TAP options.
    $lifetime = if ($Options.ContainsKey('LifetimeMinutes') -and [int]$Options.LifetimeMinutes -gt 0) { [int]$Options.LifetimeMinutes } else { $script:TapLifetimeMinutes }
    $response = Invoke-M365GraphRequest -Method POST -Uri $baseUri -Body @{
        lifetimeInMinutes = $lifetime
        isUsableOnce      = [bool]($Options.ContainsKey('UsableOnce') -and $Options.UsableOnce)
    }

    $start = ConvertTo-LocalDate $response['startDateTime']
    if ($null -eq $start) { $start = Get-Date }
    $lifetime = [int]$response['lifetimeInMinutes']

    $tapInfo = [pscustomobject]@{
        UserPrincipalName = $User.UserPrincipalName
        Pass              = [string]$response['temporaryAccessPass']
        ValidFrom         = $start
        ValidUntil        = $start.AddMinutes($lifetime)
        LifetimeInMinutes = $lifetime
        IsUsableOnce      = [bool]$response['isUsableOnce']
    }

    $message = T 'Prov.Tap.Done' $User.UserPrincipalName $tapInfo.ValidFrom.ToString((T 'Format.DateTime')) $tapInfo.ValidUntil.ToString((T 'Format.DateTime'))
    if ($existing.Count) { $message += ' ' + (T 'Prov.Tap.Replaced') }
    New-ProvisioningResult -Message $message -TemporaryAccessPass $tapInfo `
        -AddedMethodIds @([string]$response['id']) -RemovedMethodIds $removedIds
}

#endregion

#region Break-glass account

$script:GlobalAdminRoleId = '62e90394-69f5-4237-9190-012177145e10'

function New-SecureRandomPassword {
    # Cryptographically random password; never displayed, logged or stored.
    param([int]$Length = 255)
    $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()-_=+[]{}?'
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $buffer = New-Object byte[] 4
    do {
        $password = -join (1..$Length | ForEach-Object {
            $rng.GetBytes($buffer)
            $chars[[BitConverter]::ToUInt32($buffer, 0) % $chars.Length]
        })
    } until ($password -cmatch '[a-z]' -and $password -cmatch '[A-Z]' -and $password -match '\d' -and $password -match '[^a-zA-Z\d]')
    $password
}

function Invoke-WithRetry {
    # Newly created objects are only available everywhere in Graph after a few seconds.
    param(
        [Parameter(Mandatory)][scriptblock]$Action,
        [Parameter(Mandatory)][string]$Description,
        [scriptblock]$OnProgress,
        [scriptblock]$Wait,
        [int]$Attempts = 8,
        [int]$DelayMilliseconds = 5000
    )
    for ($attempt = 1; ; $attempt++) {
        try {
            return & $Action
        }
        catch {
            if ($attempt -ge $Attempts) { throw }
            & $OnProgress (T 'BG.Retry' (T $Description) ($attempt + 1) $Attempts)
            & $Wait $DelayMilliseconds
        }
    }
}

function New-M365BreakGlassAccount {
    <#
    .SYNOPSIS
        Creates a break-glass account and secures it with fake MFA or FIDO2.
    .DESCRIPTION
        1. Create the user with a random, unknown password (255 characters)
        2. Change UPN, mail nickname and display name to the object ID (UPN max. 64 characters for FIDO2)
        3. Optionally assign Global Administrator
        4. Register fake MFA so the account is protected immediately
        5. Optionally register a FIDO2 key and then remove the fake MFA again
    .PARAMETER OnProgress
        Called with status messages (e.g. for the GUI log).
    .PARAMETER Wait
        Called with milliseconds to wait for Graph replication (GUI: without freezing).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Domain,
        [switch]$AssignGlobalAdmin,
        [string]$Fido2SerialNumber,
        [scriptblock]$OnProgress = { param($Message) Write-Verbose $Message },
        [scriptblock]$Wait = { param($Milliseconds) Start-Sleep -Milliseconds $Milliseconds }
    )

    $retry = @{ OnProgress = $OnProgress; Wait = $Wait }
    $maxLocalPart = 64 - 1 - $Domain.Length
    if ($maxLocalPart -lt 8) { throw (T 'BG.DomainTooLong' $Domain) }

    # 1. Create user
    $tempName = [guid]::NewGuid().ToString('N').Substring(0, [Math]::Min(32, $maxLocalPart))
    & $OnProgress (T 'BG.Creating' $Domain)
    $created = Invoke-M365GraphRequest -Method POST -Uri 'v1.0/users' -Body @{
        accountEnabled    = $true
        displayName       = "Break Glass Account $tempName"
        mailNickname      = $tempName
        userPrincipalName = "$tempName@$Domain"
        passwordProfile   = @{ password = (New-SecureRandomPassword); forceChangePasswordNextSignIn = $false }
    }
    $userId = [string]$created['id']

    # 2. Rename to object ID
    $localPart = $userId.Substring(0, [Math]::Min($userId.Length, $maxLocalPart))
    $user = [pscustomobject]@{
        Id                = $userId
        DisplayName       = "Break Glass Account-$localPart"
        UserPrincipalName = "$localPart@$Domain"
        Mail              = $null
        AccountEnabled    = $true
    }
    Invoke-WithRetry @retry -Description 'BG.Step.Rename' -Action {
        Invoke-M365GraphRequest -Method PATCH -Uri "v1.0/users/$userId" -Body @{
            userPrincipalName = $user.UserPrincipalName
            mailNickname      = $localPart
            displayName       = $user.DisplayName
        } | Out-Null
    }
    & $OnProgress (T 'BG.Created' $user.UserPrincipalName)

    $result = [pscustomobject]@{
        User                = $user
        GlobalAdminAssigned = $false
        Fido2Registered     = $false
        FakeMfaActive       = $false
        Warnings            = New-Object System.Collections.Generic.List[string]
    }

    # 3. Global Administrator
    if ($AssignGlobalAdmin) {
        & $OnProgress (T 'BG.AssigningGlobalAdmin')
        try {
            Invoke-WithRetry @retry -Description 'BG.Step.RoleAssignment' -Action {
                Invoke-M365GraphRequest -Method POST -Uri 'v1.0/roleManagement/directory/roleAssignments' -Body @{
                    principalId      = $userId
                    roleDefinitionId = $script:GlobalAdminRoleId
                    directoryScopeId = '/'
                } | Out-Null
            }
            $result.GlobalAdminAssigned = $true
            & $OnProgress (T 'BG.GlobalAdminAssigned')
        }
        catch {
            $result.Warnings.Add((T 'BG.GlobalAdminFailed' $_.Exception.Message))
        }
    }

    # 4. Fake MFA as protection until FIDO2 is registered
    & $OnProgress (T 'BG.RegisteringFake')
    $fakeToken = $null
    try {
        $fakeToken = Invoke-WithRetry @retry -Description 'BG.Step.FakeMfa' -Action { New-FakeMfaToken -User $user }
        $result.FakeMfaActive = $true
        & $OnProgress (T 'BG.FakeRegistered' $fakeToken.SerialNumber)
    }
    catch {
        $result.Warnings.Add((T 'BG.FakeFailed' $_.Exception.Message))
    }

    # 5. Register FIDO2 key, then remove fake MFA
    if (-not [string]::IsNullOrWhiteSpace($Fido2SerialNumber)) {
        try {
            # Wait until the authentication methods of the new user can be retrieved.
            Invoke-WithRetry @retry -Description 'BG.Step.Fido2Prep' -Action {
                Invoke-M365GraphRequest -Uri "beta/users/$userId/authentication/fido2Methods" | Out-Null
            }
            & $OnProgress (T 'Fido2.Prompt')
            $fido = Start-Fido2Provisioning -User $user -Options @{ SerialNumber = $Fido2SerialNumber }
            $result.Fido2Registered = $true
            & $OnProgress $fido.Message

            if ($fakeToken) {
                & $OnProgress (T 'BG.RemovingFake')
                try {
                    Remove-HardwareOathToken -User $user -Token $fakeToken
                    $result.FakeMfaActive = $false
                }
                catch {
                    $result.Warnings.Add((T 'BG.FakeRemoveFailed' $_.Exception.Message))
                }
            }
        }
        catch {
            $result.Warnings.Add((T 'BG.Fido2Failed' $_.Exception.Message))
        }
    }

    $result
}

#endregion

#region Bulk import of hardware OATH tokens

# Column names accepted in the import CSV (case-insensitive)
$script:ImportColumns = [ordered]@{
    Secret       = @('Secret', 'Base32Secret', 'SecretKey', 'Seed', 'Key')
    SerialNumber = @('SerialNumber', 'Serial', 'SN', 'Seriennummer')
    Upn          = @('UPN', 'UserPrincipalName', 'User')
    Manufacturer = @('Manufacturer', 'Hersteller')
    Model        = @('Model', 'Modell')
}
# Column names accepted for a plain user list (bulk TAP)
$script:UpnColumns = @('UPN', 'UserPrincipalName', 'User', 'Mail', 'E-Mail', 'Email')

function Get-TotpImportSample {
    <#
    .SYNOPSIS
        Returns the lines of a sample import CSV with random secrets of the usual length for the algorithm.
        The last line has no UPN: such tokens are only added to the inventory.
    #>
    param(
        [ValidateSet('hmacsha1', 'hmacsha256')][string]$HashFunction = 'hmacsha1',
        [string]$Domain = 'contoso.com'
    )
    $byteLength = if ($HashFunction -eq 'hmacsha256') { 32 } else { 20 }
    'Secret;SerialNumber;UPN'
    foreach ($i in 1..3) {
        $upn = if ($i -lt 3) { "user$i@$Domain" } else { '' }
        '{0};SN{1:D7};{2}' -f (New-TotpSecret -ByteLength $byteLength), (1000000 + $i), $upn
    }
}

function Read-CsvLines {
    # Non-empty lines of a CSV without Excel's "sep=" line, plus the detected delimiter.
    param([Parameter(Mandatory)][string]$Path)
    $lines = @(Get-Content -LiteralPath $Path -Encoding UTF8 | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($lines.Count -and $lines[0] -match '^\s*sep=') { $lines = @($lines | Select-Object -Skip 1) }
    $delimiter = if (-not $lines.Count -or $lines[0].Split(';').Count -ge $lines[0].Split(',').Count) { ';' } else { ',' }
    [pscustomobject]@{ Lines = $lines; Delimiter = $delimiter }
}

function Read-TotpImportFile {
    <#
    .SYNOPSIS
        Reads the import CSV (separator ; or , detected automatically, "sep=" line of Excel ignored).
    .OUTPUTS
        One object per data line: Line, Upn (may be empty), SerialNumber, Secret, Manufacturer, Model.
    #>
    param([Parameter(Mandatory)][string]$Path)

    $csv = Read-CsvLines -Path $Path
    $lines = $csv.Lines
    if ($lines.Count -lt 2) { throw (T 'Import.EmptyFile') }
    $delimiter = $csv.Delimiter
    $headers = @($lines[0].Split($delimiter) | ForEach-Object { $_.Trim().Trim('"').Trim() })

    # Internal name -> CSV header
    $map = @{}
    foreach ($name in $script:ImportColumns.Keys) {
        $header = $headers | Where-Object { $script:ImportColumns[$name] -contains $_ } | Select-Object -First 1
        if ($header) { $map[$name] = $header }
    }
    $missing = @('Secret', 'SerialNumber' | Where-Object { -not $map.ContainsKey($_) })
    if ($missing.Count) { throw (T 'Import.MissingColumns' ($missing -join ', ') ($headers -join $delimiter)) }

    $lineNumber = 1
    foreach ($record in @($lines | ConvertFrom-Csv -Delimiter $delimiter)) {
        $lineNumber++
        $values = @{}
        foreach ($name in $script:ImportColumns.Keys) {
            $values[$name] = if ($map.ContainsKey($name)) { ([string]$record.($map[$name])).Trim() } else { '' }
        }
        [pscustomobject]@{
            Line         = $lineNumber
            Upn          = $values.Upn
            SerialNumber = $values.SerialNumber
            Secret       = $values.Secret
            Manufacturer = $values.Manufacturer
            Model        = $values.Model
        }
    }
}

function Read-UpnListFile {
    <#
    .SYNOPSIS
        Reads a user list: a CSV with a UPN column (UPN, UserPrincipalName, User, Mail) or one UPN per line.
    .OUTPUTS
        One object per user: Line, Upn.
    #>
    param([Parameter(Mandatory)][string]$Path)

    $csv = Read-CsvLines -Path $Path
    $lines = $csv.Lines
    if (-not $lines.Count) { throw (T 'Import.EmptyFile') }
    $delimiter = $csv.Delimiter
    $headers = @($lines[0].Split($delimiter) | ForEach-Object { $_.Trim().Trim('"').Trim() })
    $header = $headers | Where-Object { $script:UpnColumns -contains $_ } | Select-Object -First 1

    if ($header) {
        $lineNumber = 1
        foreach ($record in @($lines | ConvertFrom-Csv -Delimiter $delimiter)) {
            $lineNumber++
            $upn = ([string]$record.$header).Trim()
            if ($upn) { [pscustomobject]@{ Line = $lineNumber; Upn = $upn } }
        }
    }
    else {
        # No header: the first column of every line is the UPN
        $lineNumber = 0
        foreach ($line in $lines) {
            $lineNumber++
            $upn = $line.Split($delimiter)[0].Trim().Trim('"').Trim()
            if ($upn) { [pscustomobject]@{ Line = $lineNumber; Upn = $upn } }
        }
    }
}

function Get-HardwareOathDeviceMap {
    # All hardware OATH devices of the tenant: serial number -> device
    $devices = @{}
    $uri = 'beta/directory/authenticationMethodDevices/hardwareOathDevices'
    while ($uri) {
        $response = Invoke-M365GraphRequest -Uri $uri
        foreach ($device in @($response['value'])) {
            if ($null -ne $device) { $devices[[string]$device['serialNumber']] = $device }
        }
        $uri = [string]$response['@odata.nextLink']
    }
    $devices
}

function Resolve-M365UsersByUpn {
    <#
    .SYNOPSIS
        Looks up users by UPN (or object ID) in Graph batches of 20.
    .OUTPUTS
        Hashtable UPN -> user object, or $null if the user was not found.
    #>
    param(
        [string[]]$Upns = @(),
        [scriptblock]$Wait = { param($Milliseconds) Start-Sleep -Milliseconds $Milliseconds }
    )

    $users = @{}
    $unique = @($Upns | Where-Object { $_ } | Select-Object -Unique)
    for ($offset = 0; $offset -lt $unique.Count; $offset += 20) {
        $chunk = @($unique[$offset..([Math]::Min($offset + 20, $unique.Count) - 1)])
        # The batch is keyed by what is put into the URL: the escaped UPN
        $escaped = @{}
        foreach ($upn in $chunk) { $escaped[[uri]::EscapeDataString($upn)] = $upn }
        $responses = Invoke-M365UserBatch -UserIds @($escaped.Keys) -Path '/users/{0}?$select=id,displayName,userPrincipalName,mail,accountEnabled' -Wait $Wait
        foreach ($key in $responses.Keys) {
            $response = $responses[$key]
            $users[$escaped[$key]] = if ($response.Error) { $null } else {
                [pscustomobject]@{
                    Id                = [string]$response.Body['id']
                    DisplayName       = [string]$response.Body['displayName']
                    UserPrincipalName = [string]$response.Body['userPrincipalName']
                    Mail              = [string]$response.Body['mail']
                    AccountEnabled    = [bool]$response.Body['accountEnabled']
                }
            }
        }
    }
    $users
}

function Test-TotpImport {
    <#
    .SYNOPSIS
        Test import: checks every line without changing anything in the tenant.
    .DESCRIPTION
        Checks the secret (Base32, length), duplicate serial numbers in the file, whether the user exists
        and whether a token with the serial number already exists in the tenant. Lines without UPN are
        valid: the token is only added to the inventory.
    .OUTPUTS
        One result per line with Status OK, Warning or Error. Lines with OK or Warning are
        imported by Invoke-TotpImport.
    #>
    param(
        [Parameter(Mandatory)][object[]]$Rows,
        [ValidateSet('hmacsha1', 'hmacsha256')][string]$HashFunction = 'hmacsha1',
        [scriptblock]$OnProgress = { param($Done, $Total) },
        [scriptblock]$ShouldCancel = { $false },
        [scriptblock]$Wait = { param($Milliseconds) Start-Sleep -Milliseconds $Milliseconds }
    )

    $devices = Get-HardwareOathDeviceMap
    $users = Resolve-M365UsersByUpn -Upns @($Rows | ForEach-Object { $_.Upn }) -Wait $Wait
    $serialCount = @{}
    $upnCount = @{}
    foreach ($row in $Rows) {
        if ($row.SerialNumber) { $serialCount[$row.SerialNumber] = 1 + [int]$serialCount[$row.SerialNumber] }
        if ($row.Upn) { $upnCount[$row.Upn] = 1 + [int]$upnCount[$row.Upn] }
    }
    # Usual seed length (Base32 characters): 160 bits for SHA-1, 256 bits for SHA-256
    $expectedLength = if ($HashFunction -eq 'hmacsha256') { 52 } else { 32 }
    $done = 0

    foreach ($row in $Rows) {
        if (& $ShouldCancel) { break }
        $errors = New-Object System.Collections.Generic.List[string]
        $warnings = New-Object System.Collections.Generic.List[string]
        $notes = New-Object System.Collections.Generic.List[string]
        $user = $null
        $secret = $null

        if (-not $row.SerialNumber) { $errors.Add((T 'Import.Error.NoSerial')) }
        elseif ($serialCount[$row.SerialNumber] -gt 1) { $errors.Add((T 'Import.Error.DuplicateSerial')) }

        if (-not $row.Secret) { $errors.Add((T 'Import.Error.NoSecret')) }
        else {
            try {
                $secret = ConvertTo-NormalizedTotpSecret -Secret $row.Secret
                if ($secret.Length -gt 128) { throw (T 'Import.Error.SecretTooLong') }
                if ($secret.Length -lt $expectedLength) { $warnings.Add((T 'Import.Warn.ShortSecret' $secret.Length $expectedLength)) }
            }
            catch {
                $secret = $null
                $errors.Add($_.Exception.Message)
            }
        }

        if ($row.Upn) {
            $user = $users[$row.Upn]
            if ($null -eq $user) { $errors.Add((T 'Import.Error.UserNotFound')) }
            elseif (-not $user.AccountEnabled) { $warnings.Add((T 'Import.Warn.UserDisabled')) }
            if ($upnCount[$row.Upn] -gt 1) { $warnings.Add((T 'Import.Warn.SeveralTokens' $upnCount[$row.Upn])) }
        }
        else {
            $notes.Add((T 'Import.Note.InventoryOnly'))
        }

        if ($row.SerialNumber -and $devices.ContainsKey($row.SerialNumber)) {
            $assignedTo = $devices[$row.SerialNumber]['assignedTo']
            if ($assignedTo -is [System.Collections.IDictionary] -and $assignedTo['id']) {
                $errors.Add((T 'Totp.AlreadyAssigned' $row.SerialNumber $assignedTo['displayName']))
            }
            else {
                $warnings.Add((T 'Import.Warn.ReplaceDevice'))
            }
        }

        $status = if ($errors.Count) { 'Error' } elseif ($warnings.Count) { 'Warning' } else { 'OK' }
        [pscustomobject]@{
            Line         = $row.Line
            Upn          = $row.Upn
            DisplayName  = if ($user) { $user.DisplayName } else { '' }
            SerialNumber = $row.SerialNumber
            Status       = $status
            StatusText   = T "Import.Status.$status"
            Message      = (@($errors) + @($warnings) + @($notes)) -join ' · '
            User         = $user
            Secret       = $secret
            Manufacturer = if ($row.Manufacturer) { $row.Manufacturer } else { 'OATH' }
            Model        = $row.Model
            MethodId     = $null   # set by Invoke-TotpImport, used by Undo-TotpImport
            DeviceId     = $null
        }
        $done++
        & $OnProgress $done $Rows.Count
    }
}

function Invoke-TotpImport {
    <#
    .SYNOPSIS
        Imports the lines of a test import with status OK or Warning: creates, assigns and activates each token.
    .DESCRIPTION
        Lines without user only create the device in the inventory. An error does not stop the import:
        the token is rolled back and marked as failed. When Graph throttles, the token is tried again
        after a pause. Updates Status, StatusText, Message, MethodId and DeviceId of the passed results
        and removes their secrets.
    #>
    param(
        [Parameter(Mandatory)][object[]]$Results,
        [ValidateSet('hmacsha1', 'hmacsha256')][string]$HashFunction = 'hmacsha1',
        [ValidateSet(30, 60)][int]$TimeIntervalInSeconds = 30,
        [scriptblock]$OnProgress = { param($Result, $Done, $Total) },
        [scriptblock]$ShouldCancel = { $false },
        [scriptblock]$Wait = { param($Milliseconds) Start-Sleep -Milliseconds $Milliseconds }
    )

    $devices = Get-HardwareOathDeviceMap
    $pending = @($Results | Where-Object { $_.Status -in 'OK', 'Warning' })
    $algorithm = if ($HashFunction -eq 'hmacsha256') { 'SHA-256' } else { 'SHA-1' }
    $done = 0
    foreach ($result in $pending) {
        if (& $ShouldCancel) { break }
        $model = if ($result.Model) { $result.Model } else { 'TOTP {0} {1}s' -f $algorithm, $TimeIntervalInSeconds }
        for ($attempt = 1; ; $attempt++) {
            try {
                # A failed attempt may have replaced or rolled back the device: retries look it up again.
                $deviceMap = if ($attempt -eq 1) { $devices } else { $null }
                $token = New-HardwareOathTotp -User $result.User -SerialNumber $result.SerialNumber -SecretKey $result.Secret `
                    -DisplayName "TOTP token $($result.SerialNumber)" -Model $model -Manufacturer $result.Manufacturer `
                    -HashFunction $HashFunction -TimeIntervalInSeconds $TimeIntervalInSeconds -Devices $deviceMap `
                    -InventoryOnly:($null -eq $result.User)
                $result.MethodId = $token.MethodId
                $result.DeviceId = $token.DeviceId
                $result.Status = 'Imported'
                $result.Message = if ($result.User) { '' } else { T 'Import.Note.InventoryOnly' }
                break
            }
            catch {
                if ($attempt -lt 4 -and $_.Exception.Message -match '429|TooManyRequests|activityLimitReached|throttl|503|ServiceUnavailable') {
                    & $Wait (10000 * $attempt)
                    continue
                }
                $result.Status = 'Failed'
                $result.Message = $_.Exception.Message
                break
            }
        }
        $result.StatusText = T "Import.Status.$($result.Status)"
        $result.Secret = $null
        $done++
        & $OnProgress $result $done $pending.Count
    }
}

function Undo-TotpImport {
    <#
    .SYNOPSIS
        Removes the tokens created by the last import (status Imported) from the users and the inventory.
    #>
    param(
        [Parameter(Mandatory)][object[]]$Results,
        [scriptblock]$OnProgress = { param($Result, $Done, $Total) },
        [scriptblock]$ShouldCancel = { $false }
    )

    $pending = @($Results | Where-Object { $_.Status -eq 'Imported' -and $_.DeviceId })
    $done = 0
    foreach ($result in $pending) {
        if (& $ShouldCancel) { break }
        try {
            if ($result.MethodId -and $result.User) {
                Invoke-M365GraphRequest -Method DELETE -Uri "beta/users/$([uri]::EscapeDataString($result.User.Id))/authentication/hardwareOathMethods/$([uri]::EscapeDataString($result.MethodId))" | Out-Null
            }
            Invoke-M365GraphRequest -Method DELETE -Uri "beta/directory/authenticationMethodDevices/hardwareOathDevices/$([uri]::EscapeDataString($result.DeviceId))" | Out-Null
            $result.Status = 'Reverted'
            $result.Message = ''
            $result.MethodId = $null
            $result.DeviceId = $null
        }
        catch {
            $result.Status = 'UndoFailed'
            $result.Message = $_.Exception.Message
        }
        $result.StatusText = T "Import.Status.$($result.Status)"
        $done++
        & $OnProgress $result $done $pending.Count
    }
}

# Excel row color per result status (bulk import and bulk TAP)
$script:BulkStatusStyles = @{
    OK = 'Default'; Warning = 'Yellow'; Error = 'Red'; Imported = 'Green'; Created = 'Green'
    Failed = 'Red'; Reverted = 'Unknown'; UndoFailed = 'Red'
}

function Export-BulkResultXlsx {
    <#
    .SYNOPSIS
        Writes a result list (bulk import or bulk TAP) as Excel: colored list plus a summary sheet.
    .PARAMETER Columns
        @{ Key = text key; Width; Property }
    .PARAMETER Summary
        Label/value pairs for the summary sheet, e.g. @(@('Tenant', 'Contoso'), ...).
    #>
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][object[]]$Rows,
        [Parameter(Mandatory)][object[]]$Columns,
        [Parameter(Mandatory)][string]$Title,
        [object[]]$Summary = @()
    )

    $listRows = New-Object System.Collections.Generic.List[object]
    $listRows.Add(@{ Style = 'Header'; Values = @($Columns | ForEach-Object { T $_.Key }) })
    foreach ($row in $Rows) {
        $style = if ($script:BulkStatusStyles.ContainsKey([string]$row.Status)) { $script:BulkStatusStyles[[string]$row.Status] } else { 'Default' }
        $listRows.Add(@{ Style = $style; Values = @($Columns | ForEach-Object { $row.($_.Property) }) })
    }
    $filterRef = 'A1:{0}{1}' -f (ConvertTo-XlsxColumnName $Columns.Count), $listRows.Count

    $summaryRows = New-Object System.Collections.Generic.List[object]
    $summaryRows.Add(@{ Style = 'Bold'; Values = @($Title) })
    $summaryRows.Add(@{ Values = @((T 'Report.Summary.Created'), (Get-Date)) })
    foreach ($pair in $Summary) { $summaryRows.Add(@{ Values = @($pair) }) }
    $summaryRows.Add(@{ Values = @() })
    $summaryRows.Add(@{ Style = 'Header'; Values = @((T 'Import.Col.Status'), (T 'Report.Summary.Count')) })
    foreach ($status in @($Rows | ForEach-Object { [string]$_.Status } | Select-Object -Unique)) {
        $count = @($Rows | Where-Object { [string]$_.Status -eq $status }).Count
        $style = if ($script:BulkStatusStyles.ContainsKey($status)) { $script:BulkStatusStyles[$status] } else { 'Default' }
        $summaryRows.Add(@{ Style = $style; Values = @((T "Import.Status.$status"), $count) })
    }
    $summaryRows.Add(@{ Style = 'Bold'; Values = @((T 'Report.Summary.Total'), $Rows.Count) })

    Save-XlsxWorkbook -Path $Path -Sheets @(
        @{ Name = T 'Report.Sheet.List'; FilterRef = $filterRef
           Xml = New-XlsxSheetXml -Widths @($Columns | ForEach-Object { $_.Width }) -Rows $listRows.ToArray() -HeaderRow }
        @{ Name = T 'Report.Sheet.Summary'
           Xml = New-XlsxSheetXml -Widths 30, 60 -Rows $summaryRows.ToArray() }
    )
}

function Export-TotpImportXlsx {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][object[]]$Rows,
        [string]$Tenant,
        [string]$FileName,
        [string]$Settings
    )
    Export-BulkResultXlsx -Path $Path -Rows $Rows -Title (T 'Import.Title') -Columns @(
        @{ Key = 'Import.Col.Line';    Width = 8;  Property = 'Line' }
        @{ Key = 'Import.Col.Status';  Width = 14; Property = 'StatusText' }
        @{ Key = 'Import.Col.Upn';     Width = 38; Property = 'Upn' }
        @{ Key = 'Import.Col.Name';    Width = 28; Property = 'DisplayName' }
        @{ Key = 'Import.Col.Serial';  Width = 18; Property = 'SerialNumber' }
        @{ Key = 'Import.Col.Message'; Width = 80; Property = 'Message' }
    ) -Summary @(
        , @((T 'Report.Summary.Tenant'), $Tenant)
        , @((T 'Import.Summary.File'), $FileName)
        , @((T 'Import.Summary.Settings'), $Settings)
    )
}

#endregion

#region Token inventory

function Get-M365HardwareOathDevices {
    <#
    .SYNOPSIS
        Returns all hardware OATH tokens of the tenant for the inventory view.
    #>
    $uri = 'beta/directory/authenticationMethodDevices/hardwareOathDevices'
    while ($uri) {
        $response = Invoke-M365GraphRequest -Uri $uri
        foreach ($device in @($response['value'])) {
            if ($null -eq $device) { continue }
            $assignedTo = $device['assignedTo']
            $assignedId = if ($assignedTo -is [System.Collections.IDictionary]) { [string]$assignedTo['id'] } else { '' }
            $assignedName = if ($assignedTo -is [System.Collections.IDictionary]) { [string]$assignedTo['displayName'] } else { '' }
            $status = [string]$device['status']
            $hash = [string]$device['hashFunction']
            [pscustomobject]@{
                Id             = [string]$device['id']
                SerialNumber   = [string]$device['serialNumber']
                DisplayName    = [string]$device['displayName']
                Manufacturer   = [string]$device['manufacturer']
                Model          = [string]$device['model']
                Algorithm      = if ($hash -eq 'hmacsha256') { 'SHA-256' } elseif ($hash -eq 'hmacsha1') { 'SHA-1' } else { $hash }
                TimeInterval   = [int]$device['timeIntervalInSeconds']
                Status         = $status
                StatusText     = if (Test-UiText "Inventory.Status.$status") { T "Inventory.Status.$status" } else { $status }
                IsAssigned     = [bool]$assignedId
                AssignedToId   = $assignedId
                AssignedToName = $assignedName
                SearchText     = @($device['serialNumber'], $device['displayName'], $device['manufacturer'], $device['model'], $assignedName) -join ' '
            }
        }
        $uri = [string]$response['@odata.nextLink']
    }
}

function Remove-M365HardwareOathAssignment {
    # Removes the token from its user; the device stays in the inventory.
    param([Parameter(Mandatory)]$Device)
    if (-not $Device.AssignedToId) { return }
    Invoke-M365GraphRequest -Method DELETE -Uri "beta/users/$([uri]::EscapeDataString($Device.AssignedToId))/authentication/hardwareOathMethods/$([uri]::EscapeDataString($Device.Id))" | Out-Null
}

function Remove-M365HardwareOathDevice {
    # Deletes the device from the inventory (after removing it from its user, if assigned).
    param([Parameter(Mandatory)]$Device)
    Remove-M365HardwareOathAssignment -Device $Device
    Invoke-M365GraphRequest -Method DELETE -Uri "beta/directory/authenticationMethodDevices/hardwareOathDevices/$([uri]::EscapeDataString($Device.Id))" | Out-Null
}

function Set-M365HardwareOathAssignment {
    <#
    .SYNOPSIS
        Assigns an unassigned inventory token to a user and activates it with the code shown on the token.
    #>
    param(
        [Parameter(Mandatory)]$Device,
        [Parameter(Mandatory)]$User,
        [Parameter(Mandatory)][string]$VerificationCode
    )
    $userPart = [uri]::EscapeDataString($User.Id)
    $method = Invoke-M365GraphRequest -Method POST -Uri "beta/users/$userPart/authentication/hardwareOathMethods" -Body @{ device = @{ id = $Device.Id } }
    $methodId = [string]$method['id']
    if (-not $methodId) { $methodId = $Device.Id }
    try {
        Invoke-M365GraphRequest -Method POST -Uri "beta/users/$userPart/authentication/hardwareOathMethods/$([uri]::EscapeDataString($methodId))/activate" -Body @{
            verificationCode = $VerificationCode.Trim()
            displayName      = $(if ($Device.DisplayName) { $Device.DisplayName } else { "TOTP token $($Device.SerialNumber)" })
        } | Out-Null
    }
    catch {
        # Wrong code: do not leave the token assigned but inactive
        try { Invoke-M365GraphRequest -Method DELETE -Uri "beta/users/$userPart/authentication/hardwareOathMethods/$([uri]::EscapeDataString($methodId))" | Out-Null } catch { }
        throw
    }
}

#endregion

#region Bulk Temporary Access Pass

function Test-TapBulk {
    <#
    .SYNOPSIS
        Resolves the users of a list (objects with Line and Upn) without changing anything.
    .OUTPUTS
        One result per line: Status OK, Warning (account disabled) or Error (user not found).
    #>
    param(
        [Parameter(Mandatory)][object[]]$Rows,
        [scriptblock]$Wait = { param($Milliseconds) Start-Sleep -Milliseconds $Milliseconds }
    )

    $users = Resolve-M365UsersByUpn -Upns @($Rows | ForEach-Object { $_.Upn }) -Wait $Wait
    $seen = @{}
    foreach ($row in $Rows) {
        $errors = New-Object System.Collections.Generic.List[string]
        $warnings = New-Object System.Collections.Generic.List[string]
        $user = if ($row.Upn) { $users[$row.Upn] } else { $null }
        if (-not $row.Upn) { $errors.Add((T 'Import.Error.NoUpn')) }
        elseif ($null -eq $user) { $errors.Add((T 'Import.Error.UserNotFound')) }
        else {
            if (-not $user.AccountEnabled) { $warnings.Add((T 'Import.Warn.UserDisabled')) }
            if ($seen.ContainsKey($user.Id)) { $errors.Add((T 'BulkTap.Error.Duplicate')) }
            $seen[$user.Id] = $true
        }
        $status = if ($errors.Count) { 'Error' } elseif ($warnings.Count) { 'Warning' } else { 'OK' }
        [pscustomobject]@{
            Line        = $row.Line
            Upn         = $row.Upn
            DisplayName = if ($user) { $user.DisplayName } else { '' }
            Status      = $status
            StatusText  = T "Import.Status.$status"
            Message     = (@($errors) + @($warnings)) -join ' · '
            User        = $user
            Pass        = ''
            ValidFrom   = $null
            ValidUntil  = $null
            ValidText   = ''
        }
    }
}

function Invoke-TapBulk {
    <#
    .SYNOPSIS
        Creates a Temporary Access Pass for every result with status OK or Warning (an existing TAP is replaced).
    #>
    param(
        [Parameter(Mandatory)][object[]]$Results,
        [int]$LifetimeMinutes = 120,
        [switch]$UsableOnce,
        [scriptblock]$OnProgress = { param($Result, $Done, $Total) },
        [scriptblock]$ShouldCancel = { $false },
        [scriptblock]$Wait = { param($Milliseconds) Start-Sleep -Milliseconds $Milliseconds }
    )

    $pending = @($Results | Where-Object { $_.Status -in 'OK', 'Warning' })
    $done = 0
    foreach ($result in $pending) {
        if (& $ShouldCancel) { break }
        for ($attempt = 1; ; $attempt++) {
            try {
                $provisioned = Start-TemporaryAccessPassProvisioning -User $result.User -Options @{ LifetimeMinutes = $LifetimeMinutes; UsableOnce = [bool]$UsableOnce }
                $tap = $provisioned.TemporaryAccessPass
                $result.Pass = $tap.Pass
                $result.ValidFrom = $tap.ValidFrom
                $result.ValidUntil = $tap.ValidUntil
                $result.ValidText = $tap.ValidUntil.ToString((T 'Format.DateTime'))
                $result.Status = 'Created'
                $result.Message = if ($provisioned.RemovedMethodIds.Count) { T 'Prov.Tap.Replaced' } else { '' }
                break
            }
            catch {
                if ($attempt -lt 4 -and $_.Exception.Message -match '429|TooManyRequests|activityLimitReached|throttl|503|ServiceUnavailable') {
                    & $Wait (10000 * $attempt)
                    continue
                }
                $result.Status = 'Failed'
                $result.Message = $_.Exception.Message
                break
            }
        }
        $result.StatusText = T "Import.Status.$($result.Status)"
        $done++
        & $OnProgress $result $done $pending.Count
    }
}

function Export-TapBulkXlsx {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][object[]]$Rows,
        [string]$Tenant,
        [string]$Source,
        [string]$Settings
    )
    Export-BulkResultXlsx -Path $Path -Rows $Rows -Title (T 'BulkTap.Title') -Columns @(
        @{ Key = 'Import.Col.Upn';          Width = 38; Property = 'Upn' }
        @{ Key = 'Import.Col.Name';         Width = 28; Property = 'DisplayName' }
        @{ Key = 'Import.Col.Status';       Width = 14; Property = 'StatusText' }
        @{ Key = 'BulkTap.Col.Tap';         Width = 18; Property = 'Pass' }
        @{ Key = 'BulkTap.Col.ValidFrom';   Width = 18; Property = 'ValidFrom' }
        @{ Key = 'BulkTap.Col.ValidUntil';  Width = 18; Property = 'ValidUntil' }
        @{ Key = 'Import.Col.Message';      Width = 60; Property = 'Message' }
    ) -Summary @(
        , @((T 'Report.Summary.Tenant'), $Tenant)
        , @((T 'BulkTap.Summary.Source'), $Source)
        , @((T 'Import.Summary.Settings'), $Settings)
    )
}

#endregion

function Invoke-MfaProvisioning {
    <#
    .SYNOPSIS
        Sets up the selected MFA method for a user.
    .PARAMETER Options
        Additional input from the GUI: SerialNumber, Secret.
    .OUTPUTS
        Result object from New-ProvisioningResult.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('Fido2', 'FixedTotp', 'ProgrammableTotp', 'Tap', 'FakeMfa')][string]$Method,
        [Parameter(Mandatory)]$User,
        [hashtable]$Options = @{}
    )
    $params = @{ User = $User; Options = $Options }
    switch ($Method) {
        'Fido2'            { Start-Fido2Provisioning @params }
        'FixedTotp'        { Start-FixedSecretTotpProvisioning @params }
        'ProgrammableTotp' { Start-ProgrammableTotpProvisioning @params }
        'Tap'              { Start-TemporaryAccessPassProvisioning @params }
        'FakeMfa'          { Start-FakeMfaProvisioning @params }
    }
}

Export-ModuleMember -Function @(
    'Invoke-MfaProvisioning', 'New-M365BreakGlassAccount', 'ConvertFrom-HrdnrFakeMfaKey', 'Get-HrdnrFakeMfaKeyFromTenant'
    # Bulk import of hardware OATH tokens
    'Get-TotpImportSample', 'Read-TotpImportFile', 'Test-TotpImport', 'Invoke-TotpImport', 'Undo-TotpImport', 'Export-TotpImportXlsx'
    # Token inventory
    'Get-M365HardwareOathDevices', 'Set-M365HardwareOathAssignment', 'Remove-M365HardwareOathAssignment', 'Remove-M365HardwareOathDevice'
    # Bulk Temporary Access Pass
    'Read-UpnListFile', 'Test-TapBulk', 'Invoke-TapBulk', 'Export-TapBulkXlsx'
)
