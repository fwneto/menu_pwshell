#requires -Version 5.1

Set-StrictMode -Version Latest

try {
    $ansiCodePage = [System.Globalization.CultureInfo]::InstalledUICulture.TextInfo.ANSICodePage
    if ($ansiCodePage) {
        & chcp $ansiCodePage | Out-Null
        $encoding = [System.Text.Encoding]::GetEncoding($ansiCodePage)
        [Console]::OutputEncoding = $encoding
        [Console]::InputEncoding  = $encoding
    }
} catch {
    Write-Warning ("Falha ao ajustar codificaA?AGBPo do console: {0}" -f $_.Exception.Message)
}

$script:ModuleRoot = Split-Path -Parent $PSCommandPath
$script:ConfigPath = Join-Path $script:ModuleRoot 'menu.config.json'

function Get-DefaultMaintenanceConfig {
    [CmdletBinding()]
    param()

    [pscustomobject]@{
        ChocolateyPackagesDefault = @(
            '7zip'
            'googlechrome'
            'vlc'
            'git'
            'vscode'
            'python'
            'dotnetfx'
            'dotnet-8.0-runtime'
            'powertoys'
            'rufus'
            'telegram'
            'sumatrapdf'
            'notepadplusplus'
            'cpu-z'
            'gpu-z'
        )
        RobocopyOptions = @('/MIR','/Z','/R:2','/W:2','/FFT','/NP','/LOG')
    }
}

$script:MaintenanceConfig = Get-DefaultMaintenanceConfig

if (Test-Path -Path $script:ConfigPath) {
    try {
        $rawConfig = Get-Content -Path $script:ConfigPath -Raw -ErrorAction Stop
        if ($rawConfig -and $rawConfig.Trim()) {
            $parsedConfig = $rawConfig | ConvertFrom-Json -ErrorAction Stop
            if ($parsedConfig) {
                $script:MaintenanceConfig = $parsedConfig
            }
        }
    } catch {
        Write-Warning ("Falha ao interpretar {0}: {1}" -f $script:ConfigPath, $_.Exception.Message)
    }
}

$script:MW_Base   = $script:ModuleRoot
$script:MW_LogDir = Join-Path $script:MW_Base 'logs'
$script:MW_Temp   = Join-Path $script:MW_Base 'temp'

foreach ($directory in @($script:MW_Base, $script:MW_LogDir, $script:MW_Temp)) {
    if (-not (Test-Path -Path $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
}

$timestamp = Get-Date
$script:MW_Log        = Join-Path $script:MW_LogDir ("maintenance_{0:yyyyMMdd_HHmmss}.log" -f $timestamp)
$script:MW_Transcript = Join-Path $script:MW_LogDir ("transcript_{0:yyyyMMdd_HHmmss}.txt" -f $timestamp)
$script:TranscriptActive = $false

try {
    Start-Transcript -Path $script:MW_Transcript -Append -ErrorAction SilentlyContinue | Out-Null
    $script:TranscriptActive = $true
} catch {
    Write-Warning ("NAGBPo foi possA-vel iniciar o transcript: {0}" -f $_.Exception.Message)
}

try {
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force -ErrorAction SilentlyContinue
} catch {
    Write-Warning ("Falha ao ajustar ExecutionPolicy: {0}" -f $_.Exception.Message)
}

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('OK','INFO','WARN','ERR')]
        [string]$Tag,

        [Parameter(Mandatory)]
        [string]$Message
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $entry = "{0} [{1}] {2}" -f $timestamp, $Tag, $Message

    try {
        Add-Content -Path $script:MW_Log -Value $entry -ErrorAction Stop -Encoding UTF8
    } catch {
        Write-Warning ("Falha ao gravar no log {0}: {1}" -f $script:MW_Log, $_.Exception.Message)
    }
}

function Write-Ok {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Message)

    Write-Log -Tag 'OK' -Message $Message
    Write-Host "[OK]  $Message" -ForegroundColor Green
}

function Write-Info {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Message)

    Write-Log -Tag 'INFO' -Message $Message
    Write-Host "[..]  $Message" -ForegroundColor Cyan
}

function Write-Warn {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Message)

    Write-Log -Tag 'WARN' -Message $Message
    Write-Host "[!]  $Message" -ForegroundColor Yellow
}

