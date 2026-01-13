#!/bin/bash
# start_asr.sh - Start the ASR-only Docker container
#
# Usage:
#   ./scripts/start_asr.sh         # Start in foreground
#   ./scripts/start_asr.sh -d      # Start in background (detached)
#   ./scripts/start_asr.sh --build # Build image first, then start

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

IMAGE_NAME="nemotron-asr"
CONTAINER_NAME="nemotron-asr"

# Parse arguments
DETACHED=""
BUILD_FIRST=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--detach)
            DETACHED="-d"
            shift
            ;;
        --build)
            BUILD_FIRST="1"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [-d|--detach] [--build]"
            exit 1
            ;;
    esac
done

# Build if requested
if [[ -n "$BUILD_FIRST" ]]; then
    echo "Building Docker image..."
    docker build -f "$PROJECT_DIR/Dockerfile.asr" -t "$IMAGE_NAME" "$PROJECT_DIR"
    echo ""
fi

# Check if image exists
if ! docker image inspect "$IMAGE_NAME" &>/dev/null; then
    echo "Image '$IMAGE_NAME' not found. Building..."
    docker build -f "$PROJECT_DIR/Dockerfile.asr" -t "$IMAGE_NAME" "$PROJECT_DIR"
    echo ""
fi

# Stop existing container if running
if docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
    echo "Stopping existing container..."
    docker stop "$CONTAINER_NAME"
fi

# Remove existing container if exists
if docker ps -aq -f name="$CONTAINER_NAME" | grep -q .; then
    docker rm "$CONTAINER_NAME"
fi

echo "Starting ASR container..."
echo "  Image: $IMAGE_NAME"
echo "  Port: 9765 (WebSocket)"
echo "  GPU: all available"
echo ""

docker run $DETACHED \
    --name "$CONTAINER_NAME" \
    --gpus all \
    --ipc=host \
    -p 9765:9765 \
    -v "${HOME}/.cache/huggingface:/root/.cache/huggingface" \
    "$IMAGE_NAME"

if [[ -n "$DETACHED" ]]; then
    echo ""
    echo "Container started in background."
    echo "  View logs: docker logs -f $CONTAINER_NAME"
    echo "  Stop:      docker stop $CONTAINER_NAME"
    echo "  Health:    curl http://localhost:9765/health"
fi
