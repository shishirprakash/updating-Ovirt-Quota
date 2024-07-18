#!/bin/bash
# Variables
API_URL="https://<ovirt_host>/ovirt-engine/api/datacenters"
AUTH="admin@internal:password"
ACCEPT_HEADER="Accept: application/xml"
CONTENT_TYPE_HEADER="Content-Type: application/xml"

# Fetch all data centers
datacenters=$(curl -k -u "$AUTH" -X GET "$API_URL" -H "$ACCEPT_HEADER")

# Extract datacenter IDs using xmllint and grep (assumes xmllint is installed)
datacenter_ids=$(echo "$datacenters" | xmllint --xpath "//data_center/@id" - | grep -oP 'id="\K[^"]+')

# Loop through each datacenter to fetch and update quotas
for datacenter_id in $datacenter_ids; do
  echo "Processing data center ID: $datacenter_id"

  # Fetch all quotas for the current data center
  quotas=$(curl -k -u "$AUTH" -X GET "$API_URL/$datacenter_id/quotas" -H "$ACCEPT_HEADER")

  # Extract quota IDs and names using xmllint and grep
  quota_entries=$(echo "$quotas" | xmllint --xpath "//quota" -)
  quota_ids=$(echo "$quota_entries" | grep -oP 'id="\K[^"]+')
  quota_names=$(echo "$quota_entries" | grep -oP '<name>\K[^<]+')

  # Use temporary files for quota IDs and names
  quota_ids_file=$(mktemp)
  quota_names_file=$(mktemp)
  echo "$quota_ids" > "$quota_ids_file"
  echo "$quota_names" > "$quota_names_file"

  # Loop through each quota and update the cluster_hard_limit_pct if it's not the default quota
  paste "$quota_ids_file" "$quota_names_file" | while read -r quota_id quota_name; do
    if [[ "$quota_name" != "Default" ]]; then
      echo "Updating quota ID: $quota_id (Name: $quota_name)"
      update_data="<quota><cluster_hard_limit_pct>1</cluster_hard_limit_pct></quota>"
      curl -k -u "$AUTH" -X PUT "$API_URL/$datacenter_id/quotas/$quota_id" \
        -H "$CONTENT_TYPE_HEADER" -d "$update_data"
      sleep 2
    else
      echo "Skipping default quota ID: $quota_id (Name: $quota_name)"
    fi
  done

  # Clean up temporary files
  rm "$quota_ids_file" "$quota_names_file"

done

echo "Quota updates completed."
