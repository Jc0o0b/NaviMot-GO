$env:Path += ";C:\tools\flutter\bin"
$logFile = "$PSScriptRoot\server.log"
$proc = Start-Process -NoNewWindow -PassThru -FilePath "flutter" -ArgumentList "run -d web-server --web-port 8080" -WorkingDirectory $PSScriptRoot -RedirectStandardOutput $logFile -RedirectStandardError $logFile
Write-Output "PID: $($proc.Id)"
Write-Output "Log: $logFile"
Write-Output "Otworz w Chrome: http://localhost:8080"
