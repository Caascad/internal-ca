#
# Some helpers to test gopass with a temporary gopass store
#
GOPASS=$(whereis -b gopass | cut -d \  -f 2)

gopass_create_alice_key() {
  echo "== create gpg alice key =="
  gpg --batch --passphrase '' --quick-gen-key 'alice@example.org' || true
}

gopass_init() {
  echo "alice@example.org" > "$PASSWORD_STORE_DIR"/.gpg-id
}

# Create the gopass store with git
# We create a fake git origin beacause internal-ca test if the origin is update.
# 1:$TESTSTORE 2:$TMPDIR
gopass_mount_alice_store() {
  local store_name="$1"
  local temp_dir="$2"
  local fakeorigin_path="$temp_dir/fake_origin"
  local keystore_path="$temp_dir/keystore"

  echo "== git init $keystore_path with fake origin =="
  mkdir -p "$fakeorigin_path"
  git -C "$fakeorigin_path" init
  git -C "$fakeorigin_path" config --add receive.denyCurrentBranch 'warn'

  mkdir -p "$keystore_path"
  git -C "$keystore_path" init
  echo "test repository" > "$keystore_path/readme.md"
  git -C "$keystore_path" add readme.md
  git -C "$keystore_path" commit -m "not empty"
  git -C "$keystore_path" remote add origin "$fakeorigin_path/.git"
  git -C "$keystore_path" push --set-upstream origin master

  echo "== mount $store_name $temp_dir =="
  $GOPASS mounts mount --init 'alice@example.org' "$store_name" "$keystore_path"
  $GOPASS mounts
}

gopass_unmount_alice_store() {
  local store_name="$1"
  echo "== unmount $store_name =="
  $GOPASS mounts unmount "$store_name"
  $GOPASS mounts
}
