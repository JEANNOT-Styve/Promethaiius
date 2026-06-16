# Promethaiius

Projet d'infrastructure AI locale pour la délégation de tâches de développement via des agents IA multiples (Claude Code, Codex, OpenCode), avec inférence optimisée via vLLM.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Hôte (Windows)                        │
│                                                             │
│  ┌─────────────────────┐    ┌──────────────────────────┐   │
│  │  promethaiius-hermes │    │  promethaiius-vllm       │   │
│  │  (God Container)     │───▶│  (vLLM + Gemma CUDA 130) │   │
│  │                      │    │                          │   │
│  │  • Hermes Agent      │    │  • qwen3.6-35b-a3b       │   │
│  │  • Claude Code       │    │  • DiffusionGemma        │   │
│  │  • Codex CLI         │    │  • API OpenAI :8000      │   │
│  │  • OpenCode CLI      │    │                          │   │
│  └─────────────────────┘    └──────────────────────────┘   │
│         │                         │                          │
│         ▼                         ▼                          │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  Volumes Persistants                                │    │
│  │  • ./hermes_data  → config, skills, SQLite          │    │
│  │  • ./workspace    → code source                     │    │
│  │  • ./models       → modèles GGUF/HF                 │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

## Prérequis

- **Windows 10/11** avec Docker Desktop v29+
- **GPU NVIDIA RTX 5090** (32GB VRAM) avec driver ≥ 550
- **CUDA 13.0** supporté (architecture Blackwell)
- **Git** installé

## Installation

### 1. Configurer les variables d'environnement

```bash
cp .env.example .env
```

Éditer `.env` et remplir tes clés API :

```env
HF_TOKEN=your_huggingface_token
OPENAI_API_KEY=your_openai_key
ANTHROPIC_API_KEY=your_anthropic_key
```

### 2. Placer les modèles

Placer le modèle `qwen3.6-35b-a3b` dans `./models/` :

```bash
# Via huggingface-cli
huggingface-cli download qwen/qwen3.6-35b-a3b --local-dir ./models/qwen3.6-35b-a3b
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

## Workflow Qwen3.6 → DiffusionGemma

1. **Qwen3.6-35B-A3B** (vLLM) : Raisonnement, planification, contexte
2. **DiffusionGemma** (vLLM) : Infilling de code uniquement

Le conteneur Hermes délègue automatiquement les requêtes d'inférence à vLLM via `http://vllm:8000/v1`.

## Commandes utiles

```bash
# Redémarrer
docker compose restart

# Arrêter
docker compose down

# Reconstruire l'image Hermes
docker compose up -d --build hermes

# Monitorer VRAM
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
- Docker Desktop doit avoir WSL2 backend activé

### Accès API vLLM
- Vérifier : `curl http://localhost:8000/health`
- Logs : `docker logs promethaiius-vllm`

## Notes

- Image vLLM : `gemma-x86_64-cu130` (CUDA 130 pour RTX 5090)
- Hermes conteneurisé pour délégation native sans installation hôte
- Isolation : QDrant/SonarQube exclus de l'infrastructure Promethaiius
