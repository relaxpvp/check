# RelaxPvP - Pre-Scan
# Verifica se os serviços do Windows usados na verificação (screenshare) estão ligados.
# Uso: irm check.relaxpvp.gg | iex

$ErrorActionPreference = 'SilentlyContinue'
try { $Host.UI.RawUI.WindowTitle = 'RelaxPvP  ·  Pre-Scan' } catch {}

# nome -> descrição, arranque a repor se estiver Disabled ($null = driver, só verifica)
$services = [ordered]@{
    PcaSvc    = @('Histórico de programas',     'Manual')
    DPS       = @('Diagnóstico do sistema',     'Automatic')
    DiagTrack = @('Telemetria',                 'Automatic')
    EventLog  = @('Registo de eventos',         'Automatic')
    SysMain   = @('Prefetch / Superfetch',      'Automatic')
    Schedule  = @('Agendador de tarefas',       'Automatic')
    DusmSvc   = @('Uso de dados',               'Automatic')
    Appinfo   = @('Informação de aplicações',   'Manual')
    WSearch   = @('Pesquisa do Windows',        'Automatic')
    bam       = @('Atividade em segundo plano', $null)
}

# ---------- estilo ----------
$E = [char]27
$R = "$E[0m"
function fg($r, $g, $b) { "$E[38;2;$r;$g;${b}m" }
$dim   = fg 100 100 110
$soft  = fg 165 165 175
$white = fg 240 240 245
$red   = fg 255 70 80
$green = fg 110 240 160
$yellow = fg 255 200 90
$W = 56   # largura do bloco

function Gradient([string]$text, $from, $to) {
    $n = [math]::Max(1, $text.Length - 1)
    $sb = New-Object Text.StringBuilder
    for ($i = 0; $i -lt $text.Length; $i++) {
        $t = $i / $n
        [void]$sb.Append((fg ([int]($from[0] + ($to[0] - $from[0]) * $t)) ([int]($from[1] + ($to[1] - $from[1]) * $t)) ([int]($from[2] + ($to[2] - $from[2]) * $t))))
        [void]$sb.Append($text[$i])
    }
    $sb.ToString() + $R
}

# calculado uma vez
$logo = @(
    '██████╗ ███████╗██╗      █████╗ ██╗  ██╗'
    '██╔══██╗██╔════╝██║     ██╔══██╗╚██╗██╔╝'
    '██████╔╝█████╗  ██║     ███████║ ╚███╔╝ '
    '██╔══██╗██╔══╝  ██║     ██╔══██║ ██╔██╗ '
    '██║  ██║███████╗███████╗██║  ██║██╔╝ ██╗'
    '╚═╝  ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝'
) | ForEach-Object { (' ' * 8) + (Gradient $_ @(255, 75, 85) @(150, 0, 30)) }
$os = Get-CimInstance Win32_OperatingSystem
$boot = $os.LastBootUpTime

function Draw {
    $up = (Get-Date) - $boot
    $upTxt = if ($up.Days -gt 0) { '{0}d {1}h' -f $up.Days, $up.Hours } else { '{0}h {1}m' -f $up.Hours, $up.Minutes }
    $state = @{}
    Get-Service -Name @($services.Keys) | ForEach-Object { $state[$_.Name] = [string]$_.Status }

    $m = ' ' * [math]::Max(0, [int](($Host.UI.RawUI.WindowSize.Width - $W) / 2))
    $o = New-Object Text.StringBuilder
    $L = { param($s) [void]$o.Append($m + $s + "`n") }

    [void]$o.Append("$E[H$E[2J`n")
    $logo | ForEach-Object { & $L $_ }
    & $L ''
    & $L ((' ' * 15) + $soft + 'P V P' + $dim + '  ·  ' + $red + 'P R E - S C A N' + $R)
    & $L ''
    & $L ($dim + "  $env:COMPUTERNAME  ·  build $($os.BuildNumber)  ·  ligado há $upTxt" + $R)
    & $L ''

    $script:missing = @()
    $script:removed = @()
    $i = 0
    foreach ($name in $services.Keys) {
        $i++
        $key = if ($i -eq 10) { '0' } else { "$i" }
        $st = if ($state[$name] -eq 'Running') { $green + '● ativo' }
              elseif (-not $state[$name]) { $script:missing += $name; $script:removed += $name; $yellow + '● removido' }
              else { $script:missing += $name; $red + '● em falta' }
        & $L ($dim + "  $key   " + $white + ('{0,-11}' -f $name) + $soft + ('{0,-28}' -f $services[$name][0]) + $st + $R)
    }

    & $L ''
    $ok = $services.Count - $missing.Count
    if ($missing.Count -eq 0) {
        & $L ($green + '  ✓  Pronto para a verificação' + $dim + "   $ok/$($services.Count)" + $R)
    } else {
        & $L ($red + "  ✕  $($missing.Count) em falta" + $soft + ', ativa antes da verificação' + $dim + "   $ok/$($services.Count)" + $R)
        if ($missing -contains 'bam' -and $removed -notcontains 'bam') { & $L ($yellow + '     bam é um driver: se continuar em falta, reinicia o PC.' + $R) }
        if ($removed.Count) {
            & $L ($yellow + "     $($removed -join ', '): não existe neste Windows" + $R)
            & $L ($dim + '     (removido por otimizador/debloat, não dá para ligar daqui; fala com a staff)' + $R)
        }
    }
    & $L ''
    $keys = if (($missing | Where-Object { $removed -notcontains $_ }).Count) { $red + '  A' + $dim + ' ativar todos   ' + $white + '1-0' + $dim + ' só um   ' } else { '  ' }
    & $L ($keys + $white + 'R' + $dim + ' reanalisar   ' + $white + 'Q' + $dim + ' sair' + $R)

    Write-Host $o.ToString() -NoNewline
}

