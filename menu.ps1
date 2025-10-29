# Script de menu de manutencao do Windows
#requires -version 5.1
<#
.SYNOPSIS
    Menu de Manutencao do Windows - Instalador e Atualizador de Aplicativos
#>

Clear-Host

#region Configuracao basica (encoding, log, admin)

try {
    [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
    $OutputEncoding = [Console]::OutputEncoding
} catch {}

$Global:MW_Base = Join-Path $env:ProgramData 'ManutencaoWindows'
$Global:MW_LogDir = Join-Path $Global:MW_Base 'Logs'
$Global:MW_Temp  = Join-Path $Global:MW_Base 'Temp'
$Global:MW_Log   = Join-Path $Global:MW_LogDir ("log_{0:yyyyMMdd_HHmmss}.txt" -f (Get-Date))

foreach ($d in @($Global:MW_Base,$Global:MW_LogDir,$Global:MW_Temp)) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}

# Inicia transcript
try {
    Start-Transcript -Path $Global:MW_Log -Append -ErrorAction SilentlyContinue | Out-Null
} catch {}

function Write-Ok   { param([string]$m) Write-Host "[OK]  $m" -ForegroundColor Green }
function Write-Info { param([string]$m) Write-Host "[..]  $m" -ForegroundColor Cyan }
function Write-Warn { param([string]$m) Write-Host "[!]  $m" -ForegroundColor Yellow }
function Write-Err  { param([string]$m) Write-Host "[X]  $m" -ForegroundColor Red }

function Pause-Enter {
    Write-Host ""
    Read-Host "Pressione ENTER para continuar" | Out-Null
}

function Prompt-YesNo {
    param(
        [Parameter(Mandatory)][string]$Message,
        [switch]$DefaultYes
    )

    while ($true) {
        $suffix = if ($DefaultYes) { "[S/n]" } else { "[s/N]" }
        $answer = Read-Host ("{0} {1}" -f $Message, $suffix)
        if ([string]::IsNullOrWhiteSpace($answer)) {
            return [bool]$DefaultYes
        }

        switch ($answer.Trim().ToUpperInvariant()) {
            'S' { return $true }
            'Y' { return $true }
            'SIM' { return $true }
            'YES' { return $true }
            'N' { return $false }
            'NAO' { return $false }
            'NO' { return $false }
            default { Write-Warn "Resposta invalida. Informe S ou N." }
        }
    }
}

function Clear-DirectoryContents {
    param(
        [Parameter(Mandatory)][string]$Path,
        [string]$DisplayName
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    $label = if ($DisplayName) { $DisplayName } else { $Path }
    Write-Info ("Limpando: {0}" -f $label)

    try {
        Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                if ($_.PSIsContainer) {
                    Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
                } else {
                    Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
                }
            } catch {
                Write-Warn ("Nao foi possivel remover {0}: {1}" -f $_.FullName, $_.Exception.Message)
            }
        }
    } catch {
        Write-Warn ("Falha ao enumerar {0}: {1}" -f $label, $_.Exception.Message)
    }
}

# Elevacao para administrador
function Ensure-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p =  New-Object Security.Principal.WindowsPrincipal($id)
    if (-not $p.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
        Write-Warn "Este script precisa de privilegios de administrador. Pedindo elevacao..."
        $psi = New-Object System.Diagnostics.ProcessStartInfo "powershell"
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        $psi.Verb = "runas"
        try {
            [Diagnostics.Process]::Start($psi) | Out-Null
        } catch {
            Write-Err "Elevacao negada. Encerrando."
        }
        Stop-Transcript | Out-Null
        exit
    }
}

Ensure-Admin

# Relaxa apenas no escopo do processo atual
try { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force -ErrorAction SilentlyContinue } catch {}

#endregion

#region Utilitarios Winget/Choco

function Ensure-Winget {
    try {
        winget --version *>$null
        return $true
    } catch {
        Write-Err "Winget nao encontrado. Instale o App Installer pela Microsoft Store."
        return $false
    }
}

function Ensure-Choco {
    try {
        choco -v *>$null
        return $true
    } catch {
        Write-Warn "Chocolatey nao encontrado. Tentando instalar..."
        Set-ExecutionPolicy Bypass -Scope Process -Force
        try {
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
            Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
            choco -v *>$null
            Write-Ok "Chocolatey instalado."
            return $true
        } catch {
            Write-Err "Falha ao instalar Chocolatey: $($_.Exception.Message)"
            return $false
        }
    }
}

function Ensure-PSWindowsUpdate {
    try {
        Import-Module PSWindowsUpdate -ErrorAction Stop
        return $true
    } catch {
        Write-Warn "Modulo PSWindowsUpdate nao encontrado. Tentando instalar..."
        try {
            Install-PackageProvider -Name NuGet -Force -Scope CurrentUser -ErrorAction SilentlyContinue | Out-Null
        } catch {
            Write-Warn ("Falha ao preparar NuGet provider: {0}" -f $_.Exception.Message)
        }
        try {
            Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted -ErrorAction SilentlyContinue
        } catch {
            Write-Warn ("Nao foi possivel ajustar PSGallery: {0}" -f $_.Exception.Message)
        }
        $installed = $false
        try {
            Install-Module -Name PSWindowsUpdate -Force -Scope AllUsers -AllowClobber -ErrorAction Stop
            $installed = $true
        } catch {
            Write-Warn ("Falha na instalacao global de PSWindowsUpdate: {0}" -f $_.Exception.Message)
        }
        if (-not $installed) {
            try {
                Install-Module -Name PSWindowsUpdate -Force -Scope CurrentUser -AllowClobber -ErrorAction Stop
                $installed = $true
            } catch {
                Write-Err ("Falha ao instalar PSWindowsUpdate: {0}" -f $_.Exception.Message)
                return $false
            }
        }
        try {
            Import-Module PSWindowsUpdate -ErrorAction Stop
            Write-Ok "Modulo PSWindowsUpdate disponivel."
            return $true
        } catch {
            Write-Err ("Falha ao carregar PSWindowsUpdate: {0}" -f $_.Exception.Message)
            return $false
        }
    }
}

