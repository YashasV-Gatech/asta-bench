#!/bin/bash

# --- 1. Increase the sandbox memory limit ---
COMPOSE_FILE="astabench/util/sandbox/sandbox_compose.yaml"
if [ -f "$COMPOSE_FILE" ]; then
  # Check if the memory limit is set to 0.5gb and replace it with 8gb
  if grep -q "mem_limit: 0.5gb" "$COMPOSE_FILE"; then
    sed -i 's/mem_limit: 0.5gb/mem_limit: 8gb/g' "$COMPOSE_FILE"
    echo "Updated $COMPOSE_FILE: Increased mem_limit to 8gb."
  else
    echo "$COMPOSE_FILE memory limit is not 0.5gb. No change made."
  fi
else
  echo "Warning: $COMPOSE_FILE not found. Cannot increase memory limit."
fi

# --- 2. Install uv in the sandbox Dockerfile ---

# Define the installation commands for UV
UV_INSTALL=$(cat << 'EOF'

# Install uv
RUN curl -fsSL https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.cargo/bin:$PATH"
EOF
)

DOCKERFILE="astabench/util/sandbox/Dockerfile"
if [ -f "$DOCKERFILE" ]; then
  if ! grep -q "astral.sh/uv/install.sh" "$DOCKERFILE"; then
    # Use awk to insert after the FROM line (portable method)
    awk -v install="$UV_INSTALL" '/^FROM python:3.11-bookworm/ {print; print install; next} 1' "$DOCKERFILE" > "${DOCKERFILE}.tmp" && mv "${DOCKERFILE}.tmp" "$DOCKERFILE"
    echo "Updated $DOCKERFILE: Added uv installation."
  else
    echo "$DOCKERFILE already includes uv."
  fi
else
  echo "Warning: $DOCKERFILE not found. Cannot install uv."
fi

# --- 3. Update task definitions to use 'uv pip install' ---
FILES_TO_UPDATE=(
  "astabench/evals/inspect_eval_wrappers/ds1000.py"
  "astabench/evals/super/task.py"
  "astabench/evals/inspect_eval_wrappers/core_bench.py"
)

for FILE in "${FILES_TO_UPDATE[@]}"; do
  if [ -f "$FILE" ]; then
    # Replace the pip install command with uv pip install
    sed -i 's/+ "RUN pip install --no-cache-dir -r /+ "RUN uv pip install --no-cache-dir -r /g' "$FILE"
    echo "Updated $FILE: Switched to uv pip install."
  else
    # These files might not exist if the repository is not fully initialized
    echo "Warning: File not found: $FILE"
  fi
done

echo "Patches applied successfully."