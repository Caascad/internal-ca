internal-ca
===========

The repo provides tools to provision a CA in cert-manager.

The CA is generated with `cfssl`. Private keys are encrypted
using `gpg` in a [gopass](https://github.com/gopasspw/gopass) keystore.

The cert-manager CA allows the cluster users to issue certificates
inside the cluster for their deployments.

# For users

## Getting a certificate signed by the CA

Once the CA is configured in cert-manager any deployment can request
certificates signed by this CA.

You just need to create a `Certificate` resource in your deployment:

```yaml
apiVersion: cert-manager.io/v1alpha2
kind: Certificate
metadata:
  name: myapp-internal-cert
  namespace: myapp
spec:
  secretName: myapp-cert
  duration: 15d
  renewBefore: 10d
  organization:
    - caascad
  commonName: myapp
  isCA: false
  keySize: 2048
  keyAlgorithm: rsa
  keyEncoding: pkcs1
  usages:
    - server auth
    - client auth
  dnsNames:
    - myapp.default.svc.cluster.local
  ipAddresses:
    - 127.0.0.1
  issuerRef:
    name: ca-issuer
    kind: ClusterIssuer
    group: cert-manager.io
```

Make sure to adjust the following fields:

* `namespace`: you want to create it in the same namespace as your app
* `secretName`: the name of the secret containing the certificate
                that will be created by cert-manager
* `commonName`: the name of the application the cert is issued for
* `dnsNames`: the list of DNS names your app can be reached on

In your deployment you can then mount the secret in a volume and use the
certificate files (`tls.key`, `tls.crt`, `ca.crt`) in your app.

## Detecting certs renewal

Cert-manager will automatically renew the certificate for your app based on
`duration` and `renewBefore` params. It will update the secret with the new
certificate.

In K8S when a Secret or ConfigMap is updated and mounted on a pod the changes
are propagated in the pod FS.

Depending on your application you can handle it multiple ways:

* modify the application to watch for files changes and react accordingly
  (for example, the go viper lib can do it:
  https://github.com/spf13/viper/commit/e0f7631cf3ac7e7530949c7e154855076b0a4c17)
* use the reloader controller to trigger rolling updates (https://github.com/stakater/Reloader)
* ...

# For operators

Operators are in charge of provisioning `cert-manager` and the CA configuration
in different clusters of the Caascad project.

## Prerequisites

A nix shell is provided to work with the project.

## Cert-manager install

If it's not already done:

```bash
kubectl create namespace cert-manager
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v0.12.0/cert-manager.yaml
```

## Generating a CA for some env

Run:

```
internal-ca generate my_env
```

A `my_env` directory will be created and will contain the generated root CA,
and intermediate CA and associated k8s resources (`ca-certs.yaml`) to be
provisioned in a cluster.

Only the intermediate CA is provided to cert-manager.

Next step is to publish the env.

## Publishing the env CA

Make sure your local git is up-to-date.

To encrypt and publish the certificates run:

```
internal-ca publish my_env
```

This will encrypt the root CA and intermediate CA private keys using `gopass`
and push everything to the remote repository.

## Deploying the env CA

Once the CA is created and published you can deploy it on the cluster assuming
`cert-manager` is already installed:

```bash
gopass binary cat caascad/internal-ca/cloud1/ca-certs.yaml.b64 | kubectl apply -f -
kubectl apply -f ca-issuer.yaml
```

## Root CA and intermediate CA renewal

The expiration date on theses CAs is high enough (14 years) to not need to renew them.

The keys are RSA 4086 bits so that the long expiry time should not be a problem
per government recommendations (https://www.keylength.com/fr/5/)

# Tests

## Automated tests

We can tests all 3 commands with an automated script:

```sh
tests/test-internal-ca.sh
```

This script will create a temporary directory with a `gopass` store. The store is
initialized with a generated `alice` key and all `gopass` commands are tested with
this store.

## Manual tests

To test the whole procedure, we can manually load and unload a temporary `gopass`
store.

``` bash
source tests/gopass-helper.sh

TESTSTORE=mon_store
TESTENV=mon_env
TMPDIR=$(mktemp -d)

gopass_create_alice_key
gopass_mount_alice_store $TESTSTORE $TMPDIR/keystore

./internal-ca generate --store $TESTSTORE $TESTENV

ls $TMPDIR/keystore/internal-ca/$TESTENV
    ca-certs.yaml  ca.csr  ca-key.pem  ca.pem  cfssl.json
    intermediate-ca.csr  intermediate-ca-key.pem  intermediate-ca.pem

./internal-ca publish --store $TESTSTORE $TESTENV

./internal-ca renew --store $TESTSTORE $TESTENV

# clean
gopass_unmount_alice_store $TESTSTORE
rm -rf "$TMPDIR"
gpg --batch --yes --delete-secret-and-public-key 'alice@example.org'