# Helper para converter a saida do winget list em objetos padronizados
function Convert-WingetListOutput {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RawText
    )

    $normalized = @()
    $trimmed = $RawText.Trim()
    if (-not $trimmed) { return $normalized }

    if ($trimmed.StartsWith('{') -or $trimmed.StartsWith('[')) {
        try {
            $parsed = $trimmed | ConvertFrom-Json -ErrorAction Stop

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

            foreach ($pkg in $packages) {
                $pkgId = $null
                if ($pkg.Id) { $pkgId = [string]$pkg.Id }
                elseif ($pkg.PackageIdentifier) { $pkgId = [string]$pkg.PackageIdentifier }
                elseif ($pkg.PackageId) { $pkgId = [string]$pkg.PackageId }

                $pkgName = $null
                if ($pkg.Name) { $pkgName = [string]$pkg.Name }
                elseif ($pkg.PackageName) { $pkgName = [string]$pkg.PackageName }

                if (-not $pkgId -or -not $pkgName) { continue }

                $pkgVersion = $null
                if ($pkg.Version) { $pkgVersion = [string]$pkg.Version }
                elseif ($pkg.InstalledVersion) { $pkgVersion = [string]$pkg.InstalledVersion }

                $pkgAvailable = $null
                if ($pkg.AvailableVersion) { $pkgAvailable = [string]$pkg.AvailableVersion }
                elseif ($pkg.Available) { $pkgAvailable = [string]$pkg.Available }

                $pkgSource = $null
                if ($pkg.Source) { $pkgSource = [string]$pkg.Source }

                $normalized += [PSCustomObject]@{
                    Name      = $pkgName
                    Id        = $pkgId
                    Version   = $pkgVersion
                    Available = $pkgAvailable
                    Source    = $pkgSource
                }
            }

            if ($normalized) { return $normalized }
        } catch {
            # Ignora erro e tenta analisar como tabela
        }
    }

    $lines = $RawText -split "`r?`n"
    if (-not $lines) { return $normalized }

    $dividerIndex = $null
    for ($i = 0; $i -lt $lines.Length; $i++) {
        if ($lines[$i] -match '^\s*-{3,}\s*$') {
            $dividerIndex = $i
            break
        }
    }

    if ($null -eq $dividerIndex) { return $normalized }

    $headerIndex = $dividerIndex - 1
    if ($headerIndex -lt 0) { return $normalized }

    $headerLine = $lines[$headerIndex]
    if ($headerLine -notmatch '(Name|Nome)\s{2,}Id') { return $normalized }

    $start = $dividerIndex + 1

    for ($j = $start; $j -lt $lines.Length; $j++) {
        $line = $lines[$j].TrimEnd()
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line -match '^\s*-{3,}\s*$') { continue }
        if ($line -match '^(Name|Nome)\s{2,}') { continue }

        $parts = $line -split '\s{2,}'
        if ($parts.Count -lt 2) { continue }

        $name = $parts[0].Trim()
        $id   = $parts[1].Trim()
        if (-not $id) { continue }

        $version   = if ($parts.Count -ge 3) { $parts[2].Trim() } else { $null }
        $available = if ($parts.Count -ge 4) { $parts[3].Trim() } else { $null }
        $source    = if ($parts.Count -ge 5) { $parts[4].Trim() } else { $null }

        $normalized += [PSCustomObject]@{
            Name      = $name
            Id        = $id
            Version   = $version
            Available = $available
            Source    = $source
        }
    }

    return $normalized
}

#endregion

#region Acoes

function Acao-1-VerificarWindowsUpdates {
    Write-Info "Verificando atualizacoes do Windows..."
    try {
        Get-WindowsUpdate -AcceptAll -IgnoreReboot -WhatIf
    } catch {
        if (Ensure-PSWindowsUpdate) {
            try {
                Get-WindowsUpdate -AcceptAll -IgnoreReboot -WhatIf
            } catch {
                Write-Err "Erro ao verificar Windows Update: $($_.Exception.Message)"
            }
        } else {
            Write-Err "Nao foi possivel garantir o modulo PSWindowsUpdate."
        }
    }
    Pause-Enter
}

function Acao-2-InstalarWindowsUpdates {
    Write-Info "Instalando atualizacoes do Windows..."
    try {
        Get-WindowsUpdate -AcceptAll -IgnoreReboot -Install
    } catch {
        if (Ensure-PSWindowsUpdate) {
            try {
                Get-WindowsUpdate -AcceptAll -IgnoreReboot -Install
            } catch {
                Write-Err "Erro ao instalar atualizacoes: $($_.Exception.Message)"
            }
        } else {
            Write-Err "Nao foi possivel garantir o modulo PSWindowsUpdate."
        }
    }
    Pause-Enter
}

function Acao-3-WingetUpgrade {
    if (-not (Ensure-Winget)) { Pause-Enter; return }
    Write-Info "Atualizando todos os aplicativos via winget..."
    try {
        Set-Variable -Name LASTEXITCODE -Value 0 -Scope Global
        winget upgrade --all --silent --accept-source-agreements --accept-package-agreements
        $exitCode = $LASTEXITCODE
        if ($exitCode -eq 0) {
            Write-Ok "Atualizacao concluida (winget)."
        } else {
            $hexCode = "0x{0:X8}" -f (([int64]$exitCode) -band 0xFFFFFFFF)
            Write-Err ("winget retornou codigo {0} ({1}). Verifique os detalhes acima." -f $exitCode, $hexCode)
        }
    } catch {
        Write-Err "Falha no winget upgrade: $($_.Exception.Message)"
    }
    Pause-Enter
}

