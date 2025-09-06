#!/usr/bin/env bash
set -euo pipefail
umask 077

# =========================
# CONFIG — VALORI FISSI
# =========================
GDRIVE_ROOT="programming/imm-gen-ai/llm-ai"
GDRIVE_MODELS_SUB="models/OpenHermes-2.5-Mistral-7B"
GDRIVE_WEBUI_SUB="text-generation-webui-oobabooga"

WEBUI_PORT="7860"
WEBUI_AUTH_USER="Marco"
WEBUI_AUTH_PASS="gggg9999"

LOC_ROOT="/workspace"
LOC_MODELS="${LOC_ROOT}/models"
LOC_WEBUI="${LOC_ROOT}/webui"

RCLONE_TRANSFERS="8"
RCLONE_CHECKERS="16"
RCLONE_CHUNK="128M"

# =========================
# SSH (persistente) — AUTORIZZAZIONE CHIAVE PUBBLICA
# =========================
PUBLIC_SSH_KEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICKRuWOwBaaiVaehn5LhscLfZcha9cmT+ZI4O4SQ6Y0Y runpod-20250906'

echo "[SSH] Setup persistente in /workspace/.ssh"
mkdir -p /workspace/.ssh
chmod 700 /workspace/.ssh
chown -R root:root /workspace/.ssh

touch /workspace/.ssh/authorized_keys
chmod 600 /workspace/.ssh/authorized_keys
chown root:root /workspace/.ssh/authorized_keys

if ! grep -qxF "$PUBLIC_SSH_KEY" /workspace/.ssh/authorized_keys; then
  echo "$PUBLIC_SSH_KEY" >> /workspace/.ssh/authorized_keys
  echo "[SSH] Chiave aggiunta a /workspace/.ssh/authorized_keys"
else
  echo "[SSH] Chiave già presente"
fi

# Punta la home (~/.ssh) alla copia persistente
if [ -e "${HOME}/.ssh" ] || [ -L "${HOME}/.ssh" ]; then
  rm -rf "${HOME}/.ssh"
fi
ln -s /workspace/.ssh "${HOME}/.ssh"

# =========================
# AUTO-DETECT HOST/PORTE E STAMPA COMANDI SSH
# =========================
# Consenti override esterno:
SSH_PUBLIC_HOST="${SSH_PUBLIC_HOST:-}"
SSH_PUBLIC_PORT="${SSH_PUBLIC_PORT:-}"

detect_public_host() {
  # prova servizi pubblici (silenziosi in errore)
  local h=""
  h="$(curl -fsS -4 ifconfig.me 2>/dev/null || true)"
  if [ -z "$h" ]; then
    h="$(dig +short myip.opendns.com @resolver1.opendns.com 2>/dev/null || true)"
  fi
  echo "$h"
}

detect_public_port() {
  # prova env comuni; se non trovata, fallback 22
  for var in RUNPOD_SSH_PUBLIC_PORT RUNPOD_SSH_PORT SSH_PUBLIC_PORT SSH_PORT MAPPED_SSH_PORT; do
    if [ -n "${!var:-}" ]; then
      echo "${!var}"
      return 0
    fi
  done
  echo "22"
}

if [ -z "$SSH_PUBLIC_HOST" ]; then
  SSH_PUBLIC_HOST="$(detect_public_host || true)"
fi
if [ -z "$SSH_PUBLIC_PORT" ]; then
  SSH_PUBLIC_PORT="$(detect_public_port || true)"
fi

# Username corrente (di solito root)
SSH_USER="${USER:-root}"

echo "[SSH] ==== COMANDI SUGGERITI ===="
if [ -n "$SSH_PUBLIC_HOST" ]; then
  echo "ssh -i ~/.ssh/runpod -p ${SSH_PUBLIC_PORT} ${SSH_USER}@${SSH_PUBLIC_HOST} 'echo ok'"
  echo "ssh -i ~/.ssh/runpod -p ${SSH_PUBLIC_PORT} -N -L ${WEBUI_PORT}:localhost:${WEBUI_PORT} ${SSH_USER}@${SSH_PUBLIC_HOST}"
else
  echo "# Non sono riuscito a rilevare l'host pubblico."
  echo "# Sostituisci <HOST> e <PORTA> con i valori visti in UI (Direct TCP Ports)."
  echo "ssh -i ~/.ssh/runpod -p <PORTA> ${SSH_USER}@<HOST> 'echo ok'"
  echo "ssh -i ~/.ssh/runpod -p <PORTA> -N -L ${WEBUI_PORT}:localhost:${WEBUI_PORT} ${SSH_USER}@<HOST>"
  echo "# Oppure rilancia così:"
  echo "SSH_PUBLIC_HOST=69.30.85.177 SSH_PUBLIC_PORT=22174 ./ai-and-web-ui-installer.sh"
fi
echo "[SSH] ============================"

# =========================
# BOOTSTRAP
# =========================
echo "[BOOT] Update e tool di base"
apt-get update -y && apt-get install -y curl unzip git python3-pip dnsutils >/dev/null

echo "[BOOT] Install rclone"
curl -fsSL https://rclone.org/install.sh | bash

echo "[BOOT] Prepara directory"
mkdir -p /root/.config/rclone "${LOC_MODELS}" "${LOC_WEBUI}"