function Write-Err {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Message)

    Write-Log -Tag 'ERR' -Message $Message
    Write-Host "[X]  $Message" -ForegroundColor Red
}

function Pause-Enter {
    [CmdletBinding()]
    param()

    Write-Host ''
    Read-Host 'Pressione ENTER para continuar' | Out-Null
}

function Stop-MaintenanceTranscript {
    [CmdletBinding()]
    param()

    if ($script:TranscriptActive) {
        try {
            Stop-Transcript | Out-Null
        } catch {
            Write-Warning ("Falha ao encerrar transcript: {0}" -f $_.Exception.Message)
        } finally {
            $script:TranscriptActive = $false
        }
    }
}

function Test-IsAdministrator {
    [CmdletBinding()]
    param()

    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
    } catch {
        Write-Warning ("Falha ao verificar privilA(C)gios administrativos: {0}" -f $_.Exception.Message)
        return $false
    }
}

function Ensure-Winget {
    [CmdletBinding()]
    param()

    try {
        winget --version *>$null
        return $true
    } catch {
        Write-Err 'Winget nAGBPo encontrado. Instale o App Installer pela Microsoft Store.'
        return $false
    }
}

function Ensure-Choco {
    [CmdletBinding()]
    param()

    try {
        choco -v *>$null
        return $true
    } catch {
        Write-Warn 'Chocolatey nAGBPo encontrado. Tentando instalar...'
        try {
            Set-ExecutionPolicy Bypass -Scope Process -Force
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
            Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
            choco -v *>$null
            Write-Ok 'Chocolatey instalado.'
            return $true
        } catch {
            Write-Err ("Falha ao instalar Chocolatey: {0}" -f $_.Exception.Message)
            return $false
        }
    }
}

function Get-MaintenanceConfigValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Key
    )

    if ($null -ne $script:MaintenanceConfig.$Key) {
        return $script:MaintenanceConfig.$Key
    }

    $defaults = Get-DefaultMaintenanceConfig
    return $defaults.$Key
}

function Acao-1-VerificarWindowsUpdates {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param()

    Write-Info 'Verificando atualizaA?Aues do Windows...'
    if (-not $PSCmdlet.ShouldProcess('Windows Update', 'Listar atualizaA?Aues disponA-veis')) {
        Pause-Enter
        return
    }

    try {
        Get-WindowsUpdate -AcceptAll -IgnoreReboot -WhatIf
    } catch {
        Write-Warn 'MA3dulo PSWindowsUpdate nAGBPo encontrado. Instalando...'
        try {
            Install-PackageProvider -Name NuGet -Force -Scope CurrentUser -ErrorAction SilentlyContinue | Out-Null
            Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted -ErrorAction SilentlyContinue
            Install-Module PSWindowsUpdate -Force -Scope AllUsers
            Import-Module PSWindowsUpdate
            Get-WindowsUpdate -AcceptAll -IgnoreReboot -WhatIf
        } catch {
            Write-Err ("Erro ao preparar/verificar Windows Update: {0}" -f $_.Exception.Message)
        }
    }
    Pause-Enter
}

function Acao-2-InstalarWindowsUpdates {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param()

    Write-Info 'Instalando atualizaA?Aues do Windows...'
    if (-not $PSCmdlet.ShouldProcess('Windows Update', 'Instalar atualizaA?Aues pendentes')) {
        Pause-Enter
        return
    }

    try {
        Get-WindowsUpdate -AcceptAll -IgnoreReboot -Install
    } catch {
        Write-Warn 'MA3dulo PSWindowsUpdate nAGBPo encontrado. Instalando...'
        try {
            Install-PackageProvider -Name NuGet -Force -Scope CurrentUser -ErrorAction SilentlyContinue | Out-Null
            Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted -ErrorAction SilentlyContinue
            Install-Module PSWindowsUpdate -Force -Scope AllUsers
            Import-Module PSWindowsUpdate
            Get-WindowsUpdate -AcceptAll -IgnoreReboot -Install
        } catch {
            Write-Err ("Erro ao instalar atualizaA?Aues: {0}" -f $_.Exception.Message)
        }
    }
    Pause-Enter
}

