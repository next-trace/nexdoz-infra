#!/usr/bin/env bash
# DiaBuddy droplet bootstrap script.
#
# Runs ONCE on a fresh Ubuntu 24.04 DO droplet to:
#   - install docker + compose + minimal ops tools
#   - configure UFW firewall (22/80/443)
#   - configure fail2ban default jail
#   - create non-root `deploy` user with sudo + SSH key
#   - disable root SSH + password auth
#   - clone diabuddy-infra to /opt/diabuddy
#
# Usage (from your laptop):
#   scp scripts/provision.sh root@DROPLET_IP:/root/
#   ssh root@DROPLET_IP DEPLOY_PUBKEY="$(cat ~/.ssh/diabuddy_deploy.pub)" bash /root/provision.sh
#
# After this runs you should be able to:
#   ssh deploy@DROPLET_IP 'docker --version'

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Run this as root." >&2
  exit 1
fi

if [ -z "${DEPLOY_PUBKEY:-}" ]; then
  echo "Set DEPLOY_PUBKEY env var to the public key contents before running." >&2
  exit 1
fi

echo "==> apt update + upgrade"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y upgrade

echo "==> install base packages"
apt-get install -y \
  ca-certificates curl git gnupg lsb-release \
  ufw fail2ban tzdata unattended-upgrades

echo "==> install docker engine + compose plugin"
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# shellcheck disable=SC1091
. /etc/os-release
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $VERSION_CODENAME stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "==> firewall"
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

echo "==> fail2ban"
cat > /etc/fail2ban/jail.d/sshd.local <<'EOF'
[sshd]
enabled = true
port    = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s
maxretry = 3
bantime = 1h
findtime = 10m
EOF
systemctl enable fail2ban
systemctl restart fail2ban

echo "==> deploy user"
if ! id deploy >/dev/null 2>&1; then
  adduser --disabled-password --gecos "" deploy
  usermod -aG sudo deploy
  usermod -aG docker deploy
fi
mkdir -p /home/deploy/.ssh
echo "$DEPLOY_PUBKEY" > /home/deploy/.ssh/authorized_keys
chmod 700 /home/deploy/.ssh
chmod 600 /home/deploy/.ssh/authorized_keys
chown -R deploy:deploy /home/deploy/.ssh

echo 'deploy ALL=(ALL) NOPASSWD: /usr/bin/docker, /usr/bin/docker compose, /usr/bin/systemctl restart fail2ban' \
  > /etc/sudoers.d/deploy
chmod 440 /etc/sudoers.d/deploy

echo "==> SSH hardening"
sed -i -E 's/^#?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i -E 's/^#?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i -E 's/^#?PermitEmptyPasswords.*/PermitEmptyPasswords no/' /etc/ssh/sshd_config
systemctl reload ssh

echo "==> clone diabuddy-infra to /opt/diabuddy"
mkdir -p /opt
if [ ! -d /opt/diabuddy ]; then
  git clone https://github.com/next-trace/diabuddy-infra.git /opt/diabuddy
fi
chown -R deploy:deploy /opt/diabuddy

echo "==> unattended upgrades"
systemctl enable unattended-upgrades
systemctl start unattended-upgrades

cat <<'EOF'

====================================================================
Droplet provisioned. Next steps (from your laptop, as the deploy user):

  ssh deploy@DROPLET_IP
  cd /opt/diabuddy
  cp .env.dist .env
  nano .env                        # fill every CHANGE_ME_* value

Then trigger the first deploy via the GitHub Actions workflow
(deploy-prod.yml) on next-trace/diabuddy-infra, or locally:

  docker compose -f docker-compose.prod.yml pull
  docker compose -f docker-compose.prod.yml up -d

Verify:
  curl -sf https://api.${DOMAIN}/healthz
  curl -I  https://app.${DOMAIN}/
====================================================================
EOF
