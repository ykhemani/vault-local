#!/bin/bash

export VAULT_TLS_DISABLE=${VAULT_TLS_DISABLE:-true}
export TLS_PRIVATE_KEY=${TLS_PRIVATE_KEY:-/etc/ssl/private/privkey.pem}
export TLS_CERTIFICATE=${TLS_CERTIFICATE:-/etc/ssl/certs/fullchain.pem}

export VAULT_FQDN=${VAULT_FQDN:-localhost}
if [ "${VAULT_TLS_DISABLE}" == "true" ]
then
  export VAULT_ADDR="http://${VAULT_FQDN}:8200"
else
  export VAULT_ADDR="https://${VAULT_FQDN}:8200"
fi
echo "Set VAULT_ADDR to ${VAULT_ADDR}."

export CLUSTER_ADDR="https://${VAULT_FQDN}:8201"

export DEFAULT_LEASE_TTL=${DEFAULT_LEASE_TTL:-1h}
export MAX_LEASE_TTL=${MAX_LEASE_TTL:-24h}

export VAULT=${VAULT:-/usr/local/bin/vault}
export VAULT_TOP=${VAULT_TOP:-/opt/vault}
export VAULT_DATA_DIR=${VAULT_DATA_DIR:-raft}
export VAULT_LOG_DIR=${VAULT_LOG_DIR:-log}
export VAULT_AUDIT_DIR=${VAULT_AUDIT_DIR:-audit}
export VAULT_AUDIT_RAW_DIR=${VAULT_AUDIT_RAW_DIR:-audit-raw}
export VAULT_CONFIG_DIR=${VAULT_CONFIG_DIR:-conf}
export VAULT_PLUGIN_DIR=${VAULT_PLUGIN_DIR:-plugins}

export VAULT_LOG=${VAULT_TOP}/${VAULT_LOG_DIR}/vault.log
export VAULT_AUDIT=${VAULT_TOP}/${VAULT_AUDIT_DIR}/vault_audit.log
export VAULT_AUDIT_RAW=${VAULT_TOP}/${VAULT_AUDIT_RAW_DIR}/vault_audit_raw.log
export VAULTRC=${VAULT_TOP}/vaultrc
export VAULT_INIT_KEYS=${VAULT_TOP}/init_keys
export VAULT_CONFIG=${VAULT_TOP}/${VAULT_CONFIG_DIR}/vault.hcl

echo "Stopping vault if it is running."
pkill vault