function Acao-3-WingetUpgrade {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param()

    if (-not (Ensure-Winget)) { Pause-Enter; return }
    if (-not $PSCmdlet.ShouldProcess('Winget', 'Atualizar todos os aplicativos disponA-veis')) {
        Pause-Enter
        return
    }

    Write-Info 'Atualizando todos os aplicativos via winget...'
    try {
        winget upgrade --all --silent --accept-source-agreements --accept-package-agreements
        Write-Ok 'AtualizaA?AGBPo concluA-da (winget).'
    } catch {
        Write-Err ("Falha no winget upgrade: {0}" -f $_.Exception.Message)
    }
    Pause-Enter
}

function Acao-4-WingetUninstall {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param()

    if (-not (Ensure-Winget)) { Pause-Enter; return }
    Write-Info 'Listando pacotes winget instalados...'
    try {
        $rawJson = winget list --accept-source-agreements --output json | Out-String
        if (-not $rawJson.Trim()) {
            Write-Warn 'Nenhum app encontrado.'
            Pause-Enter
            return
        }

        try {
            $parsed = $rawJson | ConvertFrom-Json
        } catch {
            Write-Err 'NAGBPo foi possA-vel interpretar a saA-da do winget.'
            Pause-Enter
            return
        }

        $packages = @()
        if ($parsed.Sources) {
            foreach ($src in $parsed.Sources) {
                if ($src.Packages) { $packages += $src.Packages }
            }
        } elseif ($parsed.Packages) {
            $packages = $parsed.Packages
        } elseif ($parsed -is [System.Collections.IEnumerable]) {
            $packages = $parsed
        }

        $normalized = @()
        foreach ($pkg in $packages) {
            $pkgId = $null
            if ($pkg.Id) { $pkgId = [string]$pkg.Id }
            elseif ($pkg.PackageIdentifier) { $pkgId = [string]$pkg.PackageIdentifier }
            elseif ($pkg.PackageId) { $pkgId = [string]$pkg.PackageId }

            $pkgName = $null
            if ($pkg.Name) { $pkgName = [string]$pkg.Name }
            elseif ($pkg.PackageName) { $pkgName = [string]$pkg.PackageName }

            $pkgVersion = $null
            if ($pkg.Version) { $pkgVersion = [string]$pkg.Version }
            elseif ($pkg.InstalledVersion) { $pkgVersion = [string]$pkg.InstalledVersion }

            if (-not $pkgId -or -not $pkgName) { continue }

            $normalized += [PSCustomObject]@{
                Id      = $pkgId
                Name    = $pkgName
                Version = $pkgVersion
                Source  = $pkg.Source
            }
        }

        if (-not $normalized) {
            Write-Warn 'Nenhum app encontrado.'
            Pause-Enter
            return
        }

        $list = @()
        $i = 1
        foreach ($pkg in ($normalized | Sort-Object Name, Id)) {
            $displayName = $pkg.Name
            if ($displayName.Length -gt 45) { $displayName = $displayName.Substring(0, 42) + '...' }
            $actualVersion = $pkg.Version
            $displayVersion = if ($actualVersion) { $actualVersion } else { '-' }
            $list += [PSCustomObject]@{
                Index          = $i
                Name           = $pkg.Name
                Version        = $actualVersion
                Id             = $pkg.Id
                Display        = $displayName
                DisplayVersion = $displayVersion
            }
            $i++
        }

        $list | ForEach-Object {
            Write-Host ("[{0,3}] {1,-45} {2,-18} {3}" -f $_.Index, $_.Display, $_.DisplayVersion, $_.Id)
        }

        $sel = Read-Host "`nDigite o(s) nAomero(s) para desinstalar (separados por espaA?o ou vA-rgula). ENTER para cancelar"
        if ([string]::IsNullOrWhiteSpace($sel)) { return }
        $idxs = $sel -split '[, ]+' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ } | Sort-Object -Unique
        if (-not $idxs) {
            Write-Warn 'Nenhuma seleA?AGBPo vA!lida.'
            Pause-Enter
            return
        }

        $targets = @()
        foreach ($idx in $idxs) {
            $obj = $list | Where-Object { $_.Index -eq $idx }
            if ($obj) {
                $targets += $obj.Id
            }
        }

        if (-not $targets) {
            Write-Warn 'Nenhum pacote correspondente encontrado.'
            Pause-Enter
            return
        }

        Write-Host "`nSelecionados para desinstalar (winget):" -ForegroundColor Yellow
        $targets | ForEach-Object { Write-Host " - $_" }

        $conf = Read-Host "`nConfirmar? [S/n]"
        if ($conf -and $conf.Trim().ToUpper() -eq 'N') {
            Write-Host 'OperaA?AGBPo cancelada.'
            Pause-Enter
            return
        }

        foreach ($id in $targets) {
            if (-not $PSCmdlet.ShouldProcess($id, 'Desinstalar via winget')) {
                continue
            }

            try {
                winget uninstall --id "$id" --exact --silent --accept-source-agreements --accept-package-agreements
                Write-Ok ("Desinstalado (winget): {0}" -f $id)
            } catch {
                Write-Err ("Falha ao desinstalar {0}: {1}" -f $id, $_.Exception.Message)
            }
        }
    } catch {
        Write-Err ("Erro no fluxo de desinstalaA?AGBPo winget: {0}" -f $_.Exception.Message)
    }
    Pause-Enter
}

