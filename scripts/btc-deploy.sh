#!/bin/bash
# MiroFish VPS Deployment Script for BTC Market Simulation
# Run this on your VPS (Ubuntu/Debian)

set -e

echo "=== MiroFish BTC Market Simulator - VPS Deployment ==="
echo ""

# 1. Update system
echo "[1/7] Updating system packages..."
sudo apt update && sudo apt upgrade -y

# 2. Install prerequisites
echo "[2/7] Installing prerequisites..."
sudo apt install -y curl git python3.11 python3.11-venv python3-pip docker.io docker-compose nodejs npm

# 3. Clone the forked repo
echo "[3/7] Cloning MiroFish repo..."
cd ~
rm -rf MiroFish
git clone https://github.com/KofiRusu/MiroFish.git
cd MiroFish

# 4. Create .env from template
echo "[4/7] Setting up environment variables..."
echo ""
echo "=== CONFIGURATION REQUIRED ==="
echo "You need to set your API keys. Open the .env file and set:"
echo "  LLM_API_KEY=your_openai_key"
echo "  ZEP_API_KEY=your_zep_key"
echo ""
echo "Get OpenAI key: https://platform.openai.com/api-keys"
echo "Get Zep key: https://app.getzep.com/"
echo ""
echo "PAUSING for manual .env configuration..."
echo "Press Enter when .env is ready, or edit it manually:"
echo "  nano .env"
read -p "Ready to continue? (press Enter) "

# 5. Install dependencies
echo "[5/7] Installing dependencies..."
npm run setup:all

# 6. Start services via Docker
echo "[6/7] Starting MiroFish with Docker..."
docker compose up -d

# 7. Wait and verify
echo "[7/7] Waiting for services to start..."
sleep 15

# Check if services are running
echo ""
echo "=== DEPLOYMENT COMPLETE ==="
echo ""
echo "MiroFish should be running at:"
echo "  Frontend: http://localhost:3000"
echo "  Backend:  http://localhost:5001"
echo ""
echo "To access from external IP, use SSH tunnel:"
echo "  ssh -L 3000:localhost:3000 -L 5001:localhost:5001 user@your-vps-ip"
echo ""
echo "Then open http://localhost:3000 in your browser"
echo ""
echo "Next steps:"
echo "  1. Upload seed-data/btc-market-research.md via the UI"
echo "  2. Run the simulation with these API calls:"
echo "  3. See scripts/btc-simulate.sh for the full simulation pipeline"
echo ""

# Show logs
echo "View logs: docker compose logs -f"
echo "Stop services: docker compose down"
