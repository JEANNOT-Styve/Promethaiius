# Promethaiius

Infrastructure AI locale pour la délégation de tâches de développement via des agents IA multiples (Claude Code, Codex, OpenCode), avec inférence optimisée via vLLM.

## Architecture

```
+-------------------------------------------------------------+
|                        Hôte (Windows / Linux)                  |
|                                                             |
|  +-------------------+    +-------------------------------+  |
|  | promethaiius-hermes|    | promethaiius-vllm            |  |
|  | (God Container)   |---->| (vLLM + CUDA 130)            |  |
|  |                   |    |                               |  |
|  |  - Hermes Agent   |    |  - Modèle configurable        |  |
|  |  - Claude Code    |    |  - API OpenAI :8000           |  |
|  |  - Codex CLI      |    |                               |  |
|  |  - OpenCode CLI   |    |                               |  |
|  +-------------------+    +-------------------------------+  |
|         |                         |                             |
|         v                         v                             |
|  +-------------------------------------------------------------+  |
|  |  Volumes Persistants                                        |  |
|  |  - ./hermes_data  -> config, skills, SQLite                 |  |
|  |  - ./workspace    -> code source                            |  |
|  |  - MODELS_DIR   -> modèles GGUF/HF                          |  |
|  +-------------------------------------------------------------+  |
+-------------------------------------------------------------+
```

## Prérequis

- **Windows 10/11 ou Linux** avec Docker Desktop v29+ (ou Docker Engine)
- **GPU NVIDIA compatible CUDA 13.0** (architecture Blackwell ou supérieure)
- **Driver NVIDIA >= 550**
- **Git** installé

## Installation

### 1. Configurer les variables d'environnement

```bash
cp .env.example .env
```

Éditer `.env` et remplir tes clés API :

```env
MODELS_DIR=/chemin/vers/tes/models
HF_TOKEN=ton_token_huggingface
OPENAI_API_KEY=ta_clé_openai
ANTHROPIC_API_KEY=ta_clé_anthropic
```

- `MODELS_DIR` : répertoire contenant tes modèles (peut être sur un autre disque)
- Les clés API sont nécessaires pour les agents de codage

### 2. Placer les modèles

Placer le modèle souhaité dans le répertoire indiqué par `MODELS_DIR` :

```bash
# Via huggingface-cli
huggingface-cli download <repo/model> --local-dir <MODELS_DIR>/<model-name>
```

### 3. Démarrer l'infrastructure

```bash
# Script automatisé avec vérifications (recommandé)
./start-promethaiius.sh

# Ou démarrage manuel
docker compose pull
docker compose up -d
```

**Premier démarrage :** Attendez 2-3 minutes pour le chargement du modèle DiffusionGemma.

## Vérification

```bash
# Status des conteneurs
docker compose ps

# Logs vLLM
docker logs -f promethaiius-vllm

# Test API vLLM
curl http://localhost:8000/v1/models
```

## Workflow de modéles

1. **Modèle principal** (vLLM) : Raisonnement, planification, contexte
2. **Modèle de code** (vLLM) : Infilling de code uniquement

Le conteneur Hermes délègue automatiquement les requêtes d'inférence à vLLM via `http://vllm:8000/v1`.

## Commandes utiles

```bash
# Redémarrer
docker compose restart

# Arrêter
docker compose down

# Reconstruire l'image Hermes uniquement
docker compose up -d --build hermes

# Monitorer le GPU
nvidia-smi

# Vérifier la santé de vLLM
curl http://localhost:8000/v1/models

# Voir les logs en temps réel
docker logs -f promethaiius-vllm
```

### ⚠️ IMPORTANT : Limites de contexte

**Ne jamais dépasser 65000 tokens !**

- Votre modèle LM Studio backend limite la fenêtre à 65000 tokens
- Dépasser cette limite provoquera des erreurs OOM (Out Of Memory)
- Pour les prompts très longs, utilisez le chunking ou résumez d'abord

## Structure du projet

```
Promethaiius/
├── docker-compose.yml    # Infrastructure Docker
├── Dockerfile.hermes     # Image Hermes Agent
├── .env.example          # Template variables d'environnement
├── start-promethaiius.sh # Script de démarrage
├── models/               # Modèles IA (monté en volume)
├── hermes_data/          # Config Hermes (monté en volume)
├── workspace/            # Code source (monté en volume)
└── README.md             # Ce fichier
```

## Utiliser le service Hermes