function Acao-5-ChocoInstalarVerificar {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
    param()

    if (-not (Ensure-Choco)) { Pause-Enter; return }
    if (-not $PSCmdlet.ShouldProcess('Chocolatey', 'Listar pacotes desatualizados')) {
        Pause-Enter
        return
    }

    choco outdated
    Pause-Enter
}

function Acao-6-ChocoInstalarProgramas {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param()

    if (-not (Ensure-Choco)) { Pause-Enter; return }
    $lista = @(Get-MaintenanceConfigValue -Key 'ChocolateyPackagesDefault')
    if (-not $lista) {
        Write-Warn 'Nenhuma lista de pacotes padrAGBPo encontrada na configuraA?AGBPo.'
        Pause-Enter
        return
    }

    Write-Info ("Instalando via Chocolatey: {0}" -f ($lista -join ', '))

    foreach ($p in $lista) {
        if (-not $PSCmdlet.ShouldProcess($p, 'Instalar via Chocolatey')) { continue }

        try {
            choco install $p -y --no-progress
            Write-Ok ("Instalado: {0}" -f $p)
        } catch {
            Write-Err ("Falha ao instalar {0}: {1}" -f $p, $_.Exception.Message)
        }
    }
    Pause-Enter
}

function Acao-7-ChocoAtualizarTudo {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param()

    if (-not (Ensure-Choco)) { Pause-Enter; return }
    if (-not $PSCmdlet.ShouldProcess('Chocolatey', 'Atualizar todos os pacotes instalados')) {
        Pause-Enter
        return
    }

    Write-Info 'Atualizando todos os pacotes do Chocolatey...'
    try {
        choco upgrade all -y --no-progress
        Write-Ok 'AtualizaA?AGBPo concluA-da (Chocolatey).'
    } catch {
        Write-Err ("Falha ao atualizar pacotes: {0}" -f $_.Exception.Message)
    }
    Pause-Enter
}

