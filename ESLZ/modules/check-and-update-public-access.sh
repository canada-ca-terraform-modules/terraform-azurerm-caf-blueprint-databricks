#!/bin/bash

WORKSPACE_ID=$("$TG_CTX_TF_PATH" output -raw workspace_id)

if [ $? -ne 0 ] || [ -z "$WORKSPACE_ID" ]; then
  echo "Error: Unable to retrieve workspace ID from Terraform output."
  exit 1
fi

REST_ENDPOINT="https://management.azure.com/$WORKSPACE_ID?api-version=2026-01-01"

function wait_for_provisioning_state_succeeded() {

  echo "Checking provisioning state of the workspace..."

  while true; do
    local provisioning_state=$(az rest --method GET --uri $REST_ENDPOINT -o json | jq -r '.properties.provisioningState')
    if [ "$provisioning_state" = "Succeeded" ]; then
      echo "Provisioning state is now 'Succeeded'."
      break
    else
      echo "Current provisioning state: '$provisioning_state'. Waiting..."
      sleep 30
    fi
  done
}

NETWORK_ACCESS_DESIRED_STATE="Disabled"

if [ "$TG_CTX_COMMAND" = "destroy" ]; then
  NETWORK_ACCESS_DESIRED_STATE="Enabled"
  exit 0
fi

wait_for_provisioning_state_succeeded

PUBLIC_NETWORK_ACCESS=$(\
  az rest --method GET --uri $REST_ENDPOINT -o json | \
  jq -r '.properties.publicNetworkAccess' \
)

echo "Current value of public network access: $PUBLIC_NETWORK_ACCESS"

if [ "$PUBLIC_NETWORK_ACCESS" = "$NETWORK_ACCESS_DESIRED_STATE" ]; then
  echo "Public network access is already set to the desired state '$NETWORK_ACCESS_DESIRED_STATE'. No update needed."
  exit 0
fi

az rest --method GET --uri $REST_ENDPOINT -o json | jq ".properties.publicNetworkAccess = \"$NETWORK_ACCESS_DESIRED_STATE\"" > updated_workspace.json
az rest --method PUT --uri $REST_ENDPOINT -o none --body @updated_workspace.json
if [ $? -ne 0 ]; then
  echo "Failed to update public access setting."
  exit 1
fi

echo "The change to public access has been submitted. Waiting for the workspace to be available"

wait_for_provisioning_state_succeeded