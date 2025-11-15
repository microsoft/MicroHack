#!/bin/bash
# Build script for Oracle ADB Network Testing Container

set -e

# Configuration
IMAGE_NAME="adb-nettest"
VERSION="v2.1"
REGISTRY="your-registry.azurecr.io"

echo "🚀 Building Oracle ADB Network Testing Container"
echo "================================================="

# Build the Docker image
echo "📦 Building image: ${IMAGE_NAME}:${VERSION}"
docker build -t "${IMAGE_NAME}:latest" .
docker build -t "${IMAGE_NAME}:${VERSION}" .

echo "✅ Build completed successfully!"
echo ""

# Test the image
echo "🧪 Testing the built image..."
docker run --rm "${IMAGE_NAME}:latest" adbping --help | head -5

echo ""
echo "📋 Next steps:"
echo "1. Tag for your registry:"
echo "   docker tag ${IMAGE_NAME}:${VERSION} ${REGISTRY}/${IMAGE_NAME}:${VERSION}"
echo ""
echo "2. Push to registry:"
echo "   docker push ${REGISTRY}/${IMAGE_NAME}:${VERSION}"
echo ""
echo "3. Test the image:"
echo "   docker run --rm -it ${IMAGE_NAME}:latest bash"
echo ""
echo "✅ Build script completed!"