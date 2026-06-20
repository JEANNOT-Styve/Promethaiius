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
# Option A : Script automatisé
./start-promethaiius.sh

# Option B : Manuellement
docker compose pull
docker compose up -d
```

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

# Reconstruire l'image Hermes
docker compose up -d --build hermes

# Monitorer le GPU
nvidia-smi
```

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

- Image vLLM : `gemma-x86_64-cu130` (CUDA 130 pour GPU Blackwell)
- Hermes conteneurisé pour délégation native sans installation hôte
- Isolation : QDrant/SonarQube exclus de l'infrastructure Promethaiius
