#!/bin/sh
set -eu

HOST="${1:-aiflow}"
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REMOTE=/opt/aiflow-n8n
VOLUME=aiflow-n8n_n8n_data
STATE="$HERE/.staticdata"

say()  { printf '\033[36m▸\033[0m %s\n' "$1"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$1" >&2; }
die()  { printf '\033[31m✗\033[0m %s\n' "$1" >&2; exit 1; }

sshx() { ssh -o BatchMode=yes "$HOST" "$@"; }

say "preflight"
sshx true 2>/dev/null || die "tidak bisa ssh ke '$HOST' tanpa password"
ok "ssh ke $HOST"

if [ -z "${TELEGRAM_TOKEN:-}" ]; then
  TELEGRAM_TOKEN=$(sshx 'tr -d "[:space:]" < /root/.telegram-token 2>/dev/null' || true)
fi
test -n "$TELEGRAM_TOKEN" || die "TELEGRAM_TOKEN kosong dan /root/.telegram-token tidak ada di server"

: "${TELEGRAM_CHAT_ID:=705649915}"
: "${STATUS_URL:=https://umars28.github.io/aiflow/status.json}"
ok "kredensial siap (token ${#TELEGRAM_TOKEN} karakter, chat $TELEGRAM_CHAT_ID)"

say "pengerasan dasar"
sshx 'set -e
ufw allow 22/tcp >/dev/null 2>&1
ufw --force enable >/dev/null 2>&1
cat > /etc/ssh/sshd_config.d/99-hardening.conf <<EOF
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin prohibit-password
EOF
sshd -t && systemctl reload ssh'
ok "ufw aktif, ssh key-only"

say "docker"
if sshx 'command -v docker >/dev/null 2>&1'; then
  ok "sudah ada: $(sshx 'docker --version')"
else
  sshx 'set -e
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" > /etc/apt/sources.list.d/docker.list
  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin >/dev/null 2>&1
  systemctl enable --now docker' || die "gagal memasang docker"
  ok "terpasang: $(sshx 'docker --version')"
fi

say "simpan staticData yang ada"
db="/var/lib/docker/volumes/$VOLUME/_data/database.sqlite"
if sshx "test -f $db" 2>/dev/null && sshx 'command -v sqlite3 >/dev/null 2>&1'; then
  sshx "sqlite3 \"$db\" 'select id || char(9) || coalesce(staticData, \"\") from workflow_entity;'" > "$STATE" 2>/dev/null || : > "$STATE"
  ok "$(wc -l < "$STATE" | tr -d ' ') baris state disimpan"
else
  : > "$STATE"
  warn "belum ada database, state kosong"
fi

say "compose"
sshx "mkdir -p $REMOTE/workflows"
sed -e "s|TELEGRAM_TOKEN=.*|TELEGRAM_TOKEN=$TELEGRAM_TOKEN|" \
    -e "s|TELEGRAM_CHAT_ID=.*|TELEGRAM_CHAT_ID=$TELEGRAM_CHAT_ID|" \
    -e "s|AIFLOW_STATUS_URL=.*|AIFLOW_STATUS_URL=$STATUS_URL|" \
    "$HERE/compose.yaml" | sshx "umask 077; cat > $REMOTE/compose.yaml"
sshx "cd $REMOTE && docker compose up -d >/dev/null 2>&1"
ok "container naik"

say "tunggu sehat"
sshx 'for i in $(seq 1 40); do curl -sf -o /dev/null http://127.0.0.1:5678/healthz && exit 0; sleep 3; done; exit 1' \
  || die "n8n tidak sehat setelah 2 menit"
ok "n8n merespons"

say "impor workflow"
count=0
for f in "$HERE"/*.json; do
  test -f "$f" || continue
  name=$(basename "$f")
  id=$(jq -r '.id // empty' "$f")
  test -n "$id" || { warn "$name tidak punya id, dilewati"; continue; }
  scp -q -o BatchMode=yes "$f" "$HOST:$REMOTE/workflows/$name"
  sshx "docker cp $REMOTE/workflows/$name n8n:/tmp/$name >/dev/null && docker exec n8n n8n import:workflow --input=/tmp/$name" >/dev/null 2>&1 \
    || die "gagal mengimpor $name"
  ok "$name ($id)"
  count=$((count + 1))
done
test "$count" -gt 0 || die "tidak ada workflow untuk diimpor"

say "kembalikan staticData"
sql=$(mktemp)
awk -F'\t' '$2 != "" { v = $2; gsub(/\x27/, "\x27\x27", v); printf "update workflow_entity set staticData=\x27%s\x27 where id=\x27%s\x27;\n", v, $1 }' "$STATE" > "$sql"
restored=$(grep -c . "$sql" || true)
if [ "$restored" -gt 0 ]; then
  sshx "sqlite3 '$db'" < "$sql" || die "gagal memulihkan staticData"
fi
rm -f "$sql"
ok "$restored workflow dipulihkan state-nya"

say "aktifkan"
for f in "$HERE"/*.json; do
  test -f "$f" || continue
  id=$(jq -r '.id // empty' "$f")
  test -n "$id" || continue
  test "$(jq -r '.active // false' "$f")" = "true" || continue
  sshx "docker exec n8n n8n update:workflow --id=$id --active=true" >/dev/null 2>&1
  ok "$id aktif"
done

say "restart supaya jadwal terdaftar"
sshx "cd $REMOTE && docker compose restart >/dev/null 2>&1"
sshx 'for i in $(seq 1 40); do curl -sf -o /dev/null http://127.0.0.1:5678/healthz && exit 0; sleep 3; done; exit 1' \
  || die "n8n tidak kembali setelah restart"

say "verifikasi"
sshx "sqlite3 -header \"$db\" 'select id, active, triggerCount from workflow_entity;'"
sshx 'ss -tlnp | grep -q "127.0.0.1:5678" && echo "  bind: hanya loopback" || echo "  BIND TERBUKA KE PUBLIK"'
printf '\n\033[32mselesai\033[0m  buka UI dengan: ssh %s-ui lalu http://localhost:5678\n' "$HOST"