function Acao-4-WingetUninstall {
    if (-not (Ensure-Winget)) { Pause-Enter; return }
    Write-Info "Listando pacotes winget instalados..."
    try {
        $wingetHelpMarkers = @(
            '--help',
            'Mostra a ajuda',
            'Uso:',
            'Usage:',
            'Comandos dispon',
            'Commandos dispon',
            'Comando selecionado',
            'Sintaxe'
        )
        $isWingetHelpOutput = {
            param([string]$text)
            if (-not $text) { return $false }
            foreach ($marker in $wingetHelpMarkers) {
                if ($text.IndexOf($marker, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
                    return $true
                }
            }
            return $false
        }

        $attempts = @(
            @('--accept-source-agreements','--include-unknown','--disable-interactivity'),
            @('--accept-source-agreements','--disable-interactivity'),
            @('--disable-interactivity'),
            @('--accept-source-agreements'),
            @()
        )

        $rawOutput   = $null
        $successful  = $false
        $lastSnippet = $null

        foreach ($args in $attempts) {
            try {
                $rawOutput = winget list @args 2>&1 | Out-String
            } catch {
                $rawOutput = $_.Exception.Message
            }

            if (-not $rawOutput -or -not $rawOutput.Trim()) {
                continue
            }

            $exitCode = $LASTEXITCODE
            $snippet  = $rawOutput.Substring(0, [Math]::Min(200, $rawOutput.Length)).Trim()
            $lastSnippet = $snippet
            $looksLikeHelp = & $isWingetHelpOutput $rawOutput

            if ($exitCode -eq 0 -and -not $looksLikeHelp) {
                $successful = $true
                break
            }
        }

        if (-not $successful) {
            Write-Err "Nao foi possivel obter a lista de pacotes via winget."
            if ($lastSnippet) {
                Write-Info ("Saida capturada: {0}" -f $lastSnippet)
            }
            Pause-Enter
            return
        }

        $normalized = Convert-WingetListOutput -RawText $rawOutput
        $normalized = $normalized | Where-Object {
            $_.Id -and $_.Name -and
            $_.Id -notmatch '^[\-/]' -and
            $_.Name -notmatch 'Mostra a ajuda' -and
            $_.Name -ne '-'
        }
        if (-not $normalized) {
            if ($rawOutput -match 'Nenhum.*pacote' -or $rawOutput -match 'No (installed )?packages? (were )?found') {
                Write-Info "Nenhum pacote instalado foi encontrado pelo winget."
            } else {
                Write-Err "Nao foi possivel interpretar a lista retornada pelo winget."
                Write-Info "Verifique se a versao do winget suporta os parametros utilizados."
            }
            Pause-Enter; return
        }

        $list = @()
        $i = 1
        foreach ($pkg in ($normalized | Sort-Object Name, Id)) {
            $displayName = $pkg.Name
            if ($displayName.Length -gt 45) { $displayName = $displayName.Substring(0, 42) + '...' }
            $actualVersion = $pkg.Version
            $displayVersion = if ($actualVersion) { $actualVersion } else { '-' }
            $list += [PSCustomObject]@{
                Index   = $i
                Name    = $pkg.Name
                Version = $actualVersion
                Id      = $pkg.Id
                Display = $displayName
                DisplayVersion = $displayVersion
            }
            $i++
        }

        $list | ForEach-Object {
            Write-Host ("[{0,3}] {1,-45} {2,-18} {3}" -f $_.Index, $_.Display, $_.DisplayVersion, $_.Id)
        }

        $sel = Read-Host "`nDigite o(s) numero(s) para desinstalar (separados por espaco ou virgula). ENTER para cancelar"
        if ([string]::IsNullOrWhiteSpace($sel)) { return }
        $idxs = $sel -split '[, ]+' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ } | Sort-Object -Unique
        if (-not $idxs) { Write-Warn "Nenhuma selecao valida."; Pause-Enter; return }

        $targets = @()
        foreach ($idx in $idxs) {
            $obj = $list | Where-Object { $_.Index -eq $idx }
            if ($obj) {
                $targets += $obj.Id
            }
        }

        if (-not $targets) { Write-Warn "Nenhum pacote correspondente encontrado."; Pause-Enter; return }

        Write-Host "`nSelecionados para desinstalar (winget):" -ForegroundColor Yellow
        $targets | ForEach-Object { Write-Host " - $_" }

        $conf = Read-Host "`nConfirmar? [S/n]"
        if ($conf -and $conf.Trim().ToUpper() -eq 'N') { Write-Host "Operacao cancelada."; Pause-Enter; return }

        foreach ($id in $targets) {
            try {
                $uninstallAttempts = @(
                    @('--id', $id, '--exact', '--silent', '--accept-source-agreements', '--accept-package-agreements'),
                    @('--id', $id, '--exact', '--silent', '--accept-source-agreements'),
                    @('--id', $id, '--exact', '--silent'),
                    @('--id', $id, '--exact'),
                    @('--id', $id, '--exact', '--interactive')
                )

                $interactiveIndex = -1
                for ($idx = 0; $idx -lt $uninstallAttempts.Count; $idx++) {
                    if ($uninstallAttempts[$idx] -contains '--interactive') {
                        $interactiveIndex = $idx
                        break
                    }
                }

                $removed    = $false
                $lastOutput = $null
                $lastExit   = $null
                $attemptIndex = 0

                while ($attemptIndex -lt $uninstallAttempts.Count) {
                    $args = $uninstallAttempts[$attemptIndex]
                    try {
                        $lastOutput = winget uninstall @args 2>&1 | Out-String
                    } catch {
                        $lastOutput = $_.Exception.Message
                    }

                    $lastExit = $LASTEXITCODE
                    $looksLikeHelp = & $isWingetHelpOutput $lastOutput

                    if ($lastExit -eq 0 -and -not $looksLikeHelp) {
                        $removed = $true
                        break
                    }

                    $argumentError = $lastOutput -match 'argumento n.o foi reconhecido' -or $lastOutput -match 'argument name was not recognized'
                    if ($argumentError) {
                        # Tenta sem o argumento desconhecido
                        $attemptIndex++
                        continue
                    }

                    $lastExitUInt = $null
                    if ($null -ne $lastExit) {
                        $lastExitUInt = ([int64]$lastExit) -band 0xFFFFFFFF
                    }

                    $isCancelled = ($lastExit -eq 1223 -or $lastExitUInt -eq 0x800704C7)
                    if ($isCancelled -and $interactiveIndex -ge 0 -and $attemptIndex -lt $interactiveIndex) {
                        $attemptIndex = $interactiveIndex
                        continue
                    }

                    # Para demais retornos, avanca para o conjunto seguinte de argumentos
                    $attemptIndex++
                    continue
                }

                if ($removed) {
                    Write-Ok "Desinstalado (winget): $id"
                } else {
                    $details = @()
                    if ($null -ne $lastExit) {
                        $hex = "0x{0:X8}" -f (([int64]$lastExit) -band 0xFFFFFFFF)
                        $details += ("winget retornou codigo {0} ({1})" -f $lastExit, $hex)
                    }
                    if ($lastOutput) {
                        $cleanLines = $lastOutput -split "`r?`n" | ForEach-Object { $_.TrimEnd() } | Where-Object {
                            $trim = $_.Trim()
                            if (-not $trim) { return $false }
                            return $trim -notin '-', '\', '|', '/'
                        }
                        if ($cleanLines) {
                            $details += ($cleanLines -join "`n")
                        }
                    }
                    if (-not $details) {
                        $details = @("winget nao forneceu detalhes adicionais.")
                    }
                    Write-Err ("Falha ao desinstalar {0}. Ultima tentativa retornou:`n{1}" -f $id, ($details -join "`n"))
                    $lastExitUInt = $null
                    if ($null -ne $lastExit) {
                        $lastExitUInt = ([int64]$lastExit) -band 0xFFFFFFFF
                    }
                    if ($lastExit -eq 1223 -or ($lastExitUInt -eq 0x800704C7)) {
                        Write-Warn "O desinstalador abortou a operacao (ERROR_CANCELLED). Execute novamente esta opcao e responda aos prompts do desinstalador ou utilize o aplicativo original para remover o pacote."
                    }
                }
            } catch {
                Write-Err "Falha ao desinstalar ${id}: $($_.Exception.Message)"
            }
        }
    } catch {
        Write-Err "Erro no fluxo de desinstalacao winget: $($_.Exception.Message)"
    }
    Pause-Enter
}

