# Forever Quests updater: downloads the latest version from GitHub and copies it over this
# addon folder. The game does not let addons download anything, so this runs outside it.
# Run it from "Atualizar ForeverQuests.bat" (double-click), then type /reload in the game.
$ErrorActionPreference = 'Stop'
$Repo = 'SanchesIH/foreverquests'
$Branch = 'main'
$Addon = Split-Path -Parent $PSScriptRoot
$Temp = Join-Path ([IO.Path]::GetTempPath()) ('ForeverQuests-' + [guid]::NewGuid())
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    New-Item -ItemType Directory -Path $Temp | Out-Null
    $Zip = Join-Path $Temp 'update.zip'
    Write-Host "Baixando a versao mais recente de github.com/$Repo ..."
    Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/$Repo/archive/refs/heads/$Branch.zip" -OutFile $Zip
    Expand-Archive -Path $Zip -DestinationPath $Temp -Force
    # the addon is the folder that holds ForeverQuests.toc, wherever it sits in the repository
    $Toc = Get-ChildItem -Path $Temp -Recurse -Filter 'ForeverQuests.toc' | Select-Object -First 1
    if (-not $Toc) { throw 'ForeverQuests.toc nao encontrado no repositorio.' }
    $Source = $Toc.Directory.FullName
    $Old = (Select-String -Path (Join-Path $Addon 'ForeverQuests.toc') -Pattern '^## Version:\s*(.+)$' -ErrorAction SilentlyContinue).Matches.Groups[1].Value
    $New = (Select-String -Path $Toc.FullName -Pattern '^## Version:\s*(.+)$').Matches.Groups[1].Value
    Write-Host "Instalado: $Old   ->   Novo: $New"
    # the .bat that started us is still running: leave it alone
    Get-ChildItem -Path $Source | Where-Object { $_.Name -ne 'Atualizar ForeverQuests.bat' } | Copy-Item -Destination $Addon -Recurse -Force
    Write-Host ''
    Write-Host 'Pronto! No jogo, digite /reload.'
    Write-Host '(Se esta atualizacao trouxe arquivos de som novos, feche e abra o jogo em vez do /reload.)'
}
catch {
    Write-Host ''
    Write-Host ('Nao foi possivel atualizar: ' + $_.Exception.Message) -ForegroundColor Red
}
finally {
    if (Test-Path $Temp) { Remove-Item -Recurse -Force $Temp }
}
