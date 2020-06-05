storage "raft" {
  #path = "/Users/username/vault/raft"
  path = "/Users/username/vault/raft"
  node_id = "local-vault"
}

listener "tcp" {
  address = "0.0.0.0:8200"
  cluster_address = "0.0.0.0:8201"
  tls_disable = "true"
}

api_addr = "https://127.0.0.1:8200"
cluster_addr = "https://127.0.0.1:8201"

disable_mlock="false"
disable_cache="false"
ui = "true"

max_lease_ttl="24h"
default_lease_ttl="1h"

raw_storage_endpoint=true

cluster_name="local-vault"

insecure_tls="true"

plugin_directory="/Users/username/vault/plugins"


