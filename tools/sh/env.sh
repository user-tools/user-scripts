#!/bin/ash

: "${CWD:=$PWD}"


# XXX: sync with current user-script tooling; +user-scripts
: "${script_env_init:=$CWD/tools/sh/parts/env.sh}"
. "$script_env_init"


: "${USER_ENV:=tools/sh/env.sh}"
export USER_ENV


export scriptname=${scriptname:-$(basename "$0")}

export uname=${uname:-$(uname -s)}


# XXX: user-scripts tooling
. $script_util/parts/env-std.sh
. $script_util/parts/env-src.sh
. $script_util/parts/env-ucache.sh
. $script_util/parts/env-test-bats.sh
#. $script_util/parts/env-test-feature.sh
. $script_util/parts/env-basher.sh
. $script_util/parts/env-logger-stderr-reinit.sh
. $script_util/parts/env-github.sh
# XXX: user-env?
#. $script_util/parts/env-scriptpath.sh
