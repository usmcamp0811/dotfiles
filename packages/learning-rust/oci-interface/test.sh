#!/run/current-system/sw/bin/bash
IMAGE="test-artifact"
REGISTRY="localhost:5000"
TAG="latest"

# Get manifest with the correct Accept header
MANIFEST=$(curl -s -H "Accept: application/vnd.oci.image.manifest.v1+json" \
    "http://$REGISTRY/v2/$IMAGE/manifests/$TAG")

# Extract first layer digest
LAYER_DIGEST=$(echo "$MANIFEST" | jq -r '.layers[0].digest')

echo "Layer digest: $LAYER_DIGEST"

# Download the layer
curl -s -o layer.tar "http://$REGISTRY/v2/$IMAGE/blobs/$LAYER_DIGEST"

# Check file type
FILE_TYPE=$(file --mime-type layer.tar | awk '{print $2}')
echo "Downloaded file type: $FILE_TYPE"

# Extract based on file type
if [[ "$FILE_TYPE" == "application/gzip" ]]; then
    tar -xvzf layer.tar
else
    tar -xvf layer.tar
fi

# Read extracted file
cat example.txt
