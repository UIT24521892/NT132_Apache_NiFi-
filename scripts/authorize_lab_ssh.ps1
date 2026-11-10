# Chạy một lần trong PowerShell của người dùng; mật khẩu Ubuntu chỉ nhập ở prompt SSH.
# Chỉ cấp public key cho user trung trên hai VM lab qua NAT localhost.
param(
    [string]$KeyPath = (Join-Path $env:USERPROFILE '.ssh/nt132_lab_ed25519')
)
$ErrorActionPreference = 'Stop'
$publicPath = $KeyPath + '.pub'
if (-not (Test-Path -LiteralPath $publicPath)) {
    throw 'Chưa có public key lab. Không dùng private key thay cho file .pub.'
}
$publicKey = ([IO.File]::ReadAllText($publicPath)).Trim()
if ($publicKey -notmatch '^ssh-ed25519 [A-Za-z0-9+/=]+(?: [^\r\n]*)?$') {
    throw 'File public key không đúng định dạng Ed25519.'
}
$remoteSetup = @'
set -eu
umask 077
mkdir -p ~/.ssh
chmod 700 ~/.ssh
touch ~/.ssh/authorized_keys
test -r ~/.ssh/authorized_keys
tmp=$(mktemp ~/.ssh/authorized_keys.nt132.XXXXXX)
trap 'rm -f $tmp' EXIT
{ cat ~/.ssh/authorized_keys; printf '\n'; tr -d '\r'; } | awk '!seen[$0]++' > $tmp
chmod 600 $tmp
mv -- $tmp ~/.ssh/authorized_keys
echo 'Public key lab da duoc cap.'
'@
foreach ($port in @(2222, 2223)) {
    Write-Host "VM cong $port : nhap mat khau Ubuntu cua trung (SSH khong hien ky tu)."
    $sshArguments = @(
        '-T', '-o', 'StrictHostKeyChecking=yes',
        '-o', 'PreferredAuthentications=password', '-o', 'PubkeyAuthentication=no',
        '-o', 'NumberOfPasswordPrompts=1', '-o', 'ConnectTimeout=10',
        '-p', [string]$port, 'trung@127.0.0.1', $remoteSetup
    )
    $publicKey | & ssh.exe @sshArguments
    if ($LASTEXITCODE -ne 0) {
        throw "Chua cap duoc public key tren cong $port. Co the chay lai script; khong them trung key."
    }
}
Write-Host 'Da cap key cho hai VM. Bao lai agent de tiep tuc kiem tra va trien khai.'
