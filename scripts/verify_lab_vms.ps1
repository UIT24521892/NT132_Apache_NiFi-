# Chạy trong PowerShell của người dùng để nhập mật khẩu sudo tại SSH, không gửi vào chat.
param([string]$RemoteRoot)
$ErrorActionPreference = 'Stop'
if (-not $RemoteRoot) {
    $runFile = Join-Path (Split-Path $PSScriptRoot -Parent) '.tools/vm-current-run.json'
    $RemoteRoot = (Get-Content -Raw -Encoding UTF8 -LiteralPath $runFile | ConvertFrom-Json).RemoteRoot
}
if ($RemoteRoot -notmatch '^/home/trung/nt132-verify-[A-Za-z0-9-]+$') {
    throw 'RemoteRoot không đúng thư mục kiểm chứng đã chuẩn bị.'
}
$keyPath = Join-Path $env:USERPROFILE '.ssh/nt132_lab_ed25519'
$failures = 0
foreach ($task in @(
    @{Port=2222; Name='DB'; Script='check_db_vm.sh'},
    @{Port=2223; Name='API'; Script='check_api_vm.sh'}
)) {
    Write-Host ("Kiem tra " + $task.Name + ": nhap mat khau sudo Ubuntu khi duoc hoi.")
    $sshArguments = @(
        '-tt', '-i', $keyPath, '-o', 'IdentitiesOnly=yes',
        '-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=yes',
        '-p', [string]$task.Port, 'trung@127.0.0.1',
        'sudo', 'bash', ($RemoteRoot + '/scripts/' + $task.Script)
    )
    & ssh.exe @sshArguments
    if ($LASTEXITCODE -ne 0) {
        $failures++
        Write-Host ("FAIL " + $task.Name + "; log nam trong thu muc evidence cua run tren VM.")
    }
}
if ($failures) { exit 1 }
Write-Host 'Hoan tat hai VM. Bao agent de thu log va doi chieu ket qua.'
