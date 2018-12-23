#!/bin/ash
# See .travis.yml

export_stage before-script before_script && announce_stage
. ./tools/ci/parts/check.sh

. $ci_util/deinit.sh