function Acao-8-ChocoDesinstalarPacote {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param()

    if (-not (Ensure-Choco)) { Pause-Enter; return }

    try {
        $raw = choco list --local-only --limit-output 2>$null
        if (-not $raw) {
            Write-Warn 'Nenhum pacote Chocolatey instalado encontrado.'
            Pause-Enter
            return
        }

        $i = 1
        $packages = @()
        foreach ($line in $raw) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $parts = $line -split '\|', 2
            $name = $parts[0].Trim()
            $ver  = if ($parts.Count -gt 1) { $parts[1].Trim() } else { '' }
            if ($name) {
                $packages += [PSCustomObject]@{ Index = $i; Name = $name; Version = $ver }
                $i++
            }
        }

        if (-not $packages) {
            Write-Warn 'Nenhum pacote identificado na saA-da do Chocolatey.'
            Pause-Enter
            return
        }

        Write-Host "`nPacotes instalados:" -ForegroundColor Cyan
        $packages | ForEach-Object {
            $ver = if ($_.Version) { " ($($_.Version))" } else { '' }
            Write-Host ("[{0,2}] {1}{2}" -f $_.Index, $_.Name, $ver)
        }

        $sel = Read-Host "`nDigite o(s) nAomero(s) do(s) pacote(s) para desinstalar (separados por espaA?o ou vA-rgula). ENTER para cancelar"
        if ([string]::IsNullOrWhiteSpace($sel)) { return }

        $indices = $sel -split '[, ]+' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ } | Sort-Object -Unique
        if (-not $indices) {
            Write-Warn 'Nenhum nAomero vA!lido informado.'
            Pause-Enter
            return
        }

        $toUninstall = @()
        foreach ($idx in $indices) {
            $pkg = $packages | Where-Object { $_.Index -eq $idx }
            if ($pkg) { $toUninstall += $pkg.Name }
        }

        if (-not $toUninstall) {
            Write-Warn 'Nenhuma seleA?AGBPo vA!lida.'
            Pause-Enter
            return
        }

        Write-Host "`nSelecionados para desinstalar:" -ForegroundColor Yellow
        $toUninstall | ForEach-Object { Write-Host " - $_" }

        $conf = Read-Host "`nConfirmar? [S/n]"
        if ($conf -and $conf.Trim().ToUpper() -eq 'N') {
            Write-Host 'OperaA?AGBPo cancelada.'
            Pause-Enter
            return
        }

        foreach ($name in $toUninstall) {
            if (-not $PSCmdlet.ShouldProcess($name, 'Desinstalar via Chocolatey')) { continue }

            try {
                choco uninstall $name -y --remove-dependencies --no-progress
                Write-Ok ("Desinstalado: {0}" -f $name)
            } catch {
                Write-Err ("Falha ao desinstalar {0}: {1}" -f $name, $_.Exception.Message)
            }
        }
    } catch {
        Write-Err ("Erro inesperado: {0}" -f $_.Exception.Message)
    }
    Pause-Enter
}

function Acao-9-MapearDesmapearUnidade {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param()

    Write-Host "`n[1] Mapear unidade de rede"
    Write-Host "[2] Desmapear unidade de rede"
    $op = Read-Host 'Escolha'
    switch ($op) {
        '1' {
            $letra = Read-Host 'Letra da unidade (ex: Z:)'
            $path  = Read-Host 'Caminho UNC (ex: \\servidor\compartilhamento)'
            $user  = Read-Host 'UsuA!rio (ENTER para atual)'
            $pass  = if ($user) { Read-Host 'Senha' } else { $null }
            try {
                $driveName = $letra.TrimEnd(':')
                if (-not $PSCmdlet.ShouldProcess($driveName, "Mapear para $path")) { break }

                if ($user) {
                    $cred = New-Object System.Management.Automation.PSCredential($user,(ConvertTo-SecureString $pass -AsPlainText -Force))
                    New-PSDrive -Name $driveName -PSProvider FileSystem -Root $path -Persist -Credential $cred
                } else {
                    New-PSDrive -Name $driveName -PSProvider FileSystem -Root $path -Persist
                }
                Write-Ok ("Unidade {0} mapeada para {1}" -f $letra, $path)
            } catch {
                Write-Err ("Falha ao mapear: {0}" -f $_.Exception.Message)
            }
        }
        '2' {
            $letra = Read-Host 'Letra da unidade (ex: Z:)'
            try {
                $driveName = $letra.TrimEnd(':')
                if (-not $PSCmdlet.ShouldProcess($driveName, 'Desmapear unidade de rede')) { break }

                Remove-PSDrive -Name $driveName -Force
                Write-Ok ("Unidade {0} removida." -f $letra)
            } catch {
                Write-Err ("Falha ao desmapear: {0}" -f $_.Exception.Message)
            }
        }
        default { Write-Warn 'OpA?AGBPo invA!lida.' }
    }
    Pause-Enter
}

function Acao-10-LimpezaTemporarios {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param()

    Write-Info 'Limpando arquivos temporA!rios do Windows e usuA!rio...'
    $paths = @(
        $env:TEMP, $env:TMP,
        "$env:WINDIR\Temp",
        "$env:SystemRoot\SoftwareDistribution\Download"
    )

    foreach ($p in $paths) {
        if (-not (Test-Path -Path $p)) { continue }

        if (-not $PSCmdlet.ShouldProcess($p, 'Remover arquivos temporA!rios')) { continue }

        Write-Info ("Limpando: {0}" -f $p)
        try {
            Get-ChildItem -Path $p -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        } catch {
            Write-Err ("Erro ao limpar {0}: {1}" -f $p, $_.Exception.Message)
        }
    }

    Write-Ok 'Limpeza concluA-da.'
    Pause-Enter
}

