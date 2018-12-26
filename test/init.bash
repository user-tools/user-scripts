#!/bin/bash

# Helpers for BATS project test env.


# Return level number as string for use with line-type or logger level, channel
log_level_name() # Level-Num
{
  case "$1" in
      1 ) echo emerg ;;
      2 ) echo crit ;;
      3 ) echo error ;;
      4 ) echo warn ;;
      5 ) echo note ;;
      6 ) echo info ;;
      7 ) echo debug ;;
      * ) return 1 ;;
  esac
}

log_level_num() # Level-Name
{
  case "$1" in
      emerg ) echo 1 ;;
      crit  ) echo 2 ;;
      error ) echo 3 ;;
      warn* ) echo 4 ;;
      note|notice  ) echo 5 ;;
      info  ) echo 6 ;;
      debug ) echo 7 ;;
      * ) return 1 ;;
  esac
}


fnmatch() { case "$2" in $1 ) true ;; * ) false ;; esac; }


# Simple init-log shell function that behaves well in unintialzed env,
# but does not add (vars) to env.
err_() # [type] [cat] [msg] [tags] [status]
{
  test -z "$verbosity" -a -z "$DEBUG" && return
  test -n "$2" || set -- "$1" "$base" "$3" "$4" "$5"
  test -z "$verbosity" -a -n "$DEBUG" || {

    case "$1" in [0-9]* ) true ;; * ) false ;; esac &&
      lvl=$(log_level_name "$1") ||
      lvl=$(log_level_num "$1")

    test $verbosity -ge $lvl || {
      test -n "$5" && exit $5 || {
        return 0
      }
    }
  }

  printf -- "%s\n" "[$2] $1: $3 <$4> ($5)" >&2
  test -z "$5" || exit $5 # NOTE: also exit on '0'
}


# Set env and other per-specfile init
test_env_load()
{
  test -n "$script_util" || return 103 # NOTE: sanity
  test -n "$INIT_LOG" || INIT_LOG=err_

  # FIXME: hardcoded sequence for env-d like for lib. Using lib-util-env-d-default
  for env_d in 0 log ucache scriptpath dev test
  do
     $INIT_LOG "debug" "" "Loading env-part" "$env_d"
    . $script_util/parts/env-$env_d.sh ||
        $INIT_LOG "warn" "" "Failed env-part"  "$? $env_d"
  done

  test -n "$base" || return 12 # NOTE: sanity
  test -n "$INIT_LOG" || return 102 # NOTE: sanity
  $INIT_LOG "info" "" "Env initialized from parts"
}

# Set env and other per-specfile init
test_env_init()
{
  test -n "$scriptname" &&
    scriptname=$scriptname:test:$base ||
    scriptname=test:$base

  # Detect when base is exec
  test -x $PWD/$base && {
    bin=$base
  } || {
    test -x "$(which $base)" && bin=$(which $base) || lib=$(basename $base .lib)
  }
}


# Bootstrap test-env for Bats ~ 1:Init 2:Load-Libs 3:Boot-Std 4:Boot-Script
init() # ( 0 | 1 1 1 1 )
{
  test -z "$lib_loaded" || return 105
  test -n "$script_util" || script_util=$(pwd -P)/tools/sh
  test -d "$script_util" || return 103 # NOTE: sanity
  test_env_load || return
  test_env_init || return

  # Get lib-load, and optional libs/boot script/helper

  test $# -gt 0 || set -- 1
  test "$1" = "0" || {

    test -n "$2" || set -- "$1" "$1" "$3" "$4"
    test -n "$3" || set -- "$1" "$2" "$2" "$4"
    test -n "$4" || set -- "$1" "$2" "$3" "$3"

    init_sh_libs="$2"
    init_sh_boot="$3"

    test "$2" != "1" -o \( -n "$3" -a "$3" != "0" \) || init_sh_boot="null"
    test "$init_sh_boot" = "1" && {
      test "$3" = "0" || init_sh_boot='std test'
      test "$4" = "0" || init_sh_boot=$init_sh_boot' script'
    }

  }

  load_init_bats

# FIXME: deal with sub-envs wanting to know about lib-envs exported by parent
# ie. something around ENV_NAME, ENV_STACK. Renamed ENV_SRC to LIB_SRC for now
# and dealing only with current env, testing lib-load and tools, user-scripts.
  LIB_SRC=
  . $script_util/init.sh || return

}


