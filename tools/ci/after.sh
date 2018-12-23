#!/bin/sh
export_stage after && announce_stage

echo 'Travis test-result: '"$TRAVIS_TEST_RESULT"

. ./tools/ci/parts/publish.sh

announce "End of $scriptname"
echo Done
. $ci_util/deinit.sh