function Acao-11-RemoverPerfisUsuario {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param()

    $confirm = Read-Host 'ATENA?AfO: isto remove perfis de usuA!rio (pastas em C:\Users) que nAGBPo estejam em uso. Confirmar? [s/N]'
    if ($confirm.Trim().ToUpper() -ne 'S') { return }

    try {
        Get-CimInstance -ClassName Win32_UserProfile | Where-Object { -not $_.Loaded -and -not $_.Special } | ForEach-Object {
            $p = $_.LocalPath
            if ($p -and $p -ne $env:USERPROFILE) {
                if (-not $PSCmdlet.ShouldProcess($p, 'Remover perfil de usuA!rio')) { return }
                try {
                    Remove-CimInstance -InputObject $_
                    Write-Ok ("Perfil removido: {0}" -f $p)
                } catch {
                    Write-Err ("Falha ao remover {0}: {1}" -f $p, $_.Exception.Message)
                }
            }
        }
    } catch {
        Write-Err ("Erro ao enumerar/remover perfis: {0}" -f $_.Exception.Message)
    }
    Pause-Enter
}

function Acao-12-DebloatSycnex {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param()

    Write-Info 'Executando Windows10Debloater (Sycnex)...'
    $debloat = Join-Path $script:MW_Temp 'Windows10Debloater.ps1'

    if (-not $PSCmdlet.ShouldProcess($debloat, 'Baixar e executar script de debloat')) {
        Pause-Enter
        return
    }

    try {
        Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/Sycnex/Windows10Debloater/master/Windows10Debloater.ps1' -OutFile $debloat
        powershell -ExecutionPolicy Bypass -File $debloat
        Write-Ok 'Debloat finalizado.'
    } catch {
        Write-Err ("Erro no debloat: {0}" -f $_.Exception.Message)
    }
    Pause-Enter
}

function Acao-13-BackupRobocopy {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param()

    $origem = Read-Host 'Pasta de origem'
    $dest   = Read-Host 'Pasta de destino'
    if ([string]::IsNullOrWhiteSpace($origem) -or [string]::IsNullOrWhiteSpace($dest)) { return }

    $robocopyOptions = @(Get-MaintenanceConfigValue -Key 'RobocopyOptions')
    $optionsDisplay = ($robocopyOptions -join ' ')
    $logFile = Join-Path $script:MW_LogDir ("robocopy_{0:yyyyMMdd_HHmmss}.log" -f (Get-Date))

    if (-not $PSCmdlet.ShouldProcess($dest, "Copiar de $origem para $dest ($optionsDisplay)")) {
        Pause-Enter
        return
    }

    try {
        $args = @($origem, $dest)
        foreach ($option in $robocopyOptions) {
            if ($option -match '^/LOG\+?:') {
                $args += $option
            } elseif ($option -match '^/LOG\+?$') {
                $args += ('{0}:"{1}"' -f $option, $logFile)
            } else {
                $args += $option
            }
        }

        robocopy @args
        Write-Ok ("Backup concluA-do. Log: {0}" -f $logFile)
    } catch {
        Write-Err ("Erro no robocopy: {0}" -f $_.Exception.Message)
    }
    Pause-Enter
}

function Acao-14-ExclusaoForcadaPasta {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param()

    $path = Read-Host 'Caminho da pasta para excluir (forA?ado)'
    if ([string]::IsNullOrWhiteSpace($path)) { return }

    if (-not $PSCmdlet.ShouldProcess($path, 'Excluir pasta de forma forA?ada')) {
        Pause-Enter
        return
    }

    try {
        TAKEOWN /F "$path" /R /D Y | Out-Null
        ICACLS "$path" /grant "*S-1-5-32-544:(OI)(CI)F" /T | Out-Null
        Remove-Item -LiteralPath "$path" -Recurse -Force -ErrorAction Stop
        Write-Ok ("Pasta removida: {0}" -f $path)
    } catch {
        Write-Err ("Falha ao remover: {0}" -f $_.Exception.Message)
    }
    Pause-Enter
}

