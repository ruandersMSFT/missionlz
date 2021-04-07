#!/bin/bash
#
# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.
#
# shellcheck disable=SC1090,2154
# SC1090: Can't follow non-constant source. Use a directive to specify location.
# SC2154: "var is referenced but not assigned". These values come from an external file.
#
# create an app registration and add MSAL auth scopes to facilitate user logon to MLZ UI

set -e

error_log() {
  echo "${1}" 1>&2;
}

usage() {
  echo "add_auth_scopes.sh: create an app registration and add MSAL auth scopes to facilitate user logon to MLZ UI"
  error_log "usage: add_auth_scopes.sh <mlz config file> <mlz UI FQDN url>"
}

if [[ "$#" -lt 2 ]]; then
   usage
   exit 1
fi

mlz_config_file=$1
fqdn=$2

# generate MLZ configuration names
. "${mlz_config_file}"
. "$(dirname "$(realpath "${BASH_SOURCE%/*}")")/config/generate_names.sh" "${mlz_config_file}"

# path to app resources definition file
required_resources_json_file="$(dirname "$(realpath "${BASH_SOURCE%/*}")")/config/mlz_login_app_resources.json"

# generate app registration
echo "INFO: creating app registration ${mlz_fe_app_name} to facilitate user logon at ${fqdn}..."
client_id=$(az ad app create \
  --display-name "${mlz_fe_app_name}" \
  --reply-urls "http://${fqdn}/redirect" \
  --required-resource-accesses "${required_resources_json_file}" \
  --query appId \
  --output tsv)
client_password=$(az ad app credential reset \
  --id ${client_id} \
  --query password \
  --only-show-errors \
  --output tsv)

# update keyvault with the app registration information
echo "INFO: storing app registration information for client ID ${client_id} in ${mlz_kv_name}..."
az keyvault secret set \
  --name "${mlz_login_app_kv_name}" \
  --subscription "${mlz_config_subid}" \
  --vault-name "${mlz_kv_name}" \
  --value "${client_id}" \
  --only-show-errors \
  --output none

az keyvault secret set \
  --name "${mlz_login_app_kv_password}" \
  --subscription "${mlz_config_subid}" \
  --vault-name "${mlz_kv_name}" \
  --value "${client_password}" \
  --only-show-errors \
  --output none

echo "INFO: waiting thirty seconds to allow for app registration propogation..."
sleep 30