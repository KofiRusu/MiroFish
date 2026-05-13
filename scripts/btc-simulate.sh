#!/bin/bash
# MiroFish BTC Market Simulation Runner
# Runs the complete pipeline: upload seed data -> build graph -> simulate -> report
# Run after btc-deploy.sh and once MiroFish is running

set -e

BASE_URL="http://localhost:5001/api"
SEED_FILE="seed-data/btc-market-research.md"

echo "=== MiroFish BTC Market Simulation Runner ==="
echo ""

# Step 1: Upload seed data and generate ontology
echo "[Step 1/6] Uploading BTC seed data and generating ontology..."
PROJECT_RESPONSE=$(curl -s -F "files=@${SEED_FILE}" \
  -F "simulation_requirement=Predict BTC price movement over the next 30, 90, and 180 days. What is the probability of a new all-time high within 6 months? Consider on-chain metrics, macro conditions, ETF flows, mining economics, and market sentiment." \
  -F "project_name=BTC Market Simulation" \
  -F "additional_context=BTC/USD. Post-halving cycle analysis. Focus on price direction and key catalysts." \
  "${BASE_URL}/ontology/generate")

PROJECT_ID=$(echo "$PROJECT_RESPONSE" | python3 -c "import sys,json; data=json.load(sys.stdin); print(data['data']['project_id'] if data.get('success') else 'ERROR')")

echo "Project ID: ${PROJECT_ID}"
if [ "$PROJECT_ID" = "ERROR" ]; then
  echo "Failed to create project. Response: $PROJECT_RESPONSE"
  exit 1
fi

# Step 2: Build the knowledge graph
echo "[Step 2/6] Building knowledge graph..."
BUILD_RESPONSE=$(curl -s -X POST "${BASE_URL}/build" \
  -H "Content-Type: application/json" \
  -d "{\"project_id\":\"${PROJECT_ID}\",\"chunk_size\":500,\"chunk_overlap\":50}")

TASK_ID=$(echo "$BUILD_RESPONSE" | python3 -c "import sys,json; data=json.load(sys.stdin); print(data.get('task_id','ERROR'))" 2>/dev/null || echo "ERROR")

echo "Graph build task ID: ${TASK_ID}"

# Poll for completion
while true; do
  STATUS=$(curl -s "${BASE_URL}/task/${TASK_ID}" | python3 -c "import sys,json; data=json.load(sys.stdin); d=data.get('data',data); print(d.get('status','unknown'))" 2>/dev/null || echo "unknown")
  echo "  Graph build status: ${STATUS}..."
  if [ "$STATUS" = "completed" ]; then
    echo "  Graph build completed!"
    break
  elif [ "$STATUS" = "failed" ]; then
    echo "  Graph build FAILED"
    exit 1
  fi
  sleep 10
done

# Get the graph ID
GRAPH_RESPONSE=$(curl -s "${BASE_URL}/project/${PROJECT_ID}")
GRAPH_ID=$(echo "$GRAPH_RESPONSE" | python3 -c "import sys,json; data=json.load(sys.stdin); graphs=data.get('data',{}).get('graphs',[]); print(graphs[0]['graph_id'] if graphs else 'ERROR')" 2>/dev/null || echo "ERROR")
echo "Graph ID: ${GRAPH_ID}"

if [ "$GRAPH_ID" = "ERROR" ]; then
  echo "Could not retrieve graph ID. Response: $GRAPH_RESPONSE"
  exit 1
fi

# Step 3: Create simulation
echo "[Step 3/6] Creating simulation..."
SIM_RESPONSE=$(curl -s -X POST "${BASE_URL}/simulation/create" \
  -H "Content-Type: application/json" \
  -d "{\"project_id\":\"${PROJECT_ID}\",\"graph_id\":\"${GRAPH_ID}\",\"enable_twitter\":true,\"enable_reddit\":true}")

SIMULATION_ID=$(echo "$SIM_RESPONSE" | python3 -c "import sys,json; data=json.load(sys.stdin); sim=data.get('data',{}); print(sim.get('simulation_id',sim.get('id','ERROR')))" 2>/dev/null || echo "ERROR")

echo "Simulation ID: ${SIMULATION_ID}"

if [ "$SIMULATION_ID" = "ERROR" ]; then
  echo "Failed to create simulation. Response: $SIM_RESPONSE"
  exit 1
fi

# Step 4: Prepare simulation environment (generate agent personas)
echo "[Step 4/6] Preparing simulation environment..."
PREP_RESPONSE=$(curl -s -X POST "${BASE_URL}/simulation/prepare" \
  -H "Content-Type: application/json" \
  -d "{\"simulation_id\":\"${SIMULATION_ID}\",\"entity_types\":[],\"use_llm_for_profiles\":true,\"parallel_profile_count\":5,\"force_regenerate\":false}")

PREP_TASK=$(echo "$PREP_RESPONSE" | python3 -c "import sys,json; data=json.load(sys.stdin); print(data.get('task_id','ERROR'))" 2>/dev/null || echo "ERROR")

echo "Prep task ID: ${PREP_TASK}"

