# MiroFish - BTC Market Swarm Intelligence Simulator

Fork of [MiroFish](https://github.com/666ghj/MiroFish) adapted for Bitcoin price movement prediction.

## What This Fork Adds

1. **`.env`** - Pre-configured OpenAI environment template for BTC simulations
2. **`seed-data/btc-market-research.md`** - Comprehensive BTC market research covering:
   - Price history and halving cycle analysis
   - On-chain metrics (exchange flows, SOPR, MVRV, OI, NUPL)
   - Macro context (Fed policy, DXY, inflation)
   - ETF and institutional flows
   - Market sentiment and social data
   - 8+ agent personas (BTC maximalist, fund manager, whale, miner, Fed Chair, etc.)
   - Bull and bear case arguments
3. **`scripts/btc-deploy.sh`** - One-click VPS deployment
4. **`scripts/btc-simulate.sh`** - Full simulation pipeline (upload -> graph -> simulate -> report)

## Quick Start

### Step 1: Deploy to your VPS
```bash
# SSH into your VPS
ssh user@vps-ip

# Clone and run deployment script
wget https://raw.githubusercontent.com/KofiRusu/MiroFish/main/scripts/btc-deploy.sh
chmod +x btc-deploy.sh
./btc-deploy.sh
```

The script will:
- Install all dependencies (Docker, Python, Node.js)
- Clone this fork
- Set up the `.env` file (you'll be prompted for API keys)
- Start MiroFish via Docker

### Step 2: Get API Keys
- **OpenAI**: https://platform.openai.com/api-keys
- **Zep Cloud** (free): https://app.getzep.com/

Add them to your `.env` file:
```
LLM_API_KEY=sk-your-openai-key
ZEP_API_KEY=your-zep-key
```

### Step 3: Run the BTC Simulation
```bash
cd ~/MiroFish
chmod +x scripts/btc-simulate.sh
./scripts/btc-simulate.sh
```

The simulation pipeline will:
1. Upload the BTC seed data
2. Build the knowledge graph
3. Create and prepare the simulation
4. Run 50 rounds of dual-platform agent debate
5. Generate a prediction report
6. Download the report as `btc-prediction-report.md`

Estimated time: 30-60 minutes depending on LLM speed.
Estimated cost: ~$5-15 with gpt-4o-mini.

### Step 4: Chat with the Report Agent
After the simulation completes, you can query the report agent:
```bash
curl -X POST "http://localhost:5001/api/report/chat" \
  -H "Content-Type: application/json" \
  -d '{"simulation_id":"sim_xxxxx","message":"Will BTC break ATH in Q3?","chat_history":[]}'
```

## Accessing the Web UI

From your local machine (SSH tunnel):
```bash
ssh -L 3000:localhost:3000 -L 5001:localhost:5001 user@vps-ip
```
Then open: http://localhost:3000

## Simulation Parameters

| Parameter | Default | Options |
|-----------|---------|--------|
| Rounds | 50 | 10 (quick) / 50 (standard) / 120 (deep) |
| Platforms | Twitter + Reddit | Either or both |
| LLM Model | gpt-4o-mini | gpt-4o, claude, etc. |
| Chunk Size | 500 | Adjust for larger seed docs |

To change rounds, edit `.env`:
```
OASIS_DEFAULT_MAX_ROUNDS=120
```

## Cost Estimates

| Model | Rounds | Est. Cost |
|-------|--------|----------|
| gpt-4o-mini | 50 | ~$5-8 |
| gpt-4o | 50 | ~$20-30 |
| gpt-4o-mini | 120 | ~$12-18 |
| gpt-4o | 120 | ~$50-70 |

## Management

```bash
# View logs
docker compose logs -f

# Stop services
docker compose down

# Restart services
docker compose up -d

# Reset and start fresh
docker compose down -v
rm -rf backend/uploads
```
