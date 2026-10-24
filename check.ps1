$services = 'PCAsvc','DPS','DiagTrack','EventLog','SysMain','Schedule','DusmSvc','Appinfo','WSearch'

# Used only when a service is Disabled
$startupTypes = @{
    PCAsvc    = 'Manual'
    DPS       = 'Automatic'
    DiagTrack = 'Automatic'
    EventLog  = 'Automatic'
    SysMain   = 'Automatic'
    Schedule  = 'Automatic'
    DusmSvc   = 'Automatic'
    Appinfo   = 'Manual'
    WSearch   = 'Automatic'
}

function Start-ServiceAsAdmin {
    param(
        [string[]]$Names
    )

    if (-not $Names -or $Names.Count -eq 0) {
        return
    }

    $errorFile = Join-Path $env:TEMP ("relaxpvp_service_" + [guid]::NewGuid().ToString() + ".txt")

    $commands = @()

    foreach ($name in $Names) {

        $safeName = $name.Replace("'", "''")
        $startupType = $startupTypes[$name]

        $commands += @"
try {
    `$svcInfo = Get-CimInstance Win32_Service -Filter "Name='$safeName'" -ErrorAction Stop

    if (`$svcInfo.StartMode -eq 'Disabled') {
        Set-Service -Name '$safeName' -StartupType $startupType -ErrorAction Stop
        Start-Sleep -Milliseconds 300
    }

    `$svc = Get-Service -Name '$safeName' -ErrorAction Stop

    if (`$svc.Status -ne 'Running') {
        Start-Service -Name '$safeName' -ErrorAction Stop
        `$svc.WaitForStatus('Running', [TimeSpan]::FromSeconds(10))
    }
}
catch {
    Add-Content -LiteralPath '$errorFile' -Value ('$safeName : ' + `$_.Exception.Message)
}
"@
    }

    $command = $commands -join "`r`n"

    $bytes = [System.Text.Encoding]::Unicode.GetBytes($command)
    $encodedCommand = [Convert]::ToBase64String($bytes)

    try {
        Start-Process `
            -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
            -Verb RunAs `
            -ArgumentList '-NoProfile', '-EncodedCommand', $encodedCommand `
            -Wait `
            -ErrorAction Stop

        Start-Sleep -Milliseconds 750

        if (Test-Path $errorFile) {
            $errors = Get-Content $errorFile

            if ($errors) {
                Write-Host ""
                Write-Host "Nao foi possivel ativar:" -ForegroundColor Red

                foreach ($err in $errors) {
                    Write-Host " - $err" -ForegroundColor Red
                }

                Write-Host ""
                Read-Host "Pressiona ENTER para continuar"
            }

            Remove-Item $errorFile -Force -ErrorAction SilentlyContinue
        }
    }
    catch {
        Write-Host ""
        Write-Host "Permissao de administrador cancelada." -ForegroundColor Yellow
        Start-Sleep -Seconds 1
    }
}

function Show-Menu {
    Clear-Host

    Write-Host "Pre-Scan RelaxPvP" -ForegroundColor Cyan
    Write-Host "-----------------`n"

    $script:missing = @()

    for ($i = 0; $i -lt $services.Count; $i++) {
        $name = $services[$i]

        $svc = Get-Service -Name $name -ErrorAction SilentlyContinue

        Write-Host ("[{0}] {1,-12}" -f ($i + 1), $name) -NoNewline

        if ($svc -and $svc.Status -eq 'Running') {
            Write-Host " OK" -ForegroundColor Green
        }
        else {
            Write-Host " EM FALTA" -ForegroundColor Red
            $script:missing += $name
        }
    }

    Write-Host ""
    Write-Host ""

    if ($missing.Count -eq 0) {
        Write-Host "Estas OK para jogar" -ForegroundColor Green
    }
    else {
        Write-Host "Tens estes servicos em falta:" -ForegroundColor Red

        foreach ($name in $missing) {
            Write-Host " - $name" -ForegroundColor Red
        }

        Write-Host ""
        Write-Host "[A] Ativar todos em falta"
    }

    Write-Host "[R] Atualizar"
    Write-Host "[Q] Sair"
}

:main while ($true) {

    Show-Menu

    $choice = Read-Host "`nOpcao"

    switch ($choice.ToUpper()) {

        'A' {
            if ($missing.Count -gt 0) {
                Start-ServiceAsAdmin -Names $missing
            }
        }

        'R' {
            # Refreshes automatically on next loop
        }

        'Q' {
            break main
        }

        default {
            if ($choice -match '^\d+$') {

                $index = [int]$choice - 1

                if ($index -ge 0 -and $index -lt $services.Count) {

                    $name = $services[$index]
                    $svc = Get-Service -Name $name -ErrorAction SilentlyContinue

                    if (-not $svc) {
                        Write-Host ""
                        Write-Host "$name nao foi encontrado." -ForegroundColor Red
                        Start-Sleep -Seconds 1
                    }
                    elseif ($svc.Status -eq 'Running') {
                        Write-Host ""
                        Write-Host "$name ja esta ativo." -ForegroundColor Green
                        Start-Sleep -Seconds 1
                    }
                    else {
                        Start-ServiceAsAdmin -Names @($name)
                    }
                }
            }
        }
    }
}
