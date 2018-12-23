#!/bin/ash
# See .travis.yml

# FIXME: script & build, actual project lib testing


# Smoke run everything with make
  #- make test/baseline/realpath.tap
  #- make base
  #- make lint
  #- make units
  #- make specs


# Cleanup and run again wtih redo
  #- git clean -dfx test/
  #- redo


export_stage script && announce_stage

. ./tools/ci/parts/init-build-cache.sh

announce 'Checking project tooling, host env, 3rd party setup...'
. ./tools/ci/parts/baseline.sh

failed=/tmp/htd-build-test-$(get_uuid).failed
. ./tools/ci/parts/build.sh

export script_end_ts="$($gdate +"%s.%N")"

#announce 'Running unit tests...'
#scriptpath= SCRIPTPATH= bats test/unit/{os,lib,logger}*bats
#scriptpath= SCRIPTPATH= bats test/unit/{sys,shell,str,date}*bats
#scriptpath= SCRIPTPATH= bats test/unit/*bats


#announce 'Running other specs, features etc...'
#scriptpath= SCRIPTPATH= bats test/spec/*bats

#lib_load script logger str logger-std
#lib_load env-d build user-env make mkvar
#lib_load build package build-test
#lib_init


announce "Done"
#announce "All OK"

. $ci_util/deinit.sh
