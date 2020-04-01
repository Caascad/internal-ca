#!/usr/bin/env bash

set -eo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $DIR/gopass-helper.sh

readonly TEST_STORE=$(mktemp -d -t store.XXXXXXXXXX)
readonly GNUPGHOME=$(mktemp -d -t gpg.XXXXXXXXXX)
readonly PASSWORD_STORE_DIR=$(mktemp -d -t pass.XXXXXXXXXX)
readonly GOPASS_HOMEDIR=$(mktemp -d -t gopass.XXXXXXXXXX)

export GNUPGHOME
export GOPASS_HOMEDIR
export PASSWORD_STORE_DIR

###       ###
## DRYRUN ##
#         #

GOPASS=$(type -p gopass)
TESTENV="test_$(date +%s)"
TESTSTORE=test-caascad

###      ###
## SETUP ##
#        #

setup() {
  # use internal-ca file, ignore PATH
  shopt -u sourcepath
  gopass_create_alice_key
  gopass_init
  gopass_mount_alice_store "$TESTSTORE" "$TEST_STORE"
}


###         ###
## TEARDOWN ##
#           #

teardown() {
  gopass_unmount_alice_store "$TESTSTORE"
  rm -rf $TEST_STORE
  rm -rf $GOPASS_HOMEDIR
  rm -rf $PASSWORD_STORE_DIR
  rm -rf $GNUPGHOME
}

trap teardown EXIT
setup

###      ###
## TESTS ##
#        #

(
  echo "== internal-ca generate =="
  source internal-ca generate --yes --store $TESTSTORE $TESTENV
  tree $TESTENV
)

(
  echo "== internal-ca publish =="
  source internal-ca publish --yes --store $TESTSTORE $TESTENV
  tree
  $GOPASS $TESTSTORE/internal-ca
)

(
  echo "== internal-ca renew =="
  source internal-ca renew --yes --store $TESTSTORE $TESTENV
  tree
)

(
  echo "== internal-ca publish =="
  source internal-ca publish --yes --store $TESTSTORE $TESTENV
  tree
  $GOPASS $TESTSTORE/internal-ca
)
