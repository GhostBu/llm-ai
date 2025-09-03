cd /workspace

apt-get update -y && apt-get install -y nano

nano ai-and-web-ui-installer.sh

#!/usr/bin/env bash
set -euo pipefail

# =========================
# CONFIG — VALORI FISSI
# =========================
# Percorsi su Google Drive (condivisi al SA come "Lettore")
GDRIVE_ROOT="programming/imm-gen-ai/llm-ai"
GDRIVE_MODELS_SUB="models/OpenHermes-2.5-Mistral-7B"
GDRIVE_WEBUI_SUB="text-generation-webui-oobabooga"

# Porte e credenziali WebUI
WEBUI_PORT="7860"
WEBUI_AUTH_USER="Marco"        # TODO
WEBUI_AUTH_PASS="gggg9999"  # TODO

# Percorsi locali sul Pod
LOC_ROOT="/workspace"
LOC_MODELS="${LOC_ROOT}/models"
LOC_WEBUI="${LOC_ROOT}/webui"

# Rclone tuning
RCLONE_TRANSFERS="8"
RCLONE_CHECKERS="16"
RCLONE_CHUNK="128M"

# =========================
# BOOTSTRAP
# =========================
echo "[BOOT] Update and base tools"
apt-get update -y && apt-get install -y curl unzip git python3-pip

echo "[BOOT] Install rclone"
curl -fsSL https://rclone.org/install.sh | bash

echo "[BOOT] Write Service Account key"
mkdir -p /root/.config/rclone "${LOC_MODELS}" "${LOC_WEBUI}"

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

echo "[CHECK] Listing Drive paths to verify access..."
rclone ls "${G_MODELS}" >/dev/null || { echo "[ERR] Modelli non accessibili: ${G_MODELS}"; exit 2; }
rclone ls "${G_WEBUI}"  >/dev/null || { echo "[ERR] WebUI non accessibile: ${G_WEBUI}"; exit 2; }

echo "[SYNC] Copy models from ${G_MODELS}"
rclone copy "${G_MODELS}" "${LOC_MODELS}" \
  --transfers "${RCLONE_TRANSFERS}" --checkers "${RCLONE_CHECKERS}" \
  --drive-chunk-size "${RCLONE_CHUNK}" --progress || true

echo "[SYNC] Copy webui from ${G_WEBUI}"
rclone copy "${G_WEBUI}" "${LOC_WEBUI}" \
  --transfers "${RCLONE_TRANSFERS}" --checkers "${RCLONE_CHECKERS}" \
  --drive-chunk-size "${RCLONE_CHUNK}" --progress || true

#echo "[SETUP] Python upgrade"
#python3 -m pip install --upgrade pip
#
# =========================
# PYTORCH & DEPENDENCIES
# =========================
#echo "[CUDA] Checking GPU availability..."
#if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
#  echo "[CUDA] GPU detected. Installing PyTorch CUDA (cu121)..."
#  pip install --upgrade torch --index-url https://download.pytorch.org/whl/cu121
#else
#  echo "[CUDA] GPU NOT detected. Installing PyTorch CPU build..."
#  pip install --upgrade torch --index-url https://download.pytorch.org/whl/cpu
#fi

# Requisiti Text Generation WebUI: usa il file 'requirements/full' se esiste,
# altrimenti 'requirements.txt' standard, altrimenti tentativo best-effort su transformers/accelerate
REQ_FILE=""
if [ -f "${LOC_WEBUI}/re_]()
