#!/bin/bash

WORKSPACE_ID=$("$TG_CTX_TF_PATH" output -raw workspace_id)

REST_ENDPOINT="https://management.azure.com/$WORKSPACE_ID?api-version=2026-01-01"

CURRENT_STATE=$(\
  az rest --method GET --uri $REST_ENDPOINT -o json | \
  jq -r '{publicNetworkAccess: .properties.publicNetworkAccess, provisioningState: .properties.provisioningState}' \
)

PUBLIC_NETWORK_ACCESS=$(echo $CURRENT_STATE | jq -r '.publicNetworkAccess')
PROVISIONING_STATE=$(echo $CURRENT_STATE | jq -r '.provisioningState')

echo "Current value of public network access: $PUBLIC_NETWORK_ACCESS"
echo "Current provisioning state: $PROVISIONING_STATE"

if [ "$PUBLIC_NETWORK_ACCESS" = "Disabled" ]; then
  echo "Public network access is already disabled. No update needed."
  exit 0
fi

if [ "$PROVISIONING_STATE" != "Succeeded" ]; then
  echo "Workspace is currently in provisioning state '$PROVISIONING_STATE'. Please wait until provisioning completes and re-run."
  exit 1
fi

az rest --method GET --uri $REST_ENDPOINT -o json | jq '.properties.publicNetworkAccess = "Disabled"' > updated_workspace.json
az rest --method PUT --uri $REST_ENDPOINT -o none --body @updated_workspace.json
if [ $? -ne 0 ]; then
  echo "Failed to update public access setting."
  exit 1
fi
echo "The change to public access has been submitted. The workspace will be available again once the provisioning completes."