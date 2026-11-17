#!/usr/bin/env bash
# VM3 ftp.lab, Ubuntu Server 24.04: sudo bash infra/ftp/setup_vm3.sh <IP_VM3>
# Cài vsftpd, tạo clock_uploader (ghi/rename) và nifi_fetch (chỉ list/read), inbox /checkin.
# Chạy lại an toàn: không xóa file trong inbox, không đổi mật khẩu đã có.
# Không đặt mật khẩu và không đổi firewall; hai bước đó làm thủ công theo hướng dẫn.
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
PASV_IP="${1:-}"
FTP_ROOT=/srv/ftp/nt132
INBOX=$FTP_ROOT/checkin
READ_GROUP=nt132-ftp-read
UPLOADER=clock_uploader
READER=nifi_fetch
NOLOGIN=/usr/sbin/nologin

[[ $EUID -eq 0 ]] || { echo "FAIL: cần chạy bằng sudo" >&2; exit 1; }
[[ $(hostname -s) == ftp ]] || { echo "FAIL: hostname phải là ftp (đúng VM3)" >&2; exit 1; }
if [[ ! $PASV_IP =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
  echo "Dùng: sudo bash infra/ftp/setup_vm3.sh <IP_VM3>" >&2
  exit 2
fi

if ! dpkg -s vsftpd >/dev/null 2>&1; then
  apt-get update -q
  DEBIAN_FRONTEND=noninteractive apt-get install -y -q vsftpd
fi

# PAM vsftpd dùng pam_shells: shell nologin phải có trong /etc/shells thì user FTP mới đăng nhập được,
# trong khi vẫn không có shell SSH tương tác.
grep -qxF "$NOLOGIN" /etc/shells || echo "$NOLOGIN" >> /etc/shells

getent group "$READ_GROUP" >/dev/null || groupadd --system "$READ_GROUP"
id -u "$UPLOADER" >/dev/null 2>&1 || useradd --home-dir "$FTP_ROOT" --no-create-home --shell "$NOLOGIN" "$UPLOADER"
id -u "$READER" >/dev/null 2>&1 || useradd --home-dir "$FTP_ROOT" --no-create-home --shell "$NOLOGIN" "$READER"
usermod -aG "$READ_GROUP" "$READER"

# Chroot root không writable; inbox: uploader rwx, nhóm đọc r-x, setgid để file mới thuộc nhóm đọc.
install -d -m 0755 -o root -g root /srv/ftp "$FTP_ROOT"
install -d -m 2750 -o "$UPLOADER" -g "$READ_GROUP" "$INBOX"

install -d -m 0755 -o root -g root /etc/vsftpd/users
printf '%s\n' "$UPLOADER" "$READER" > /etc/vsftpd.userlist
chmod 0644 /etc/vsftpd.userlist
printf 'write_enable=NO\n' > /etc/vsftpd/users/$READER
chmod 0644 /etc/vsftpd/users/$READER

[[ -f /etc/vsftpd.conf.orig-nt132 ]] || cp -p /etc/vsftpd.conf /etc/vsftpd.conf.orig-nt132
sed "s|__PASV_ADDRESS__|$PASV_IP|" "$SRC/vsftpd.conf" > /etc/vsftpd.conf.new
chmod 0644 /etc/vsftpd.conf.new
mv /etc/vsftpd.conf.new /etc/vsftpd.conf

for u in "$UPLOADER" "$READER"; do
  if [[ $(passwd -S "$u" | awk '{print $2}') != P ]]; then
    echo "CHÚ Ý: $u chưa có mật khẩu, chạy: sudo passwd $u"
  fi
done

if [[ -d /run/systemd/system ]]; then
  systemctl enable vsftpd >/dev/null
  systemctl restart vsftpd
  systemctl is-active --quiet vsftpd || { echo "FAIL: vsftpd không active; xem journalctl -u vsftpd" >&2; exit 1; }
  echo "PASS: vsftpd active, passive $PASV_IP:40000-40010, inbox $INBOX (FTP path /checkin)."
else
  echo "Không có systemd: đã ghi cấu hình, chưa khởi động vsftpd."
fi
