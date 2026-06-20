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

**Fenêtre contextuelle limitée à 65000 tokens maximum** - respectez cette limite !

#### Paramètres optimisés pour 31.5GB VRAM :
- `--max-model-len 65000` : Fenêtre contextuelle maximale (ne pas dépasser !)
- `--gpu-memory-utilization 0.65` : 65% de la VRAM (laisser 10GB pour le système)
- `--attention-backend FLASH_ATTENTION` : Plus économe en mémoire que TRITON_ATTN
- `--max-num-seqs 2` : Limité pour éviter les problèmes de fragmentation
- `--diffusion-config` : Configuration réduite (canvas_length: 128, max_denoising_steps: 32)

#### ⚠️ Recommandations critiques de la communauté IA :

**1. Ne jamais dépasser 65000 tokens**
   - La fenêtre contextuelle est limitée par votre modèle LM Studio en backend
   - Dépasser cette limite provoquera des erreurs OOM (Out Of Memory)

**2. Gestion VRAM sur RTX 5090 (31.5GB)**
   - Laissez toujours ~10-12GB de marge pour le système et les caches
   - Fermez LM Studio avant de démarrer vLLM si possible
   - Utilisez `--gpu-memory-utilization 0.65` maximum

**3. Optimisations mémoire**
   - FLASH_ATTENTION est plus économe que TRITON_ATTN sur GPU Blackwell
   - Réduisez `canvas_length` et `max_denoising_steps` pour les tâches légères
   - Évitez les prompts très longs (> 40k tokens) sauf nécessité

**4. Workflow recommandé**
   ```bash
   # Vérifier VRAM disponible
   nvidia-smi
   
   # Arrêter LM Studio si en cours d'utilisation
   docker compose stop promethaiius-vllm
   
   # Démarrer vLLM avec la configuration optimisée
   docker compose up -d
   
   # Attendre le healthcheck (2-3 min pour le premier démarrage)
   docker logs -f promethaiius-vllm | grep "Ready for requests"
   ```

**5. Dépannage VRAM**
   - Erreur OOM : réduire `--gpu-memory-utilization` à 0.60
   - Lenteur excessive : vérifier que le modèle est bien chargé en VRAM (pas en RAM)
   - Erreurs CUDA : mettre à jour les drivers NVIDIA >= 550

### Infrastructure actuelle

- Image vLLM : `gemma-x86_64-cu130` (CUDA 13.0 pour GPU Blackwell)
- Hermes conteneurisé pour délégation native sans installation hôte
- Isolation : QDrant/SonarQube exclus de l'infrastructure Promethaiius