echo "Erasing any existing Vault config, data, logs, etc."
rm -rfv \
  ${VAULT_TOP}/${VAULT_DATA_DIR}/* \
  ${VAULT_LOG} \
  ${VAULT_AUDIT} \
  ${VAULT_AUDIT_RAW} \
  ${VAULTRC} \
  ${VAULT_INIT_KEYS}

echo "Creating required directories."
mkdir -p \
  ${VAULT_TOP}/${VAULT_LOG_DIR} \
  ${VAULT_TOP}/${VAULT_AUDIT_DIR} \
  ${VAULT_TOP}/${VAULT_AUDIT_RAW_DIR} \
  ${VAULT_TOP}/${VAULT_DATA_DIR} \
  ${VAULT_TOP}/${VAULT_CONFIG_DIR}

echo "Writing Vault config."

cat << EOF > ${VAULT_CONFIG}
storage "raft" {
  path            = "${VAULT_TOP}/${VAULT_DATA_DIR}"
  node_id         = "vault"
}

listener "tcp" {
  address         = "0.0.0.0:8200"
  cluster_address = "0.0.0.0:8201"
  tls_disable     = "${VAULT_TLS_DISABLE}"
  tls_key_file    = "${TLS_PRIVATE_KEY}"
  tls_cert_file   = "${TLS_CERTIFICATE}"
  tls_min_version = "tls12"
}

api_addr          = "${VAULT_ADDR}"
cluster_addr      = "${CLUSTER_ADDR}"

disable_mlock     = "true"

ui                = "true"

max_lease_ttl     = "${MAX_LEASE_TTL}"
default_lease_ttl = "${DEFAULT_LEASE_TTL}"

cluster_name      = "vault"

insecure_tls      = "false"

plugin_directory  = "${VAULT_TOP}/${VAULT_PLUGIN_DIR}"

EOF


echo "Starting Vault"
${VAULT} server -config ${VAULT_CONFIG} > ${VAULT_LOG} 2>&1 &

unset VAULT_TOKEN

echo "Waiting for $VAULT_ADDR/v1/sys/health to return 501 (not initialized)."
vault_http_return_code=0
while [ "$vault_http_return_code" != "501" ]
do
  vault_http_return_code=$(curl --insecure -s -o /dev/null -w "%{http_code}" $VAULT_ADDR/v1/sys/health)
  sleep 1
done

echo "Initializing Vault"
curl \
  --insecure \
  -s \
  --header "X-Vault-Request: true" \
  --request PUT \
  --data '{"secret_shares":1,"secret_threshold":1}' $VAULT_ADDR/v1/sys/init \
  > ${VAULT_INIT_KEYS}

export VAULT_TOKEN=$(cat ${VAULT_INIT_KEYS} | jq -r '.root_token')
export UNSEAL_KEY=$(cat ${VAULT_INIT_KEYS} | jq -r .keys[])


# ${VAULT} operator init \
#   -format=json \
#   -key-shares 1 \
#   -key-threshold 1 \
#   > ${VAULT_INIT_KEYS}

# export VAULT_TOKEN=$(cat ${VAULT_INIT_KEYS} | jq -r '.root_token')
# export UNSEAL_KEY=$(cat ${VAULT_INIT_KEYS} | jq -r .unseal_keys_hex[])

echo "Writing vaultrc ${VAULTRC}."
cat << EOF > ${VAULTRC}
#!/bin/bash

export VAULT_TOKEN=${VAULT_TOKEN}
export VAULT_ADDR=${VAULT_ADDR}
export VAULT_SKIP_VERIFY=true
export UNSEAL_KEY=${UNSEAL_KEY}
EOF

# unseal
echo "Waiting for $VAULT_ADDR/v1/sys/health to return 503 (sealed)."
vault_http_return_code=0
while [ "$vault_http_return_code" != "503" ]
do
  vault_http_return_code=$(curl --insecure -s -o /dev/null -w "%{http_code}" $VAULT_ADDR/v1/sys/health)
  sleep 1
done

echo "Unsealing Vault"
curl \
  -s \
  --request PUT \
  --data "{\"key\": \"${UNSEAL_KEY}\"}" \
  $VAULT_ADDR/v1/sys/unseal | jq -r .

echo "Waiting for $VAULT_ADDR/v1/sys/health to return 200 (initialized, unsealed, active)."
vault_http_return_code=0
while [ "$vault_http_return_code" != "200" ]
do
  vault_http_return_code=$(curl --insecure -s -o /dev/null -w "%{http_code}" $VAULT_ADDR/v1/sys/health)
  sleep 1
done

# Enable audit log
echo "Enable audit device ${VAULT_AUDIT}."
${VAULT} audit enable \
  file \
  file_path=${VAULT_AUDIT}

echo "Enable raw audit device ${VAULT_AUDIT_RAW}."
${VAULT} audit enable \
  -path=raw file \
  file_path=${VAULT_AUDIT_RAW} \
  log_raw=true

if [ "${vault_license}" != "" ]
then
  echo "Installing Vault license."
  curl \
    --insecure \
    --header "X-Vault-Token: $VAULT_TOKEN" \
    --request PUT \
    --data "{\"text\": \"${vault_license}\"}" \
    $VAULT_ADDR/v1/sys/license
else
  echo "No Vault license specified."
fi

echo "Vault is ready for use."
echo "Please source vaultrc file ${VAULTRC} to configure your environment:"
echo ". ${VAULTRC}"
