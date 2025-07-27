#!/bin/bash

set -e
set -o pipefail
LOGFILE=~/setup_textgen_ai.log
exec > >(tee -i "$LOGFILE") 2>&1

MODEL_NAME="OpenHermes-2.5-Mistral-7B"
DRIVE_PATH="gdrive:/programming/imm-gen-ai/llm-ai/models"
LOCAL_MOUNT=~/drive
LOCAL_DEST=~/textgen/models
MODEL_DEST="$LOCAL_DEST/$MODEL_NAME"

echo "[INFO] Inizio setup - $(date)"

# STEP 1: DEPENDENCIES
echo "[STEP] Aggiorno pacchetti e installo tool..."
apt update -y && apt install -y git unzip wget python3 python3-pip curl || {
    echo "[FATAL] Installazione pacchetti base fallita."; exit 10;
}

# STEP 2: RCLONE INSTALL
echo "[STEP] Verifica/installazione rclone..."
if ! command -v rclone >/dev/null 2>&1; then
    echo "[INFO] rclone non trovato, lo installo..."
    curl -s https://rclone.org/install.sh | bash || {
        echo "[FATAL] Installazione rclone fallita."; exit 11;
    }
else
    echo "[INFO] rclone già installato."
fi


# STEP 3: CONFIG RCLONE
if ! rclone listremotes | grep -q "^gdrive:"; then
    echo "[STEP] Configurazione gdrive mancante, inizio configurazione automatica..."

    # Crea un profilo temporaneo vuoto se non esiste
    mkdir -p ~/.config/rclone

    echo "[INFO] Avvio configurazione guidata rclone per Google Drive"
    echo "[AZIONE] Ti verrà mostrato un link. Copialo nel browser sul tuo PC, autorizza, poi copia il codice nel terminale."

    rclone config create gdrive drive scope=drive || {
        echo "[FATAL] Configurazione guidata fallita."; exit 12;
    }

    echo "[INFO] Configurazione gdrive completata."
else
    echo "[INFO] gdrive già configurato, salto configurazione."
fi

# STEP 4: MOUNT GOOGLE DRIVE
echo "[STEP] Mount Google Drive in $LOCAL_MOUNT"
mkdir -p "$LOCAL_MOUNT"
rclone mount "$DRIVE_PATH" "$LOCAL_MOUNT" --daemon || {
    echo "[FATAL] Mount fallito."; exit 13;
}
sleep 5

# STEP 5: COPIA MODELLO
if [ ! -d "$MODEL_DEST" ]; then
    echo "[STEP] Copia modello $MODEL_NAME in locale..."
    mkdir -p "$LOCAL_DEST"
    cp -r "$LOCAL_MOUNT/$MODEL_NAME" "$MODEL_DEST" || {
        echo "[FATAL] Copia modello fallita."; exit 14;
    }
else
    echo "[INFO] Modello già presente, salto la copia."
fi

# CHECK FILE
if [ ! -f "$MODEL_DEST/config.json" ]; then
    echo "[FATAL] Il modello non contiene config.json. Verifica il contenuto in $MODEL_DEST"
    exit 15
fi

# STEP 6: CLONA TEXTGEN WEBUI
cd ~
if [ ! -d textgen ]; then
    echo "[STEP] Clonazione repo Text Generation WebUI..."
    git clone https://github.com/oobabooga/text-generation-webui.git textgen || {
        echo "[FATAL] Clonazione repo fallita."; exit 16;
    }
else
    echo "[INFO] Directory textgen già presente."
fi

# STEP 7: INSTALL REQUIREMENTS
cd ~/textgen
echo "[STEP] Installazione dipendenze Python..."
pip install -r requirements.txt || {
    echo "[FATAL] Installazione requirements.txt fallita."; exit 17;
}

# STEP 8: AVVIO SERVER
echo "[STEP] Avvio WebUI sulla porta 7860..."
python3 server.py --model "$MODEL_NAME" --api --listen || {
    echo "[FATAL] Server Python non partito."; exit 18;
}