# Poll for prep completion
while true; do
  STATUS=$(curl -s -X POST "${BASE_URL}/simulation/prepare/status" \
    -H "Content-Type: application/json" \
    -d "{\"task_id\":\"${PREP_TASK}\"}" | python3 -c "import sys,json; data=json.load(sys.stdin); d=data.get('data',data); print(d.get('status','unknown'))" 2>/dev/null || echo "unknown")
  echo "  Prep status: ${STATUS}..."
  if [ "$STATUS" = "ready" ] || [ "$STATUS" = "completed" ]; then
    echo "  Environment ready!"
    break
  elif [ "$STATUS" = "failed" ]; then
    echo "  Prep FAILED"
    exit 1
  fi
  sleep 10
done

# Step 5: Start simulation with 50 rounds
echo "[Step 5/6] Starting BTC market simulation (50 rounds, dual-platform)..."
START_RESPONSE=$(curl -s -X POST "${BASE_URL}/simulation/start" \
  -H "Content-Type: application/json" \
  -d "{\"simulation_id\":\"${SIMULATION_ID}\",\"platform\":\"parallel\",\"max_rounds\":50,\"enable_graph_memory_update\":true,\"force\":false}")

echo "Simulation started. Response: $START_RESPONSE"
echo ""
echo "  Running dual-platform simulation (Twitter + Reddit)..."
echo "  This may take 15-45 minutes depending on LLM response time."
echo "  Monitoring progress..."

# Monitor simulation progress
LAST_PROGRESS=""
while true; do
  SIM_STATUS=$(curl -s "${BASE_URL}/simulation/${SIMULATION_ID}" | python3 -c "import sys,json; data=json.load(sys.stdin); sim=data.get('data',{}); print(f\"round={sim.get('current_round','?')},status={sim.get('status','?')}\")" 2>/dev/null || echo "unknown")
  
  if [ "$SIM_STATUS" != "$LAST_PROGRESS" ]; then
    echo "  Progress: ${SIM_STATUS}"
    LAST_PROGRESS="$SIM_STATUS"
  fi
  
  SIM_STATE=$(curl -s "${BASE_URL}/simulation/${SIMULATION_ID}" | python3 -c "import sys,json; data=json.load(sys.stdin); print(data.get('data',{}).get('status','unknown'))" 2>/dev/null || echo "unknown")
  
  if [ "$SIM_STATE" = "completed" ] || [ "$SIM_STATE" = "finished" ]; then
    echo "  Simulation completed!"
    break
  elif [ "$SIM_STATE" = "failed" ]; then
    echo "  Simulation FAILED"
    exit 1
  fi
  sleep 30
done

# Step 6: Generate report
echo "[Step 6/6] Generating prediction report..."
REPORT_RESPONSE=$(curl -s -X POST "${BASE_URL}/report/generate" \
  -H "Content-Type: application/json" \
  -d "{\"simulation_id\":\"${SIMULATION_ID}\",\"force_regenerate\":false}")

REPORT_TASK=$(echo "$REPORT_RESPONSE" | python3 -c "import sys,json; data=json.load(sys.stdin); print(data.get('data',{}).get('task_id','ERROR'))" 2>/dev/null || echo "ERROR")

echo "Report task ID: ${REPORT_TASK}"

# Poll for report completion
while true; do
  STATUS=$(curl -s "${BASE_URL}/report/generate/status" \
    -X POST \
    -H "Content-Type: application/json" \
    -d "{\"task_id\":\"${REPORT_TASK}\"}" | python3 -c "import sys,json; data=json.load(sys.stdin); d=data.get('data',data); print(d.get('status','unknown'))" 2>/dev/null || echo "unknown")
  echo "  Report status: ${STATUS}..."
  if [ "$STATUS" = "completed" ]; then
    echo "  Report generated!"
    break
  elif [ "$STATUS" = "failed" ]; then
    echo "  Report generation FAILED"
    exit 1
  fi
  sleep 10
done

# Download the report
REPORT_DOWNLOAD=$(curl -s "${BASE_URL}/report/by-simulation/${SIMULATION_ID}")

REPORT_ID=$(echo "$REPORT_DOWNLOAD" | python3 -c "import sys,json; data=json.load(sys.stdin); report=data.get('data',{}); print(report.get('report_id','ERROR'))" 2>/dev/null || echo "ERROR")

echo "Report ID: ${REPORT_ID}"
curl -s "${BASE_URL}/report/${REPORT_ID}/download" -o "btc-prediction-report.md"

echo ""
echo "=== BTC MARKET SIMULATION COMPLETE ==="
echo ""
echo "Results:"
echo "  Project ID: ${PROJECT_ID}"
echo "  Graph ID: ${GRAPH_ID}"
echo "  Simulation ID: ${SIMULATION_ID}"
echo "  Report: btc-prediction-report.md"
echo ""
echo "To chat with the Report Agent:"
curl -X POST "${BASE_URL}/report/chat" \
  -H "Content-Type: application/json" \
  -d "{\"simulation_id\":\"${SIMULATION_ID}\",\"message\":\"What is your BTC price prediction for the next 90 days and what factors influenced it most?\",\"chat_history\":[]}" | python3 -m json.tool