Une fois l'infrastructure démarrée, Hermes est accessible via plusieurs interfaces :

### 1. Dashboard web (recommandé)

```bash
# Ouvrir le dashboard dans ton navigateur
start http://localhost:9119
```

> Le dashboard permet de gérer les conversations, skills, cron jobs, et l'état des conteneurs.

### 2. Interface CLI (en exécutant des commandes dans le conteneur)

```bash
# Entrer dans le shell du conteneur Hermes
docker exec -it promethaiius-hermes bash

# Utiliser la CLI Hermes depuis l'intérieur
hermes --help
hermes config get
hermes skills list
```

### 3. API Gateway (port 9119)

Hermes expose une API REST sur le port `9119`. Les endpoints principaux :

```bash
# Health check
curl http://localhost:9119/health

# Liste des channels connectés
curl http://localhost:9119/api/channels

# Envoyer un message (via le gateway)
curl -X POST http://localhost:9119/api/messages \
  -H "Content-Type: application/json" \
  -d '{"text": "Bonjour", "source": "web"}'
```

### 4. Telegram (si configuré)

Si `TELEGRAM_BOT_TOKEN` est défini dans `.env`, Hermes est aussi accessible via Telegram. Le bot répond automatiquement aux messages envoyés au bot.

### Flux d'inférence

Le conteneur Hermes délègue automatiquement les requêtes d'inférence à vLLM via `http://vllm:8000/v1`. Tu n'as rien à configurer de plus — Hermes utilise l'API OpenAI compatible de vLLM par défaut.

## Dépannage

### Problèmes VRAM
- Réduire `--gpu-memory-utilization` dans `docker-compose.yml`
- Fermer LM Studio avant de démarrer vLLM

### Erreurs CUDA
- Vérifier : `nvidia-smi` (driver compatible CUDA 13)
- Docker Desktop doit avoir WSL2 backend activé (sur Windows)

### Accès API vLLM
- Vérifier : `curl http://localhost:8000/health`
- Logs : `docker logs promethaiius-vllm`

## Notes

### Configuration DiffusionGemma (RTX 5090 31.5GB VRAM)

**Fenêtre contextuelle réduite à 65000 tokens maximum** - respectez cette limite !

#### Paramètres officiels NousResearch :
- `--max-model-len 65000` : Fenêtre contextuelle maximale (réduite de 100k pour respecter votre limite LM Studio)
- `--gpu-memory-utilization 0.70` : 70% de la VRAM (~22GB sur 31.5GB)
- `--attention-backend TRITON_ATTN` : Backend officiel recommandé par NousResearch
- `--diffusion-config '{"canvas_length": 256, "max_denoising_steps": 48}'` : Configuration complète pour diffusion
- `--max-num-seqs 4` : Support multi-séquences (recommandé)

#### ⚠️ IMPORTANT : Votre limite LM Studio

Votre modèle LM Studio backend limite la fenêtre à **65000 tokens maximum**. La configuration vLLM ci-dessus est optimisée pour DiffusionGemma, mais vous devez respecter cette limite imposée par votre backend.

**Recommandations de la communauté :**
1. Ne jamais dépasser 65000 tokens (limite LM Studio)
2. Utilisez TRITON_ATTN comme recommandé par NousResearch (pas FLASH_ATTENTION)
3. Configuration diffusion complète : canvas_length=256, max_denoising_steps=48
4. Laissez ~10GB de marge VRAM pour le système

#### Workflow recommandé :
```bash
# Vérifier VRAM disponible
nvidia-smi

# Arrêter LM Studio si en cours d'utilisation
docker compose stop promethaiius-vllm

# Démarrer vLLM avec la configuration officielle
docker compose up -d

# Attendre le healthcheck (2-3 min pour le premier démarrage)
docker logs -f promethaiius-vllm | grep "Ready for requests"
```

#### Dépannage VRAM :
- Erreur OOM : réduire `--gpu-memory-utilization` à 0.65
- Lenteur excessive : vérifier que le modèle est bien chargé en VRAM (pas en RAM)
- Erreurs CUDA : mettre à jour les drivers NVIDIA >= 550

### Infrastructure actuelle

- Image vLLM : `gemma-x86_64-cu130` (CUDA 13.0 pour GPU Blackwell)
- Hermes conteneurisé pour délégation native sans installation hôte
- Isolation : QDrant/SonarQube exclus de l'infrastructure Promethaiius
