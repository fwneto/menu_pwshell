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

#endregion

#region Acoes

function Acao-1-VerificarWindowsUpdates {
    Write-Info "Verificando atualizacoes do Windows..."
    try {
        Get-WindowsUpdate -AcceptAll -IgnoreReboot -WhatIf
    } catch {
        Write-Warn "Modulo PSWindowsUpdate nao encontrado. Instalando..."
        try {
            Install-PackageProvider -Name NuGet -Force -Scope CurrentUser -ErrorAction SilentlyContinue | Out-Null
            Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted -ErrorAction SilentlyContinue
            Install-Module PSWindowsUpdate -Force -Scope AllUsers
            Import-Module PSWindowsUpdate
            Get-WindowsUpdate -AcceptAll -IgnoreReboot -WhatIf
        } catch {
            Write-Err "Erro ao preparar/verificar Windows Update: $($_.Exception.Message)"
        }
    }
    Pause-Enter
}

function Acao-2-InstalarWindowsUpdates {
    Write-Info "Instalando atualizacoes do Windows..."
    try {
        Get-WindowsUpdate -AcceptAll -IgnoreReboot -Install
    } catch {
        Write-Warn "Modulo PSWindowsUpdate nao encontrado. Instalando..."
        try {
            Install-PackageProvider -Name NuGet -Force -Scope CurrentUser -ErrorAction SilentlyContinue | Out-Null
            Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted -ErrorAction SilentlyContinue
            Install-Module PSWindowsUpdate -Force -Scope AllUsers
            Import-Module PSWindowsUpdate
            Get-WindowsUpdate -AcceptAll -IgnoreReboot -Install
        } catch {
            Write-Err "Erro ao instalar atualizacoes: $($_.Exception.Message)"
        }
    }
    Pause-Enter
}

function Acao-3-WingetUpgrade {
    if (-not (Ensure-Winget)) { Pause-Enter; return }
    Write-Info "Atualizando todos os aplicativos via winget..."
    try {
        winget upgrade --all --silent --accept-source-agreements --accept-package-agreements
        Write-Ok "Atualizacao concluida (winget)."
    } catch {
        Write-Err "Falha no winget upgrade: $($_.Exception.Message)"
    }
    Pause-Enter
}

function Acao-4-WingetUninstall {
    if (-not (Ensure-Winget)) { Pause-Enter; return }
    Write-Info "Listando pacotes winget instalados..."
    try {
        $rawJson = winget list --accept-source-agreements --output json | Out-String
        if (-not $rawJson.Trim()) { Write-Warn "Nenhum app encontrado."; Pause-Enter; return }

        try {
            $parsed = $rawJson | ConvertFrom-Json
        } catch {
            Write-Err "Nao foi possivel interpretar a saida do winget."; Pause-Enter; return
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

        if (-not $normalized) { Write-Warn "Nenhum app encontrado."; Pause-Enter; return }

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
                winget uninstall --id "$id" --exact --silent --accept-source-agreements --accept-package-agreements
                Write-Ok "Desinstalado (winget): $id"
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
    Write-Info "Limpando arquivos temporarios do Windows e usuario..."
    try {
        $paths = @(
            $env:TEMP, $env:TMP,
            "$env:WINDIR\Temp",
            "$env:SystemRoot\SoftwareDistribution\Download"
        )
        foreach ($p in $paths) {
            if (Test-Path $p) {
                Write-Info "Limpando: $p"
                Get-ChildItem -Path $p -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        Write-Ok "Limpeza concluida."
    } catch {
        Write-Err "Erro na limpeza: $($_.Exception.Message)"
    }
    Pause-Enter
}

function Acao-11-RemoverPerfisUsuario {
    $confirm = Read-Host "ATENCAO: isto remove perfis de usuario (pastas em C:\Users) que nao estejam em uso. Confirmar? [s/N]"
    if ($confirm.Trim().ToUpper() -ne 'S') { return }
    try {
        $inUse = (Get-WmiObject -Class Win32_ComputerSystem).UserName
        Get-CimInstance -ClassName Win32_UserProfile | Where-Object { -not $_.Loaded -and -not $_.Special } | ForEach-Object {
            $p = $_.LocalPath
            if ($p -and $p -ne $env:USERPROFILE) {
                try {
                    Remove-CimInstance -InputObject $_
                    Write-Ok "Perfil removido: $p"
                } catch {
                    Write-Err "Falha ao remover ${p}: $($_.Exception.Message)"
                }
            }
        }
    } catch {
        Write-Err "Erro ao enumerar/remover perfis: $($_.Exception.Message)"
    }
    Pause-Enter
}

function Acao-12-DebloatSycnex {
    Write-Info "Executando Windows10Debloater (Sycnex)..."
    try {
        $debloat = Join-Path $Global:MW_Temp 'Windows10Debloater.ps1'
        Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/Sycnex/Windows10Debloater/master/Windows10Debloater.ps1" -OutFile $debloat
        powershell -ExecutionPolicy Bypass -File $debloat
        Write-Ok "Debloat finalizado."
    } catch {
        Write-Err "Erro no debloat: $($_.Exception.Message)"
    }
    Pause-Enter
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

#region Menu

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
    Write-Host "[12] Debloat do Windows (Sycnex)"
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
            '12' { Acao-12-DebloatSycnex }
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

try {
    Loop-Menu
} finally {
    Stop-Transcript | Out-Null
}