function Acao-5-ChocoInstalarVerificar {
    if (-not (Ensure-Choco)) { Pause-Enter; return }
    choco outdated
    Pause-Enter
}

function Acao-6-ChocoInstalarProgramas {
    if (-not (Ensure-Choco)) { Pause-Enter; return }
    $pacotesDesejados = @(
        '7zip'
        'googlechrome'
        'vlc'
        'dotnetfx'
        'dotnet-8.0-runtime'
        'powertoys'
        'notepadplusplus'
        'adobereader'
        'firefox'
        'zoom'
        'vcredist140'
        'teamviewer'
        'googledrive'
        'microsoft-teams'
        'winscp.install'
        'k-litecodecpackfull'
        'ffmpeg'
        'yt-dlp'
        'aria2'
    )

    $pacotes = for ($i = 0; $i -lt $pacotesDesejados.Count; $i++) {
        [PSCustomObject]@{
            Numero = $i + 1
            Id     = $pacotesDesejados[$i]
        }
    }

    Write-Host "`nPacotes disponiveis para instalacao:" -ForegroundColor Cyan
    foreach ($item in $pacotes) {
        Write-Host ("[{0,2}] {1}" -f $item.Numero, $item.Id)
    }

    $entrada = Read-Host "`nInforme os numeros dos pacotes a instalar (separados por espaco ou virgula). Digite 'todos' para instalar tudo ou ENTER para cancelar"
    if ([string]::IsNullOrWhiteSpace($entrada)) {
        Write-Info "Nenhum pacote selecionado."
        Pause-Enter
        return
    }

    if ($entrada.Trim().ToUpper() -eq 'TODOS') {
        $selecionados = $pacotes
    } else {
        $indicesInformados = $entrada -split '[,; ]+' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }
        if (-not $indicesInformados) {
            Write-Warn "Nenhum numero valido informado."
            Pause-Enter
            return
        }

        $validos = $indicesInformados | Where-Object { $_ -ge 1 -and $_ -le $pacotes.Count } | Sort-Object -Unique
        if (-not $validos) {
            Write-Warn "Nenhum numero dentro do intervalo foi informado."
            Pause-Enter
            return
        }

        $invalidos = $indicesInformados | Where-Object { $_ -lt 1 -or $_ -gt $pacotes.Count } | Sort-Object -Unique
        if ($invalidos) {
            Write-Warn ("Indices fora do intervalo foram ignorados: {0}" -f ($invalidos -join ', '))
        }

        $selecionados = foreach ($idx in $validos) {
            $pacotes[$idx - 1]
        }
    }

    Write-Info ("Instalando via Chocolatey: {0}" -f (($selecionados.Id) -join ', '))
    foreach ($item in $selecionados) {
        try {
            choco install $item.Id -y --no-progress
            Write-Ok "Instalado: $($item.Id)"
        } catch {
            Write-Err ("Falha ao instalar {0}: {1}" -f $item.Id, $_.Exception.Message)
        }
    }
    Pause-Enter
}

function Acao-7-ChocoAtualizarTudo {
    if (-not (Ensure-Choco)) { Pause-Enter; return }
    Write-Info "Atualizando todos os pacotes do Chocolatey..."
    try {
        choco upgrade all -y --no-progress
        Write-Ok "Atualizacao concluida (Chocolatey)."
    } catch {
        Write-Err "Falha ao atualizar pacotes: $($_.Exception.Message)"
    }
    Pause-Enter
}

# <<< NOVA FUNCAO ATUALIZADA >>>
function Acao-8-ChocoDesinstalarPacote {
    if (-not (Ensure-Choco)) { Pause-Enter; return }
    try {
        # Lista pacotes instalados localmente
        $raw = choco list --local-only --limit-output 2>$null
        if (-not $raw) {
            Write-Warn "Nenhum pacote Chocolatey instalado encontrado."
            Pause-Enter; return
        }

        $i = 1
        $packages = @()
        foreach ($line in $raw) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $parts = $line -split '\|', 2
            $name = $parts[0].Trim()
            $ver  = if ($parts.Count -gt 1) { $parts[1].Trim() } else { "" }
            if ($name) {
                $packages += [PSCustomObject]@{ Index = $i; Name = $name; Version = $ver }
                $i++
            }
        }

        if (-not $packages) {
            Write-Warn "Nenhum pacote identificado na saida do Chocolatey."
            Pause-Enter; return
        }

        Write-Host "`nPacotes instalados:" -ForegroundColor Cyan
        $packages | ForEach-Object {
            $ver = if ($_.Version) { " ($($_.Version))" } else { "" }
            Write-Host ("[{0,2}] {1}{2}" -f $_.Index, $_.Name, $ver)
        }

        $sel = Read-Host "`nDigite o(s) numero(s) do(s) pacote(s) para desinstalar (separados por espaco ou virgula). ENTER para cancelar"
        if ([string]::IsNullOrWhiteSpace($sel)) { return }

        $indices = $sel -split '[, ]+' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ } | Sort-Object -Unique
        if (-not $indices) {
            Write-Warn "Nenhum numero valido informado."
            Pause-Enter; return
        }

        $toUninstall = @()
        foreach ($idx in $indices) {
            $pkg = $packages | Where-Object { $_.Index -eq $idx }
            if ($pkg) { $toUninstall += $pkg.Name }
        }

        if (-not $toUninstall) {
            Write-Warn "Nenhuma selecao valida."
            Pause-Enter; return
        }

        Write-Host "`nSelecionados para desinstalar:" -ForegroundColor Yellow
        $toUninstall | ForEach-Object { Write-Host " - $_" }

        $conf = Read-Host "`nConfirmar? [S/n]"
        if ($conf -and $conf.Trim().ToUpper() -eq 'N') {
            Write-Host "Operacao cancelada."
            Pause-Enter; return
        }

        foreach ($name in $toUninstall) {
            try {
                choco uninstall $name -y --remove-dependencies --no-progress
                Write-Ok "Desinstalado: $name"
            } catch {
                Write-Err "Falha ao desinstalar ${name}: $($_.Exception.Message)"
            }
        }
    } catch {
        Write-Err "Erro inesperado: $($_.Exception.Message)"
    }
    Pause-Enter
}