function Say([string]$text) {
    $m = ' ' * [math]::Max(0, [int](($Host.UI.RawUI.WindowSize.Width - $W) / 2))
    Write-Host ("`r" + $m + '  ' + $text + "$E[K") -NoNewline
}

function Read-Choice {
    try { return ([string][Console]::ReadKey($true).KeyChar).ToUpper() }
    catch { return (Read-Host "`n   Opção").ToUpper() }
}

function Enable-Services([string[]]$names) {
    $fixable = @($names | Where-Object { $services[$_][1] -and $removed -notcontains $_ })
    if ($fixable.Count -eq 0) { return }

    $log = Join-Path $env:TEMP ("relaxpvp_check_" + [guid]::NewGuid() + '.txt')
    $cmd = foreach ($n in $fixable) {
        @"
try {
  if ((Get-CimInstance Win32_Service -Filter "Name='$n'").StartMode -eq 'Disabled') { Set-Service -Name '$n' -StartupType $($services[$n][1]) -ErrorAction Stop }
  `$s = Get-Service -Name '$n' -ErrorAction Stop
  if (`$s.Status -ne 'Running') { Start-Service -Name '$n' -ErrorAction Stop; `$s.WaitForStatus('Running', [TimeSpan]::FromSeconds(10)) }
} catch { Add-Content -LiteralPath '$log' -Value ('$n : ' + `$_.Exception.Message) }
"@
    }
    $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes(($cmd -join "`r`n")))

    Write-Host "`n" -NoNewline
    Say ((fg 255 200 90) + 'Aceita o pedido de administrador...' + $R)
    try {
        $p = Start-Process "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Verb RunAs -PassThru -WindowStyle Hidden -ErrorAction Stop `
            -ArgumentList '-NoProfile', '-EncodedCommand', $enc
    } catch {
        Say ((fg 255 200 90) + 'Permissão de administrador cancelada.' + $R)
        Start-Sleep 1
        return
    }
    Say ($white + 'A ativar ' + $soft + ($fixable -join ', ') + $dim + '...' + $R)
    $p.WaitForExit()

    if (Test-Path $log) {
        Say ($red + 'Não foi possível ativar:' + $R); Write-Host ''
        Get-Content $log | ForEach-Object { Say ($dim + '· ' + $soft + $_ + $R); Write-Host '' }
        Remove-Item $log -Force
        Say ($dim + 'Carrega numa tecla para continuar...' + $R)
        $null = Read-Choice
    }
}

function Scan-Animation {
    $spin  = '|', '/', '-', '\'
    $steps = 28
    for ($i = 0; $i -le $steps; $i++) {
        $bar  = $red + ('█' * $i) + $dim + ('░' * ($steps - $i))
        $pct  = [int](100 * $i / $steps)
        Say ($red + $spin[$i % $spin.Count] + $soft + '  A analisar  ' + $bar + $white + (' {0,3}%' -f $pct) + $R)
        Start-Sleep -Milliseconds 40
    }
    Say ($green + '✓' + $soft + '  Análise concluída' + $R)
    Start-Sleep -Milliseconds 350
}

# ---------- loop ----------
Write-Host "$E[?1049h$E[?25l" -NoNewline   # ecrã alternativo + esconde cursor
try {
    while ($true) {
        Draw
        $c = Read-Choice
        if ($c -eq 'Q') { break }
        if ($c -eq 'R') { Scan-Animation }
        if ($c -eq 'A' -and $missing.Count) { Enable-Services $missing }
        if ($c -match '^\d$') {
            $idx = if ($c -eq '0') { 9 } else { [int]$c - 1 }
            $n = @($services.Keys)[$idx]
            if ($n -and $missing -contains $n) { Enable-Services @($n) }
        }
    }
} finally {
    Write-Host "$E[?25h$E[?1049l" -NoNewline   # repõe ecrã e cursor
    $ok = $services.Count - $missing.Count
    if ($missing.Count -eq 0) { Write-Host ("`n  " + $green + '●' + $white + " RelaxPvP Pre-Scan: $ok/$($services.Count) ativos, pronto para a verificação." + $R + "`n") }
    else { Write-Host ("`n  " + $red + '●' + $white + " RelaxPvP Pre-Scan: $ok/$($services.Count) ativos, faltam: " + $soft + ($missing -join ', ') + $R + "`n") }
}
