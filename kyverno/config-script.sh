#!/bin/bash

# Script to generate kubeconfig for db-team service account
# Run this after applying the YAML configuration

set -e

# Configuration
SERVICE_ACCOUNT="db-team-sa"
NAMESPACE="kube-system"
SECRET_NAME="db-team-sa-token"
CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')
SERVER_URL=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
KUBECONFIG_FILE="db-team-kubeconfig.yaml"

echo "🚀 Generating kubeconfig for db-team service account..."

# Wait for secret to be created
echo "⏳ Waiting for service account token to be available..."
kubectl wait --for=condition=Ready secret/$SECRET_NAME -n $NAMESPACE --timeout=60s

# Get the token and certificate
TOKEN=$(kubectl get secret $SECRET_NAME -n $NAMESPACE -o jsonpath='{.data.token}' | base64 -d)
CA_CERT=$(kubectl get secret $SECRET_NAME -n $NAMESPACE -o jsonpath='{.data.ca\.crt}')

# Generate kubeconfig
cat > $KUBECONFIG_FILE << EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: $CA_CERT
    server: $SERVER_URL
  name: $CLUSTER_NAME
contexts:
- context:
    cluster: $CLUSTER_NAME
    user: $SERVICE_ACCOUNT
  name: db-team-context
current-context: db-team-context
users:
- name: $SERVICE_ACCOUNT
  user:
    token: $TOKEN
EOF

echo "✅ Kubeconfig generated successfully: $KUBECONFIG_FILE"
echo ""
echo "🧪 Testing the kubeconfig..."

# Test the kubeconfig
export KUBECONFIG_BACKUP=$KUBECONFIG
export KUBECONFIG=$KUBECONFIG_FILE

echo "📋 Available namespaces with team=db label:"
kubectl get namespaces -l team=db --no-headers 2>/dev/null || echo "No namespaces found with team=db label"

echo ""
echo "🔧 To use this kubeconfig:"
echo "  export KUBECONFIG=$PWD/$KUBECONFIG_FILE"
echo "  kubectl get pods -n <your-db-namespace>"
echo ""
echo "🏷️  To create a new namespace with db team access:"
echo "  kubectl create namespace my-new-db-namespace"
echo "  kubectl label namespace my-new-db-namespace team=db"

# Restore original kubeconfig
export KUBECONFIG=$KUBECONFIG_BACKUP
