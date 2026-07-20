#!/bin/bash
# Build script for Oracle ADB Connping Testing Container

set -e

# Configuration
IMAGE_NAME="connping"
VERSION="v1.0"
ACR_NAME="odaamh"
ACR_REGISTRY="${ACR_NAME}.azurecr.io"
FULL_IMAGE_NAME="${ACR_REGISTRY}/${IMAGE_NAME}:${VERSION}"
LATEST_IMAGE_NAME="${ACR_REGISTRY}/${IMAGE_NAME}:latest"

echo "🚀 Building Oracle ADB Connping Testing Container"
echo "================================================="
echo "Image: ${FULL_IMAGE_NAME}"
echo ""

# Build the Docker image
echo "📦 Building image locally with Docker Desktop..."
docker build -t "${IMAGE_NAME}:${VERSION}" .
docker build -t "${IMAGE_NAME}:latest" .

echo "✅ Local build completed successfully!"
echo ""

# Tag for ACR
echo "🏷️  Tagging images for Azure Container Registry..."
docker tag "${IMAGE_NAME}:${VERSION}" "${FULL_IMAGE_NAME}"
docker tag "${IMAGE_NAME}:latest" "${LATEST_IMAGE_NAME}"

echo "✅ Images tagged successfully!"
echo ""

# Test the image
echo "🧪 Testing the built image..."
docker run --rm "${IMAGE_NAME}:latest" connping --help || echo "Note: connping help displayed"

echo ""
echo "📋 Next steps to push to Azure Container Registry:"
echo "================================================="
echo ""
echo "1. Login to ACR (if not already logged in):"
echo "   az login"
echo "   az account set --subscription 09808f31-065f-4231-914d-776c2d6bbe34"
echo "   az acr login --name ${ACR_NAME}"
echo ""
echo "2. Push images to ACR:"
echo "   docker push ${FULL_IMAGE_NAME}"
echo "   docker push ${LATEST_IMAGE_NAME}"
echo ""
echo "3. Verify the image in ACR:"
echo "   az acr repository show --name ${ACR_NAME} --image ${IMAGE_NAME}:${VERSION}"
echo ""
echo "4. Deploy to Kubernetes:"
echo "   kubectl apply -f ../k8s/namespace.yaml"
echo "   kubectl apply -f ../k8s/connping-deployment.yaml"
echo ""
echo "✅ Build script completed!"
echo ""
echo "Local images created:"
echo "  - ${IMAGE_NAME}:${VERSION}"
echo "  - ${IMAGE_NAME}:latest"
echo ""
echo "ACR images ready to push:"
echo "  - ${FULL_IMAGE_NAME}"
echo "  - ${LATEST_IMAGE_NAME}"