function Show-MaintenanceMenu {
    [CmdletBinding()]
    param()

    Clear-Host
    Write-Host '========== MENU DE MANUTENA?AfO ==========' -ForegroundColor Magenta
    Write-Host '[ 1] Verificar atualizaA?Aues do Windows'
    Write-Host '[ 2] Instalar atualizaA?Aues do Windows'
    Write-Host '[ 3] Winget: Atualizar aplicativos'
    Write-Host '[ 4] Winget: Desinstalar aplicativos'
    Write-Host '[ 5] Chocolatey: Instalar/Verificar'
    Write-Host '[ 6] Chocolatey: Instalar programas'
    Write-Host '[ 7] Chocolatey: Atualizar tudo'
    Write-Host '[ 8] Chocolatey: Desinstalar pacote'
    Write-Host '[ 9] Mapear/Desmapear unidade de rede'
    Write-Host '[10] Limpeza de temporA!rios'
    Write-Host '[11] Remover perfis de usuA!rio'
    Write-Host '[12] Debloat do Windows (Sycnex)'
    Write-Host '[13] Backup com Robocopy'
    Write-Host '[14] ExclusAGBPo forA?ada de pasta'
    Write-Host '[ S] Sair  |  [Q] Quit  |  [0] Zero para sair'
    Write-Host '=========================================' -ForegroundColor Magenta
}

function Invoke-MaintenanceMenuLoop {
    [CmdletBinding()]
    param()

    $originalConfirmPreference = $ConfirmPreference
    try {
        $ConfirmPreference = 'None'
        do {
            Show-MaintenanceMenu
            $escolha = Read-Host 'Escolha'
            switch ($escolha.Trim().ToUpper()) {
                '1'  { Acao-1-VerificarWindowsUpdates -Confirm:$false }
                '2'  { Acao-2-InstalarWindowsUpdates -Confirm:$false }
                '3'  { Acao-3-WingetUpgrade -Confirm:$false }
                '4'  { Acao-4-WingetUninstall -Confirm:$false }
                '5'  { Acao-5-ChocoInstalarVerificar -Confirm:$false }
                '6'  { Acao-6-ChocoInstalarProgramas -Confirm:$false }
                '7'  { Acao-7-ChocoAtualizarTudo -Confirm:$false }
                '8'  { Acao-8-ChocoDesinstalarPacote -Confirm:$false }
                '9'  { Acao-9-MapearDesmapearUnidade -Confirm:$false }
                '10' { Acao-10-LimpezaTemporarios -Confirm:$false }
                '11' { Acao-11-RemoverPerfisUsuario -Confirm:$false }
                '12' { Acao-12-DebloatSycnex -Confirm:$false }
                '13' { Acao-13-BackupRobocopy -Confirm:$false }
                '14' { Acao-14-ExclusaoForcadaPasta -Confirm:$false }
                'S'  { return }
                'Q'  { return }
                '0'  { return }
                default {
                    Write-Warn 'OpA?AGBPo invA!lida.'
                    Start-Sleep -Milliseconds 900
                }
            }
        } while ($true)
    } finally {
        $ConfirmPreference = $originalConfirmPreference
    }
}

function Start-MaintenanceMenu {
    [CmdletBinding()]
    param()

    if (-not (Test-IsAdministrator)) {
        throw 'O menu de manutenA?AGBPo requer privilA(C)gios de administrador.'
    }

    try {
        Invoke-MaintenanceMenuLoop
    } finally {
        Stop-MaintenanceTranscript
    }
}

Export-ModuleMember -Function `
    'Start-MaintenanceMenu', `
    'Invoke-MaintenanceMenuLoop', `
    'Show-MaintenanceMenu', `
    'Acao-1-VerificarWindowsUpdates', `
    'Acao-2-InstalarWindowsUpdates', `
    'Acao-3-WingetUpgrade', `
    'Acao-4-WingetUninstall', `
    'Acao-5-ChocoInstalarVerificar', `
    'Acao-6-ChocoInstalarProgramas', `
    'Acao-7-ChocoAtualizarTudo', `
    'Acao-8-ChocoDesinstalarPacote', `
    'Acao-9-MapearDesmapearUnidade', `
    'Acao-10-LimpezaTemporarios', `
    'Acao-11-RemoverPerfisUsuario', `
    'Acao-12-DebloatSycnex', `
    'Acao-13-BackupRobocopy', `
    'Acao-14-ExclusaoForcadaPasta', `
    'Get-DefaultMaintenanceConfig', `
    'Get-MaintenanceConfigValue'