function Acao-9-MapearDesmapearUnidade {
    Write-Host "`n[1] Mapear unidade de rede"
    Write-Host "[2] Desmapear unidade de rede"
    $op = Read-Host "Escolha"
    switch ($op) {
        '1' {
            $letra = Read-Host "Letra da unidade (ex: Z:)"
            $path  = Read-Host "Caminho UNC (ex: \\servidor\compartilhamento)"
            $user  = Read-Host "Usuario (ENTER para atual)"
            $pass  = if ($user) { Read-Host "Senha" } else { $null }
            try {
                if ($user) {
                    New-PSDrive -Name $letra.TrimEnd(':') -PSProvider FileSystem -Root $path -Persist -Credential (New-Object System.Management.Automation.PSCredential($user,(ConvertTo-SecureString $pass -AsPlainText -Force)))
                } else {
                    New-PSDrive -Name $letra.TrimEnd(':') -PSProvider FileSystem -Root $path -Persist
                }
                Write-Ok "Unidade $letra mapeada para $path"
            } catch {
                Write-Err "Falha ao mapear: $($_.Exception.Message)"
            }
        }
        '2' {
            $letra = Read-Host "Letra da unidade (ex: Z:)"
            try {
                Remove-PSDrive -Name $letra.TrimEnd(':') -Force
                Write-Ok "Unidade $letra removida."
            } catch {
                Write-Err "Falha ao desmapear: $($_.Exception.Message)"
            }
        }
        default { Write-Warn "Opcao invalida."; }
    }
    Pause-Enter
}

function Acao-10-LimpezaTemporarios {
    Write-Info "Limpando arquivos temporarios do Windows, usuarios e navegadores..."
    try {
        $paths = @(
            $env:TEMP
            $env:TMP
            (Join-Path -Path $env:WINDIR -ChildPath 'Temp')
            (Join-Path -Path $env:SystemRoot -ChildPath 'Prefetch')
            (Join-Path -Path $env:SystemRoot -ChildPath 'SoftwareDistribution\Download')
        )

        foreach ($p in $paths) {
            Clear-DirectoryContents -Path $p
        }

        $usersRoot = 'C:\Users'
        if (Test-Path -LiteralPath $usersRoot) {
            $excluded = @('Public','Default','Default User','All Users')
            Get-ChildItem -Path $usersRoot -Directory -ErrorAction SilentlyContinue | Where-Object { $excluded -notcontains $_.Name } | ForEach-Object {
                $userDir = $_
                Write-Info ("Processando perfil: {0}" -f $userDir.Name)

                $userTempTargets = @(
                    (Join-Path -Path $userDir.FullName -ChildPath 'AppData\Local\Temp')
                    (Join-Path -Path $userDir.FullName -ChildPath 'AppData\Local\Microsoft\Windows\INetCache')
                    (Join-Path -Path $userDir.FullName -ChildPath 'AppData\LocalLow\Microsoft\CryptnetUrlCache')
                )

                foreach ($target in $userTempTargets) {
                    Clear-DirectoryContents -Path $target
                }

                $browserPatterns = @(
                    'AppData\Local\Google\Chrome\User Data\*\Cache',
                    'AppData\Local\Google\Chrome\User Data\*\Code Cache',
                    'AppData\Local\Google\Chrome\User Data\*\GPUCache',
                    'AppData\Local\Google\Chrome\User Data\*\Service Worker\CacheStorage',
                    'AppData\Local\Microsoft\Edge\User Data\*\Cache',
                    'AppData\Local\Microsoft\Edge\User Data\*\Code Cache',
                    'AppData\Local\Microsoft\Edge\User Data\*\GPUCache',
                    'AppData\Local\Microsoft\Edge\User Data\*\Service Worker\CacheStorage',
                    'AppData\Local\BraveSoftware\Brave-Browser\User Data\*\Cache',
                    'AppData\Local\BraveSoftware\Brave-Browser\User Data\*\Code Cache',
                    'AppData\Local\Opera Software\Opera Stable\Cache',
                    'AppData\Local\Mozilla\Firefox\Profiles\*\cache2',
                    'AppData\Local\Mozilla\Firefox\Profiles\*\startupCache'
                )

                foreach ($pattern in $browserPatterns) {
                    $patternPath = Join-Path $userDir.FullName $pattern
                    Get-Item -Path $patternPath -ErrorAction SilentlyContinue | ForEach-Object {
                        Clear-DirectoryContents -Path $_.FullName
                    }
                }
            }
        }

        Write-Ok "Limpeza concluida."
    } catch {
        Write-Err "Erro na limpeza: $($_.Exception.Message)"
    }

    Pause-Enter
}

