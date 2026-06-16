#!/bin/bash
# Promethaiius - Start Script

# Check prerequisites
if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Please install Docker Desktop first."
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Create necessary directories
mkdir -p models hermes_data workspace

# Pull latest images
echo "Pulling latest images..."
docker compose pull

# Start services
echo "Starting Promethaiius services..."
docker compose up -d

# Check service status
echo "Checking service status..."
docker compose ps

echo "Promethaiius is running!"
echo "vLLM API: http://localhost:8000/v1"
echo "Hermes container: promethaiius-hermes"