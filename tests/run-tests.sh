#!/bin/bash

# Determine the path to this script (we'll use this to figure out relative positions of other files)
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  SCRIPT_PATH="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
export SCRIPT_PATH="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"

source $SCRIPT_PATH/../package/scripts/common/utils.sh

export QUARTO_ROOT="`cd "$SCRIPT_PATH/.." > /dev/null 2>&1 && pwd`"
QUARTO_SRC_DIR="$QUARTO_ROOT/src"
DENO_ARCH_DIR=$DENO_DIR
DENO_DIR="$QUARTO_ROOT/package/dist/bin/"

# Local import map
QUARTO_IMPORT_ARGMAP=--importmap=$QUARTO_SRC_DIR/dev_import_map.json

export QUARTO_BIN_PATH=$DENO_DIR
export QUARTO_SHARE_PATH="`cd "$QUARTO_ROOT/src/resources/";pwd`"
export QUARTO_DEBUG=true

QUARTO_DENO_OPTIONS="--config test-conf.json --unstable --allow-read --allow-write --allow-run --allow-env --allow-net --check"


if [[ -z $GITHUB_ACTION ]] && [[ -z $QUARTO_TESTS_NO_CONFIG ]]
then
  echo "> Checking and configuring environment for tests"
  source configure-test-env.sh
fi

# Activating python virtualenv
# set QUARTO_TESTS_FORCE_NO_PIPENV env var to not activate the virtalenv manage by pipenv for the project
if [[ -z $QUARTO_TESTS_FORCE_NO_PIPENV ]]
then
  # Save possible activated virtualenv for later restauration
  OLD_VIRTUAL_ENV=$VIRTUAL_ENV
  echo "> Activating virtualenv for Python tests in Quarto"
  source "$(pipenv --venv)/bin/activate"
  quarto_venv_activated="true"
fi

if [ "$QUARTO_TEST_TIMING" != "" ]; then
  QUARTO_DENO_OPTIONS="--config test-conf.json --unstable --allow-read --allow-write --allow-run --allow-env --allow-net --no-check"
  rm -f timing.txt
  FILES=$@
  if [ "$FILES" == "" ]; then
    FILES=`find . | grep \.test\.ts$`
  fi
  for i in $FILES; do
    echo $i >> timing.txt
    /usr/bin/time -a -o timing.txt "${DENO_DIR}/tools/${DENO_ARCH_DIR}/deno" test ${QUARTO_DENO_OPTIONS} ${QUARTO_DENO_EXTRA_OPTIONS} "${QUARTO_IMPORT_ARGMAP}" $i
  done
else
  "${DENO_DIR}/tools/${DENO_ARCH_DIR}/deno" test ${QUARTO_DENO_OPTIONS} ${QUARTO_DENO_EXTRA_OPTIONS} "${QUARTO_IMPORT_ARGMAP}" $@
fi

SUCCESS=$?

if [[ $quarto_venv_activated == "true" ]] 
then
  echo "> Exiting virtualenv activated for tests"
  deactivate
  unset quarto_venv_activated
fi
if [[ -n $OLD_VIRTUAL_ENV ]]
then
  echo "> Reactivating original virtualenv"
  source $OLD_VIRTUAL_ENV/bin/activate
  unset OLD_VIRTUAL_ENV
fi

# Generates the coverage report
if [[ $@ == *"--coverage"* ]]; then

  # read the coverage value from the command 
  [[ $@ =~ .*--coverage=(.+) ]] && export COV="${BASH_REMATCH[1]}"

  echo Generating coverage report...
  ${DENO_DIR}/deno coverage --unstable ${COV} --lcov > ${COV}.lcov
  genhtml -o ${COV}/html ${COV}.lcov
  open ${COV}/html/index.html
fi

exit ${SUCCESS}