# Non-bats bootstrap to initialize access to test-helper libs with 'load'
load_init() # [ 0 ]
{
  test "$1" = "0" || {
    test_env_init || return
  }

  test -n "$TMPDIR" || TMPDIR=/tmp
  BATS_TMPDIR=$TMPDIR/bats-temp-$(get_uuid)
  BATS_CWD=$PWD
  BATS_TEST_DIRNAME=$PWD/test
  load_init_bats
#  test "$PWD" = "$scriptpath"
}


# XXX: temporary override for Bats load
load_old() {
  local name="$1"
  local filename

  if [[ "${name:0:1}" == '/' ]]; then
    filename="${name}"
  else
    filename="$BATS_TEST_DIRNAME/${name}.bash"
  fi

  if [[ ! -f "$filename" ]]; then
    printf 'bats: %s does not exist\n' "$filename" >&2
    exit 1
  fi

  source "${filename}"
}

# XXX: intial bits shouldn't they be in suite exec.
bats_autosetup_common_includes()
{
  : "${BATS_LIB_PATH_DEFAULTS:="test helper test/helper node_modules vendor"}"

  # Basher has a GitHub <user>/<package> checkout tree
  : "${BASHER_PACKAGES:=$HOME/.basher/cellar/packages}"
  test ! -d $BASHER_PACKAGES ||
    BATS_LIB_PATH_DEFAULTS="$BATS_LIB_PATH_DEFAULTS $BASHER_PACKAGES"

  test -e /src/ &&
    : "${VND_SRC_PREFIX:="/src"}" ||
    : "${VND_SRC_PREFIX:="$HOME/build"}"

  : "${VENDORS:="google.com github.com bitbucket.org"}"
  for vendor in $VENDORS
  do
    test -e $VND_SRC_PREFIX/$vendor || continue

    BATS_LIB_PATH_DEFAULTS="$BATS_LIB_PATH_DEFAULTS $VND_SRC_PREFIX/$vendor"
  done
}

bats_dynamic_include_path()
{
  # Require BATS_LIB_PATH_DEFAULTS, a list of partial relative and
  # absolute path names to initialze BATS_LIB_PATH with
  bats_autosetup_common_includes

  # Build up default path, start-to-end.
  BATS_LIB_PATH="$BATS_TEST_DIRNAME"

  # Add default helper or package locations, for relative paths
  # first those beside test script (BATS_TEST_DIRNAME) then BATS_CWD
  for path_default in $BATS_LIB_PATH_DEFAULTS
  do
    test "${path_default:0:1}" = '/' && {
      test -e "$path_default"  || continue

      BATS_LIB_PATH="$BATS_LIB_PATH:$path_default"
    } || {

      for bats_path in "$BATS_TEST_DIRNAME" "$BATS_CWD"
      do
        test -d "$bats_path/$path_default" || continue
        BATS_LIB_PATH="$BATS_LIB_PATH:$bats_path/$path_default"
      done
    }
  done
}

load_init_bats()
{
  test -n "$BATS_LIB_PATH" || bats_dynamic_include_path

  test -n "$BATS_LIB_EXTS" || BATS_LIB_EXTS=.bash\ .sh
  test -n "$BATS_VAR_EXTS" || BATS_VAR_EXTS=.txt\ .tab
  test -n "$BATS_LIB_DEFAULT" || BATS_LIB_DEFAULT=load
}

load() # ( PATH | NAME )
{
  test $# -gt 0 || return 1
  : "${lookup_exts:=${BATS_LIB_EXTS}}"
  while test $# -gt 0
  do
    source $(bats_lib_lookup "$1" || return $? ) || return $?
    shift
  done
}

bats_lib_lookup()
{
  test $# -eq 1 || return 1
  : "${lookup_exts:=${BATS_VAR_EXTS}}"
  test "${1:0:1}" = '/' -a -e "$1" && {
    echo "$1"
    return
  }
  for i in ${BATS_LIB_PATH//:/ }
  do
    test -d "$i/$1" && {

      for e in $lookup_exts
      do
        test -e "$i/$1/$BATS_LIB_DEFAULT$e" && {
          echo "$i/$1/$BATS_LIB_DEFAULT$e"
          return
        }
      done

    }
    test -f "$i/$1" && {
      echo "$i/$1"
      return
    }
    for e in $lookup_exts
    do
      test -e "$i/$1$e" && {
        echo "$i/$1$e"
        return
      }
    done
  done
  return 1
}