function Acao-11-RemoverPerfisUsuario {
    Write-Warn "ATENCAO: esta rotina remove perfis de usuario (pastas em C:\Users) que nao estejam carregados."
    try {
        $rawProfiles = Get-CimInstance -ClassName Win32_UserProfile -ErrorAction Stop | Where-Object {
            -not $_.Loaded -and -not $_.Special -and $_.LocalPath -and (Test-Path -LiteralPath $_.LocalPath)
        }
    } catch {
        Write-Err ("Erro ao consultar perfis: {0}" -f $_.Exception.Message)
        Pause-Enter
        return
    }

    $currentProfile = $env:USERPROFILE
    $excluir = @('Default','Default User','All Users','Public')
    $candidatos = @()
    $index = 1

    foreach ($profile in $rawProfiles | Sort-Object -Property LocalPath) {
        $path = $profile.LocalPath
        if ([string]::IsNullOrWhiteSpace($path)) { continue }
        if ($currentProfile -and ($path.TrimEnd('\') -ieq $currentProfile.TrimEnd('\'))) { continue }
        $nome = Split-Path -Path $path -Leaf
        if ($excluir -contains $nome) { continue }

        $candidatos += [PSCustomObject]@{
            Index   = $index
            Path    = $path
            Name    = $nome
            Profile = $profile
        }
        $index++
    }

    if (-not $candidatos) {
        Write-Info "Nenhum perfil elegivel encontrado."
        Pause-Enter
        return
    }

    Write-Host "`nPerfis disponiveis para remocao:" -ForegroundColor Cyan
    foreach ($item in $candidatos) {
        Write-Host ("[{0,2}] {1}" -f $item.Index, $item.Path)
    }

    $entrada = Read-Host "`nInforme os numeros dos perfis para remover (separados por espaco ou virgula). ENTER para cancelar"
    if ([string]::IsNullOrWhiteSpace($entrada)) {
        Write-Info "Nenhum perfil selecionado."
        Pause-Enter
        return
    }

    $indices = $entrada -split '[,; ]+' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ } | Sort-Object -Unique
    if (-not $indices) {
        Write-Warn "Nenhum numero valido informado."
        Pause-Enter
        return
    }

    $validos = $indices | Where-Object { $_ -ge 1 -and $_ -le $candidatos.Count }
    if (-not $validos) {
        Write-Warn "Nenhum numero dentro do intervalo foi informado."
        Pause-Enter
        return
    }

    $selecionados = foreach ($idx in $validos) {
        $candidatos | Where-Object { $_.Index -eq $idx }
    }

    Write-Host "`nPerfis selecionados para remocao:" -ForegroundColor Yellow
    $selecionados | ForEach-Object { Write-Host (" - {0}" -f $_.Path) }

    $confirm = Read-Host "`nConfirmar exclusao? [s/N]"
    if ($confirm.Trim().ToUpper() -ne 'S') {
        Write-Info "Operacao cancelada."
        Pause-Enter
        return
    }

    foreach ($item in $selecionados) {
        try {
            Remove-CimInstance -InputObject $item.Profile -ErrorAction Stop
            Write-Ok ("Perfil removido: {0}" -f $item.Path)
        } catch {
            Write-Err ("Falha ao remover {0}: {1}" -f $item.Path, $_.Exception.Message)
        }
    }

    Pause-Enter
}

function Invoke-WindowsDebloatSycnex {
    Write-Info "Preparando Windows10Debloater (Sycnex)..."
    try {
        $debloat = Join-Path $Global:MW_Temp 'Windows10Debloater.ps1'
        Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/Sycnex/Windows10Debloater/master/Windows10Debloater.ps1" -OutFile $debloat
        $silent = Prompt-YesNo "Executar o debloat Sycnex no modo silencioso recomendado?" -DefaultYes
        if ($silent) {
            powershell -ExecutionPolicy Bypass -File $debloat -ArgumentList '-Silent','-SysPrep'
        } else {
            powershell -ExecutionPolicy Bypass -File $debloat
        }
        Write-Ok "Debloat Sycnex finalizado."
    } catch {
        Write-Err "Erro ao executar Windows10Debloater: $($_.Exception.Message)"
    }
}

function Invoke-WindowsDebloatChrisTitus {
    Write-Info "Abrindo WinUtil (Chris Titus)..."
    try {
        $command = "& { iwr -UseBasicParsing -Uri 'https://christitus.com/win' | iex }"
        powershell -NoProfile -ExecutionPolicy Bypass -Command $command
        Write-Ok "WinUtil Chris Titus finalizado."
    } catch {
        Write-Err "Erro ao executar WinUtil: $($_.Exception.Message)"
    }
}

function Invoke-WindowsDebloatCustom {
    Write-Info "Configurando debloat customizado..."

    $actions = @(
        [PSCustomObject]@{
            Key     = 'RemoveConsumerApps'
            Label   = 'Remover aplicativos padrão de consumidor (3D Viewer, Jogos, Notícias, etc.)'
            Default = $true
            Action  = {
                $apps = @(
                    'Microsoft.3DBuilder',
                    'Microsoft.BingNews',
                    'Microsoft.BingWeather',
                    'Microsoft.GetHelp',
                    'Microsoft.Getstarted',
                    'Microsoft.Microsoft3DViewer',
                    'Microsoft.MicrosoftOfficeHub',
                    'Microsoft.MicrosoftSolitaireCollection',
                    'Microsoft.MixedReality.Portal',
                    'Microsoft.MSPaint',
                    'Microsoft.People',
                    'Microsoft.SkypeApp',
                    'Microsoft.Todos',
                    'Microsoft.Xbox.TCUI',
                    'Microsoft.XboxApp',
                    'Microsoft.XboxGameOverlay',
                    'Microsoft.XboxGamingOverlay',
                    'Microsoft.XboxIdentityProvider',
                    'Microsoft.XboxSpeechToTextOverlay',
                    'Microsoft.ZuneMusic',
                    'Microsoft.ZuneVideo'
                )

                foreach ($app in $apps) {
                    try {
                        Get-AppxPackage -AllUsers -Name $app -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
                        Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq $app } | ForEach-Object {
                            Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue
                        }
                    } catch {
                        Write-Warn ("Falha ao remover {0}: {1}" -f $app, $_.Exception.Message)
                    }
                }
                Write-Ok "Pacotes de consumidor removidos (quando presentes)."
            }
        }
        [PSCustomObject]@{
            Key     = 'RemoveOneDrive'
            Label   = 'Remover Microsoft OneDrive'
            Default = $false
            Action  = {
                try {
                    Stop-Process -Name OneDrive -Force -ErrorAction SilentlyContinue
                } catch {}

                $setup = @(
                    (Join-Path $env:SystemRoot 'System32\OneDriveSetup.exe'),
                    (Join-Path $env:SystemRoot 'SysWOW64\OneDriveSetup.exe')
                ) | Where-Object { Test-Path $_ } | Select-Object -First 1

                if ($setup) {
                    try {
                        Start-Process -FilePath $setup -ArgumentList '/uninstall' -Wait -WindowStyle Hidden
                        Write-Ok "OneDrive desinstalado."
                    } catch {
                        Write-Warn ("Falha ao desinstalar OneDrive via instalador: {0}" -f $_.Exception.Message)
                    }
                } else {
                    Write-Warn "Instalador do OneDrive nao encontrado."
                }

                $paths = @(
                    Join-Path $env:UserProfile 'OneDrive',
                    Join-Path $env:UserProfile 'SkyDrive',
                    Join-Path $env:SystemRoot 'OneDrive'
                )
                foreach ($path in $paths) {
                    try {
                        if (Test-Path $path) {
                            Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue
                        }
                    } catch {
                        Write-Warn ("Falha ao limpar {0}: {1}" -f $path, $_.Exception.Message)
                    }
                }
            }
        }
        [PSCustomObject]@{
            Key     = 'DisableTelemetry'
            Label   = 'Desativar telemetria (AllowTelemetry=0, tarefas CEIP)'
            Default = $true
            Action  = {
                try {
                    New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Force | Out-Null
                    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Name 'AllowTelemetry' -Type DWord -Value 0
                    Write-Ok "Telemetria ajustada para AllowTelemetry=0."
                } catch {
                    Write-Warn ("Falha ao ajustar telemetria: {0}" -f $_.Exception.Message)
                }

                $tasks = @(
                    '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser',
                    '\Microsoft\Windows\Application Experience\ProgramDataUpdater',
                    '\Microsoft\Windows\Autochk\Proxy',
                    '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator',
                    '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip',
                    '\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector'
                )

                foreach ($task in $tasks) {
                    try {
                        schtasks.exe /Change /TN $task /Disable *> $null
                    } catch {
                        Write-Warn ("Falha ao desabilitar tarefa {0}: {1}" -f $task, $_.Exception.Message)
                    }
                }
            }
        }
        [PSCustomObject]@{
            Key     = 'DisableCortana'
            Label   = 'Desativar Cortana/Pesquisa online'
            Default = $true
            Action  = {
                try {
                    New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Force | Out-Null
                    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Name 'AllowCortana' -Type DWord -Value 0
                    Stop-Process -Name 'Cortana','SearchUI','SearchApp' -Force -ErrorAction SilentlyContinue
                    Write-Ok "Cortana desativada."
                } catch {
                    Write-Warn ("Falha ao desativar Cortana: {0}" -f $_.Exception.Message)
                }
            }
        }
        [PSCustomObject]@{
            Key     = 'DisableWidgets'
            Label   = 'Desativar Widgets / Noticias e Interesses na barra de tarefas'
            Default = $false
            Action  = {
                try {
                    New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' -Force | Out-Null
                    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' -Name 'AllowNewsAndInterests' -Type DWord -Value 0
                    New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds' -Force | Out-Null
                    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds' -Name 'EnableFeeds' -Type DWord -Value 0
                    Write-Ok "Widgets/Noticias desativados para novas sessoes."
                } catch {
                    Write-Warn ("Falha ao desativar widgets: {0}" -f $_.Exception.Message)
                }
            }
        }
        [PSCustomObject]@{
            Key     = 'RemoveTeams'
            Label   = 'Remover Microsoft Teams (AppX + Teams Machine-Wide)'
            Default = $false
            Action  = {
                try {
                    Get-AppxPackage -AllUsers MicrosoftTeams -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
                } catch {
                    Write-Warn ("Falha ao remover MicrosoftTeams (AppX): {0}" -f $_.Exception.Message)
                }

                try {
                    $wingetAvailable = (Get-Command winget -ErrorAction SilentlyContinue) -ne $null
                    if ($wingetAvailable) {
                        winget uninstall --id Microsoft.Teams --silent --accept-package-agreements --accept-source-agreements *> $null
                        winget uninstall --id Microsoft.Teams.Free --silent --accept-package-agreements --accept-source-agreements *> $null
                    } else {
                        Write-Warn "Winget indisponivel; pulei a remocao via instalador."
                    }
                } catch {
                    Write-Warn ("Falha ao remover Teams via winget: {0}" -f $_.Exception.Message)
                }
            }
        }
    )

    foreach ($entry in $actions) {
        $apply = Prompt-YesNo ("Aplicar: {0}?" -f $entry.Label) -DefaultYes:([bool]$entry.Default)
        $entry | Add-Member -NotePropertyName Selected -NotePropertyValue $apply -Force
    }

    $selected = $actions | Where-Object { $_.Selected }
    if (-not $selected) {
        Write-Warn "Nenhuma acao selecionada para o debloat customizado."
        return
    }

    Write-Host "`nSerao aplicadas as seguintes mudancas:" -ForegroundColor Yellow
    foreach ($entry in $selected) {
        Write-Host (" - {0}" -f $entry.Label)
    }

    if (-not (Prompt-YesNo "Confirmar aplicacao das mudancas selecionadas?" -DefaultYes)) {
        Write-Info "Operacao de debloat customizado cancelada."
        return
    }

    foreach ($entry in $selected) {
        Write-Info ("Executando: {0}" -f $entry.Label)
        try {
            & $entry.Action
        } catch {
            Write-Err ("Falha geral em {0}: {1}" -f $entry.Key, $_.Exception.Message)
        }
    }

    Write-Ok "Debloat customizado concluido."
}

function Acao-12-DebloatWindows {
    while ($true) {
        Clear-Host
        Write-Host "====== Debloat Windows 10/11 ======" -ForegroundColor Magenta
        Write-Host "[ 1] Windows10Debloater (Sycnex)"
        Write-Host "[ 2] WinUtil (Chris Titus) - personalizacao via GUI"
        Write-Host "[ 3] Debloat customizado (selecionar recursos)"
        Write-Host "[ 0] Voltar"
        Write-Host "===================================" -ForegroundColor Magenta

        $choice = Read-Host "Escolha"
        switch ($choice.Trim()) {
            '1' {
                Invoke-WindowsDebloatSycnex
                Pause-Enter
                return
            }
            '2' {
                Invoke-WindowsDebloatChrisTitus
                Pause-Enter
                return
            }
            '3' {
                Invoke-WindowsDebloatCustom
                Pause-Enter
                return
            }
            '0' {
                return
            }
            default {
                Write-Warn "Opcao invalida."
                Start-Sleep -Milliseconds 900
            }
        }
    }
}

function Acao-13-BackupRobocopy {
    $origem = Read-Host "Pasta de origem"
    $dest   = Read-Host "Pasta de destino"
    if ([string]::IsNullOrWhiteSpace($origem) -or [string]::IsNullOrWhiteSpace($dest)) { return }
    $log = Join-Path $Global:MW_LogDir ("robocopy_{0:yyyyMMdd_HHmmss}.log" -f (Get-Date))
    try {
        robocopy "$origem" "$dest" /MIR /Z /R:2 /W:2 /FFT /NP /LOG:"$log"
        Write-Ok "Backup concluido. Log: $log"
    } catch {
        Write-Err "Erro no robocopy: $($_.Exception.Message)"
    }
    Pause-Enter
}

function Acao-14-ExclusaoForcadaPasta {
    $path = Read-Host "Caminho da pasta para excluir (forcado)"
    if ([string]::IsNullOrWhiteSpace($path)) { return }
    try {
        TAKEOWN /F "$path" /R /D Y | Out-Null
        ICACLS "$path" /grant "*S-1-5-32-544:(OI)(CI)F" /T | Out-Null
        Remove-Item -LiteralPath "$path" -Recurse -Force -ErrorAction Stop
        Write-Ok "Pasta removida: $path"
    } catch {
        Write-Err "Falha ao remover: $($_.Exception.Message)"
    }
    Pause-Enter
}

#endregion

function Acao-0-InstalarDependencias {
    Write-Info "Verificando dependencias principais (winget, Chocolatey, PSWindowsUpdate)..."

    $wingetOk = $false
    try {
        $wingetOk = Ensure-Winget
    } catch {
        Write-Err ("Falha ao verificar winget: {0}" -f $_.Exception.Message)
    }
    if ($wingetOk) {
        Write-Ok "Winget disponivel."
    } else {
        Write-Warn "Winget ausente. Instale o App Installer (Microsoft Store) manualmente caso necessario."
    }

    $chocoOk = $false
    try {
        $chocoOk = Ensure-Choco
    } catch {
        Write-Err ("Falha ao verificar Chocolatey: {0}" -f $_.Exception.Message)
    }
    if ($chocoOk) {
        Write-Ok "Chocolatey disponivel."
    } else {
        Write-Err "Chocolatey nao foi instalado automaticamente. Verifique a conexao ou tente novamente."
    }

    $pswuOk = $false
    try {
        $pswuOk = Ensure-PSWindowsUpdate
    } catch {
        Write-Err ("Falha ao preparar PSWindowsUpdate: {0}" -f $_.Exception.Message)
    }
    if ($pswuOk) {
        Write-Ok "PSWindowsUpdate pronto para uso."
    } else {
        Write-Err "Modulo PSWindowsUpdate indisponivel. Reexecute esta rotina apos corrigir o erro."
    }
}

#region Menu

function Mostrar-SetupInicial {
    Clear-Host
    Write-Host "====== PREPARACAO INICIAL ======" -ForegroundColor Magenta
    Write-Host "[ 1] Verificar/instalar dependencias"
    Write-Host "[ 2] Prosseguir para o menu principal"
    Write-Host "[ 0] Sair"
    Write-Host "================================" -ForegroundColor Magenta
}

function Loop-SetupInicial {
    while ($true) {
        Mostrar-SetupInicial
        $escolha = Read-Host "Escolha"
        switch ($escolha.Trim().ToUpper()) {
            '1' {
                Acao-0-InstalarDependencias
                Pause-Enter
            }
            '2' { return }
            '0' { exit }
            'S' { exit }
            'Q' { exit }
            default {
                Write-Warn "Opcao invalida."
                Start-Sleep -Milliseconds 900
            }
        }
    }
}

function Mostrar-Menu {
    Clear-Host
    Write-Host "========== MENU DE MANUTENCAO ==========" -ForegroundColor Magenta
    Write-Host "[ 1] Verificar atualizacoes do Windows"
    Write-Host "[ 2] Instalar atualizacoes do Windows"
    Write-Host "[ 3] Winget: Atualizar aplicativos"
    Write-Host "[ 4] Winget: Desinstalar aplicativos"
    Write-Host "[ 5] Chocolatey: Instalar/Verificar"
    Write-Host "[ 6] Chocolatey: Instalar programas"
    Write-Host "[ 7] Chocolatey: Atualizar tudo"
    Write-Host "[ 8] Chocolatey: Desinstalar pacote"
    Write-Host "[ 9] Mapear/Desmapear unidade de rede"
    Write-Host "[10] Limpeza de temporarios"
    Write-Host "[11] Remover perfis de usuario"
    Write-Host "[12] Debloat do Windows (Sycnex/Titus/Custom)"
    Write-Host "[13] Backup com Robocopy"
    Write-Host "[14] Exclusao forcada de pasta"
    Write-Host "[ S] Sair  |  [Q] Quit  |  [0] Zero para sair"
    Write-Host "=========================================" -ForegroundColor Magenta
}

function Loop-Menu {
    do {
        Mostrar-Menu
        $escolha = Read-Host "Escolha"
        switch ($escolha.Trim().ToUpper()) {
            '1'  { Acao-1-VerificarWindowsUpdates }
            '2'  { Acao-2-InstalarWindowsUpdates }
            '3'  { Acao-3-WingetUpgrade }
            '4'  { Acao-4-WingetUninstall }
            '5'  { Acao-5-ChocoInstalarVerificar }
            '6'  { Acao-6-ChocoInstalarProgramas }
            '7'  { Acao-7-ChocoAtualizarTudo }
            '8'  { Acao-8-ChocoDesinstalarPacote }
            '9'  { Acao-9-MapearDesmapearUnidade }
            '10' { Acao-10-LimpezaTemporarios }
            '11' { Acao-11-RemoverPerfisUsuario }
            '12' { Acao-12-DebloatWindows }
            '13' { Acao-13-BackupRobocopy }
            '14' { Acao-14-ExclusaoForcadaPasta }
            'S' { return }
            'Q' { return }
            '0' { return }
            default { Write-Warn "Opcao invalida."; Start-Sleep -Milliseconds 900 }
        }
    } while ($true)
}

#endregion

Loop-SetupInicial

try {
    Loop-Menu
} finally {
    Stop-Transcript | Out-Null
}
