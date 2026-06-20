#!/bin/bash
# Promethaiius - Start Script Optimisé pour DiffusionGemma (RTX 5090)

echo "=========================================="
echo "  PROMETHAIUS - Démarrage DiffusionGemma   "
echo "=========================================="
echo ""
echo "📌 Configuration officielle NousResearch :"
echo "   • Fenêtre contextuelle : MAX 65000 tokens (votre limite LM Studio)"
echo "   • VRAM allouée : ~28GB (90% de 31.5GB)"
echo "   • Attention backend : TRITON_ATTN"
echo "   • Diffusion config : canvas_length=256, max_denoising_steps=48"
echo ""

# Vérifier Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker n'est pas installé. Veuillez installer Docker Desktop d'abord."
    exit 1
fi

# Vérifier NVIDIA drivers
if command -v nvidia-smi &> /dev/null; then
    GPU_INFO=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader)
    echo "✅ GPU détecté : $GPU_INFO"
else
    echo "⚠️  Aucun GPU NVIDIA détecté - vLLM ne fonctionnera pas !"
fi

echo ""
echo "=========================================="
echo "  Configuration DiffusionGemma            "
echo "=========================================="
echo ""

# Arrêter LM Studio si en cours d'utilisation
echo "🔄 Vérification des conflits GPU..."
if docker ps | grep -q promethaiius-vllm; then
    echo "⚠️  vLLM est déjà en cours d'exécution !"
    read -p "Voulez-vous le redémarrer ? (y/n) " -n 1 -t
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker compose stop promethaiius-vllm
        sleep 2
    else
        exit 0
    fi
fi

# Pull les dernières images
echo ""
echo "📥 Téléchargement des images Docker..."
docker compose pull

# Créer les répertoires nécessaires
mkdir -p models hermes_data workspace

# Démarrer les services
echo ""
echo "🚀 Démarrage de Promethaiius..."
docker compose up -d

# Vérifier le statut
echo ""
echo "📊 Statut des services :"
docker compose ps

# Attendre que vLLM soit prêt (healthcheck)
echo ""
echo "⏳ Attente du démarrage de vLLM (2-3 min pour le premier lancement)..."
sleep 15

# Vérifier si vLLM est prêt
MAX_RETRIES=60
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -s http://localhost:8000/v1/models | grep -q "diffusiongemma"; then
        echo ""
        echo "✅ vLLM est prêt !"
        echo ""
        echo "🎉 Promethaiius est opérationnel !"
        echo "   • API vLLM : http://localhost:8000/v1"
        echo "   • Conteneur Hermes : promethaiius-hermes"
        exit 0
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    sleep 5
done

echo ""
echo "⚠️  vLLM n'est pas prêt après $(($MAX_RETRIES * 5)) secondes."
echo "   Vérifiez les logs : docker compose logs -f promethaiius-vllm"
exit 1
