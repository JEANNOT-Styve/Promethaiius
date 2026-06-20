#!/bin/bash
# Promethaiius - Start Script Optimisé pour DiffusionGemma (RTX 5090)

echo "=========================================="
echo "  PROMETHAIUS - Démarrage DiffusionGemma   "
echo "=========================================="
echo ""
echo "📌 Configuration officielle NousResearch :"
echo "   • Fenêtre contextuelle : MAX 65000 tokens (votre limite LM Studio)"
echo "   • VRAM allouée : ~22GB (70% de 31.5GB)"
echo "   • Attention backend : TRITON_ATTN"
echo "   • Diffusion config : canvas_length=256, max_denoising_steps=48"
echo ""

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
