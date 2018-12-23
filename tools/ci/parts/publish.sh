#!/bin/sh
# Pub/dist

export publish_ts=$($gdate +%s.%N)
ci_stages="$ci_stages publish"

announce "Starting ci:publish"

lib_load git vc vc-htd

set -- "bvberkum/script-mpe"
git_scm_find "$1" || {
  git_scm_get "$SCM_VND" "$1" || return
}

. ./tools/ci/parts/report-times.sh

# FIXME: pubish