# =========================
# GOOGLE DRIVE SERVICE ACCOUNT (rclone)
# =========================
echo "[BOOT] Scrivo Service Account JSON (sostituisci con la tua chiave reale se necessario)"
cat >/root/sa.json <<'JSON'
{
  "type": "service_account",
  "project_id": "llm-ai-471019",
  "private_key_id": "REPLACE_WITH_NEW_KEY_ID",
  "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQCwIHzh2ZOnjJj5\nCgAXqTyjC2XNR4Phiv7VujC/qeEqtGDHl5uvpI6jsRqe0rS4HquD0AL0IQbVvkjC\n8XvCHmz6antJpTEqDpG+ylFqsktoSNFLQH5A5TqKH9QAM6oaihZtdZRvnMkfzhP2\nsYf13X6J2lktnS/HHBst0T3Xd73aKfV/L/Wbd9CInGkL3BQK8ckSnu2AwifRFqVb\n54JLo6wy2d3r0swhs23km2YCHtgyAvtlMs95VWnG6OdlcTptKZJ+3x7XtqQ6pMim\ntK98usCdyuEBEJ0oQh8sOHCMj4DRsJmG2DOmP01T+ldk6irT5PQkAo3Xwc6Gc2+b\ndX/iZ1ypAgMBAAECggEASJGqQvh+ISwKH5qiPR2LEXbxxCoySa0WoQNtcJtTXmAh\n/DsYd79q0kF3wXb55V8ltlLv1J0DDvCvVDthjbMxneBf2hFJd5W3MZB1CWxbK6XN\nLp9tJdoNS7ofhNHExdidsw4eUfqc2BD2ItA1P/W6XJxt4CCC/hwziqZLP8tjm069\nafE0P8z69NeQpAhSYu5OuLM6ewkau0yS3E0tC2MN0704+tjlWv5ZEwCTjVFQOkvF\nFApybYljsW0t2UfjQ7SJcVC6LjJTb1ptWsBGtIM5ol4ElhyDRqMBogskCeTZGX3I\niAAyzUfYsjj+dSRffUCkm1mhV/Zzfmdhpwl7ganpLQKBgQDdQVVyzpaD/h+gzrW9\nNmAKpRvjF9lEWVFG3mWH9LRLwsLdLfLw/Om1XKzNLG5dV4dwbqvevyRG8VGmdxSs\n96gm5sjBPHFZ560Ssg5taxOD10zevfy3GFqJ4Hu1vf/8t9BawPYxm9F1jr1bjoWr\nzq122HiTqWDDFN7FIl21qNgyIwKBgQDLyPQ6wiyrspz2smAoBeiKXHdvVgANKx5q\n0OWwk5cEYBiNBd63abuCTyDsYJQ0PzZQLTllPe8G4NhmiRzxdmEveHpet2nLINOy\niBLXs1e21Ium0AW2WIDIywYKhJrYXpARqspT5lJK/rO4OzMWcgDfv9e1z+sEvg0R\nGqqlZsbkwwKBgQDTCFblGzCrEr6+FYt4vp1aaeMwdnXP4FVKgCNdSsSRImHUrtfy\njXioeI2FYOSfeTYAwj6CRdPnKpMTcK8yz0D+Yc+HqAwBkZ0doOFr8d56OOfj6Fhb\nlwn8SjYUwfWg6P39IeFwrctaElyAMG9E0OvY2F4hkUNursBQTRgOhc43+wKBgQCc\nxRZl0ZUt7TVlb2obwBfZwTK8euuFNeOrhtL8mT33Rrn8W0Sv0u5GW/tW/SFmZC6z\nVWcvJIsqvnSbxOV4OHqhW0zAatc/Rhy13oqoV7al1zMr/CI42jMQxWb7VnIM/ApX\nHQ2Tp78tJG47z4cIwGE9wEcA/letiUtiGiKnJb7iowKBgG4GLlOK+tClnKgd/zFM\nGOaW2v7Zfgj+0np5ohfZVYwqPI54nRUi3B50N4py5zmqr9RWmo+KKd3EpYGuqsQo\nQ0ZtmH20QTC1z1uTFf7kbDF8YYViWBZ119zRojXQsVErkhT856mQFvDLxLWnOYg2\n8hp0meQcOuzbdsMOUd48MSAK\n-----END PRIVATE KEY-----\n",
  "client_email": "llm-ai-sa@llm-ai-471019.iam.gserviceaccount.com",
  "client_id": "114581115458024762833",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/llm-ai-sa%40llm-ai-471019.iam.gserviceaccount.com",
  "universe_domain": "googleapis.com"
}
JSON
chmod 600 /root/sa.json

cat >/root/.config/rclone/rclone.conf <<'RC'
[gdrive]
type = drive
scope = drive.readonly
service_account_file = /root/sa.json
RC

# =========================
# SYNC DA GOOGLE DRIVE (+ pre-check)
# =========================
G_MODELS="gdrive:${GDRIVE_ROOT}/${GDRIVE_MODELS_SUB}"
G_WEBUI="gdrive:${GDRIVE_ROOT}/${GDRIVE_WEBUI_SUB}"

echo "[CHECK] Verifica accesso alle path di Drive..."
rclone ls "${G_MODELS}" >/dev/null || { echo "[ERR] Modelli non accessibili: ${G_MODELS}"; exit 2; }
rclone ls "${G_WEBUI}"  >/dev/null || { echo "[ERR] WebUI non accessibile: ${G_WEBUI}"; exit 2; }

echo "[SYNC] Copio modelli da ${G_MODELS} -> ${LOC_MODELS}"
rclone copy "${G_MODELS}" "${LOC_MODELS}" \
  --transfers "${RCLONE_TRANSFERS}" --checkers "${RCLONE_CHECKERS}" \
  --drive-chunk-size "${RCLONE_CHUNK}" --progress || true

echo "[SYNC] Copio webui da ${G_WEBUI} -> ${LOC_WEBUI}"
rclone copy "${G_WEBUI}" "${LOC_WEBUI}" \
  --transfers "${RCLONE_TRANSFERS}" --checkers "${RCLONE_CHECKERS}" \
  --drive-chunk-size "${RCLONE_CHUNK}" --progress || true

echo "[DONE] Setup completato."
