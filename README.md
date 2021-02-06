# Run Vault locally for quick ad hoc demos.

Sometimes you need a short-lived [HashiCorp](https://hashicorp.com) [Vault](https://vaultproject.io) cluster to develop or validate a policy, an auth method or a secret engine configuration.

There are many ways to do this. The [vault.sh](vault.sh) script provided in this repository allows you to quickly spin up a Vault server in a fairly painless manner.

More specifically, [vault.sh](vault.sh) will:
* Stop vault if it is already running on the host where you are running this script.
* Remove any existing data, logs, config files and audit logs. The result is that you will have a clean Vault server bootstrapped.
* Create the required directories for housing the configuration, log file, and audit logs.
* Generate the configuration file for Vault to start.
* Start Vault.
* Initialize Vault, capturing the unseal key and root token to a file.
* Unseal Vault using that unseal key.
* Enable a standard file audit device, as well as a raw file audit device.
* Install the Vault license if one has been provided (see Customizations below).

## Prerequisites
* Vault binary suitable for your operating system and architecture (expected by default at `/usr/local/bin/vault`).

## Usage

```
git clone https://github.com/ykhemani/vault-local
cd ./vault-local
export VAULT_TOP=$(pwd) # or the path where Vault configs, data, logs and audit logs should be written.
./bin/vault.sh
```

## Sample output

```
$ . venv 

$ ./bin/vault.sh 
Set VAULT_ADDR to http://localhost:8200.
Stopping vault if it is running.
Erasing any existing Vault config, data, logs, etc.
/Users/khemani/data/vault/raft/raft/snapshots
/Users/khemani/data/vault/raft/raft/raft.db
/Users/khemani/data/vault/raft/raft
/Users/khemani/data/vault/raft/vault.db
/Users/khemani/data/vault/log/vault.log
/Users/khemani/data/vault/audit/vault_audit.log
/Users/khemani/data/vault/audit-raw/vault_audit_raw.log
/Users/khemani/data/vault/vaultrc
/Users/khemani/data/vault/init_keys
Creating required directories.
Writing Vault config.
Starting Vault
Waiting for http://localhost:8200/v1/sys/health to return 501 (not initialized).
Initializing Vault
Writing vaultrc /Users/khemani/data/vault/vaultrc.
Waiting for http://localhost:8200/v1/sys/health to return 503 (sealed).
Unsealing Vault
{
  "type": "shamir",
  "initialized": true,
  "sealed": false,
  "t": 1,
  "n": 1,
  "progress": 0,
  "nonce": "",
  "version": "1.6.2+ent",
  "migration": false,
  "cluster_name": "vault",
  "cluster_id": "d6504eaa-3438-4167-dc6e-1a6367926040",
  "recovery_seal": false,
  "storage_type": "raft"
}
Waiting for http://localhost:8200/v1/sys/health to return 200 (initialized, unsealed, active).
Enable audit device /Users/khemani/data/vault/audit/vault_audit.log.
Success! Enabled the file audit device at: file/
Enable raw audit device /Users/khemani/data/vault/audit-raw/vault_audit_raw.log.
Success! Enabled the file audit device at: raw/
No Vault license specified.
Vault is ready for use.
Please source vaultrc file /Users/khemani/data/vault/vaultrc to configure your environment:
. /Users/khemani/data/vault/vaultrc
```

```
$ . /Users/khemani/data/vault/vaultrc

$ vault status
Key                     Value
---                     -----
Seal Type               shamir
Initialized             true
Sealed                  false
Total Shares            1
Threshold               1
Version                 1.6.2+ent
Storage Type            raft
Cluster Name            vault
Cluster ID              d6504eaa-3438-4167-dc6e-1a6367926040
HA Enabled              true
HA Cluster              https://localhost:8201
HA Mode                 active
Raft Committed Index    90
Raft Applied Index      90
Last WAL                27
```

## Sample output with TLS enabled

```
$ . venv 

$ ./bin/vault.sh 
Set VAULT_ADDR to https://vault.example.com:8200.
Stopping vault if it is running.
Erasing any existing Vault config, data, logs, etc.
Creating required directories.
Writing Vault config.
Starting Vault
Waiting for https://vault.example.com:8200/v1/sys/health to return 501 (not initialized).
Initializing Vault
Writing vaultrc /Users/khemani/data/vault/vaultrc.
Waiting for https://vault.example.com:8200/v1/sys/health to return 503 (sealed).
Unsealing Vault
{
  "type": "shamir",
  "initialized": true,
  "sealed": false,
  "t": 1,
  "n": 1,
  "progress": 0,
  "nonce": "",
  "version": "1.6.2+ent",
  "migration": false,
  "cluster_name": "vault",
  "cluster_id": "4e23acce-80cd-bb67-118e-16c9beee3997",
  "recovery_seal": false,
  "storage_type": "raft"
}
Waiting for https://vault.example.com:8200/v1/sys/health to return 200 (initialized, unsealed, active).
Enable audit device /Users/khemani/data/vault/audit/vault_audit.log.
Success! Enabled the file audit device at: file/
Enable raw audit device /Users/khemani/data/vault/audit-raw/vault_audit_raw.log.
Success! Enabled the file audit device at: raw/
Installing Vault license.
Vault is ready for use.
Please source vaultrc file /Users/khemani/data/vault/vaultrc to configure your environment:
. /Users/khemani/data/vault/vaultrc
```

```
$ . /Users/khemani/data/vault/vaultrc

$ vault status
Key                     Value
---                     -----
Seal Type               shamir
Initialized             true
Sealed                  false
Total Shares            1
Threshold               1
Version                 1.6.2+ent
Storage Type            raft
Cluster Name            vault
Cluster ID              4e23acce-80cd-bb67-118e-16c9beee3997
HA Enabled              true
HA Cluster              https://vault.example.com:8201
HA Mode                 active
Raft Committed Index    87
Raft Applied Index      87
Last WAL                27
```

Note that in the example above, I've used a TLS certificate with the common name `vault.example.com` and that I have added an entry for `vault.example.com` pointing to `127.0.0.1` in my `/etc/hosts` file.

### Customizations

This repo provides supports for running Vault with TLS certificates. To run Vault with TLS enabled, set the following environment variables prior to running Vault.

I set these via a file called `venv`, which is listed in the [.gitignore](.gitignore) so that it doesn't get added to the repo.

```
export VAULT_TLS_DISABLE=false

export TLS_PRIVATE_KEY=<path to private key>

export TLS_CERTIFICATE=<path to TLS certificate>

export VAULT_FQDN=<FQDN matching common name in TLS certificate>
```

For example:

```
export VAULT_TLS_DISABLE=false

export TLS_PRIVATE_KEY="/etc/ssl/private/privkey.pem"
export TLS_CERTIFICATE="/etc/ssl/certs/fullchain.pem"

export VAULT_FQDN="vault.example.com"
```

This repo also supports running Vault Enterprise. To apply your Vault license, set the following environment variable prior to running Vault.

```
export vault_license=<vault license>
```

As mentioned above, `vault.sh` expects to find the `vault` binary at `/usr/local/bin/vault`. You may override this by setting the path to the `vault` binary via the `VAULT` environment variable. For example:
```
export VAULT=/usr/bin/vault
```
