#!/usr/bin/env bash
# Sets up the test-phase server (Oracle Cloud, Ubuntu 24.04, arm64; docs/INFRA.md). Run as root;
# safe to run again. scripts/server-setup.sh copies this folder to the server and runs it.
# - security updates every day, installed by themselves, with a restart at 03:30 UTC if needed;
# - the host firewall: Oracle's own iptables rules, with 80 and 443 opened (kept across restarts);
# - SSH: keys only, no root;
# - Docker (the API's containers) and Caddy (TLS for api.magana.ng), both started at boot and
#   restarted if they stop;
# - magana-deploy and its timer (every minute).
# It never prints a secret, and never writes /etc/magana/magana.env (scripts/server-env.sh does).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
export DEBIAN_FRONTEND=noninteractive
[ "$(id -u)" = 0 ] || { echo "run as root (sudo)"; exit 1; }

echo "== updates"
echo "iptables-persistent iptables-persistent/autosave_v4 boolean false" | debconf-set-selections
echo "iptables-persistent iptables-persistent/autosave_v6 boolean false" | debconf-set-selections
apt-get update -q
apt-get -y -q -o Dpkg::Options::=--force-confold full-upgrade
apt-get -y -q install unattended-upgrades ca-certificates curl gnupg git jq iptables-persistent \
  debian-keyring debian-archive-keyring apt-transport-https

cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF
# Ubuntu's default origins are the security updates; Docker's and Caddy's repositories are added
# so their fixes come too. A restart, when an update needs one, at 03:30 UTC (04:30 in Lagos).
cat > /etc/apt/apt.conf.d/52magana-unattended <<'EOF'
Unattended-Upgrade::Origins-Pattern {
        "origin=Docker,label=Docker CE";
        "site=dl.cloudsmith.io,label=caddy-stable";
};
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "03:30";
EOF
systemctl enable --now unattended-upgrades >/dev/null

echo "== firewall"
# Oracle's Ubuntu images block everything but SSH in iptables (/etc/iptables/rules.v4), whatever the
# cloud's network rules say. Their rules stay (they also protect the instance's metadata and boot
# volume); 80 and 443 go in just before the final REJECT, live and in the saved file. Not ufw:
# Oracle advises against it on these images.
RULES=/etc/iptables/rules.v4
for port in 80 443; do
  rule="-A INPUT -p tcp -m state --state NEW -m tcp --dport $port -j ACCEPT"
  grep -qF -- "$rule" "$RULES" || sed -i "0,/^-A INPUT -j REJECT/s//${rule//\//\\/}\n-A INPUT -j REJECT/" "$RULES"
  iptables -C INPUT -p tcp -m state --state NEW -m tcp --dport "$port" -j ACCEPT 2>/dev/null || \
    iptables -I INPUT "$(iptables -L INPUT --line-numbers | awk '$2=="REJECT"{print $1; exit}')" \
      -p tcp -m state --state NEW -m tcp --dport "$port" -j ACCEPT
done
grep -c -- "--dport \(80\|443\) -j ACCEPT" "$RULES" | grep -qx 2 || { echo "couldn't add 80/443 to $RULES"; exit 1; }

echo "== ssh"
cat > /etc/ssh/sshd_config.d/60-magana.conf <<'EOF'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
EOF
sshd -t && systemctl reload ssh

echo "== docker"
if ! command -v docker >/dev/null; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -q
  apt-get -y -q install docker-ce docker-ce-cli containerd.io docker-buildx-plugin
fi
# Container logs rotate (they never hold photos, page text or quick-check answers).
echo '{ "log-driver": "json-file", "log-opts": { "max-size": "20m", "max-file": "5" } }' > /tmp/daemon.json
cmp -s /tmp/daemon.json /etc/docker/daemon.json || { mv /tmp/daemon.json /etc/docker/daemon.json; systemctl restart docker; }
systemctl enable docker >/dev/null

echo "== caddy"
if ! command -v caddy >/dev/null; then
  curl -1sLf https://dl.cloudsmith.io/public/caddy/stable/gpg.key | gpg --dearmor --yes -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -1sLf https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt > /etc/apt/sources.list.d/caddy-stable.list
  apt-get update -q && apt-get -y -q install caddy
fi
mkdir -p /etc/systemd/system/caddy.service.d
cat > /etc/systemd/system/caddy.service.d/restart.conf <<'EOF'
[Service]
Restart=always
RestartSec=5
EOF
install -m 644 "$HERE/Caddyfile" /etc/caddy/Caddyfile
caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null

echo "== magana-deploy"
install -d -m 700 /etc/magana
install -d -m 755 /var/lib/magana /var/lib/magana/public /opt/magana
install -m 755 "$HERE/magana-deploy" /usr/local/bin/magana-deploy
install -m 644 "$HERE/magana-deploy.service" "$HERE/magana-deploy.timer" /etc/systemd/system/
systemctl daemon-reload
systemctl enable caddy >/dev/null && systemctl reload-or-restart caddy
systemctl enable --now magana-deploy.timer >/dev/null

echo "== done"
echo "settings: $( [ -f /etc/magana/magana.env ] && echo present || echo 'missing (scripts/server-env.sh --push)')"
systemctl is-active docker caddy magana-deploy.timer unattended-upgrades | paste -sd' ' -
