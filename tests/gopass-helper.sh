#
# Some helpers to test gopass with a temporary gopass store
#
GOPASS=$(whereis -b gopass | cut -d \  -f 2)

gopass_create_alice_key() {
  echo "== create gpg alice key =="
  gpg --batch --passphrase '' --quick-gen-key 'alice@example.org' || true
}

gopass_mount_alice_store() {
  echo "== mount $1 $2 =="
  $GOPASS mounts mount --init 'alice@example.org' $1 "$2"
  $GOPASS mounts

  (
    echo "== git init $TMPDIR/keystore =="
    cd "$TMPDIR/keystore"
    git init
  )
}

gopass_unmount_alice_store() {
  echo "== unmount $1 =="
  $GOPASS mounts unmount $1
  $GOPASS mounts
}
