#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $DIR/gopass-helper.sh

readonly TMPDIR=$(mktemp -d -t tmp.XXXXXXXXXX)
readonly GNUPGHOME=$(mktemp -d -t gpg.XXXXXXXXXX)
readonly GOPASS_HOMEDIR=$(mktemp -d -t gopass.XXXXXXXXXX)

export GNUPGHOME
export GOPASS_HOMEDIR

set -eo pipefail

###       ###
## DRYRUN ##
#         #

KUBECTL=$(whereis -b kubectl | cut -d \  -f 2)
GOPASS=$(whereis -b gopass | cut -d \  -f 2)
TESTENV="test_$(date +%s)"
TESTSTORE=test-caascad

function kubectl() {
  echo "+kubectl $@" 1>&2;

  case "$1" in
  create)
      $KUBECTL $* --dry-run
      ;;
  *)
      echo %kubectl $*
      ;;
  esac
}

function gopass() {
  echo "+gopass $@" 1>&2;
  case "$1" in
  config)
      echo "mount '$TESTSTORE' config:\n  path: gpgcli-gitcli-fs+file://$TMPDIR/keystore/"
      ;;
  binary)
      $GOPASS $*
      ;;
  *)
      echo %gopass $*
      ;;
  esac
}

###      ###
## SETUP ##
#        #

setup() {
  # use internal-ca file, ignore PATH
  shopt -u sourcepath
  gopass_create_alice_key
  gopass_mount_alice_store "$TESTSTORE" "$TMPDIR"
}


###         ###
## TEARDOWN ##
#           #

teardown() {
  gopass_unmount_alice_store "$TESTSTORE"

  rm -rf $GOPASS_HOMEDIR
  rm -rf $GNUPGHOME
  rm -rf $GOPASS_HOMEDIR
}

trap teardown EXIT
setup

###      ###
## TESTS ##
#        #

(
  echo "== internal-ca generate =="
  source internal-ca generate --store $TESTSTORE $TESTENV
  tree $TESTENV
)

(
  echo "== internal-ca publish =="
  source internal-ca publish --store $TESTSTORE $TESTENV
  tree
  $GOPASS $TESTSTORE/internal-ca
)

(
  echo "== internal-ca renew =="
  source internal-ca renew --store $TESTSTORE $TESTENV
  tree
)

(
  echo "== internal-ca publish =="
  source internal-ca publish --store $TESTSTORE $TESTENV
  tree
  $GOPASS $TESTSTORE/internal-ca
)
