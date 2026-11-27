#!/usr/bin/env bash
# À lancer après chaque Start Lab : recopie les identifiants de session
# du Learner Lab (~/.aws/credentials) dans les secrets du dépôt GitHub.
set -euo pipefail

REPO="${1:-Mdh931/novasphere-moadh}"

for key in aws_access_key_id aws_secret_access_key aws_session_token; do
  aws configure get "$key" | gh secret set "${key^^}" --repo "$REPO"
done

echo "Secrets AWS mis à jour sur $REPO"
