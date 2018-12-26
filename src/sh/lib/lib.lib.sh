#!/bin/sh

# Module for lib_load


lib_lib_load()
{
  test -n "$default_lib" || default_lib="os sys str src shell"
  # XXX testing default_lib="argv match vc"
}

lib_lib_init()
{
  test -n "$LOG" && lib_lib_log="$LOG" || lib_lib_log="$INIT_LOG"
  test -n "$lib_lib_log" || return 102

  $lib_lib_log info "" "Loaded lib.lib" "$0"
}

lib_lib_log() { test -n "$LOG" && log="$LOG" || log="$lib_lib_log"; }

lib_path_exists()
{
  test -e "$1/$2.lib.sh" || return 1
  echo "$1/$2.lib.sh"
}

lib_loaded() # [Check-Libs...]
{
  test $# -gt 0 && {

    while test $# -gt 0
    do
      lib_id=$(printf -- "${1}" | tr -Cs 'A-Za-z0-9_' '_')

      test "$1" = "$(eval echo \$${lib_id}_lib_loaded)" || return
      shift
    done
    return

  } || {
    sh_genv '[a-z][a-z0-9]*_lib_loaded' | sed 's/_lib_loaded=1$//' | sort
  }
}

# Echo every occurence of *.lib.sh on SCRIPTPATH
lib_path() # local-name path-var-name
{
  test -n "$2" || set -- "$1" SCRIPTPATH
  lookup_test=lib_path_exists lookup_path $2 "$1"
}

lib_lookup()
{
  lib_path "$1" | head -n 1
}

# Lookup and load sh-lib on SCRIPTPATH
lib_load()
{
  test -n "$1" || return 1
  test -n "$lib_lib_log" || exit 102 # NOTE: sanity

  $lib_lib_log debug "" "Loading lib(s)" "$*"

  local lib_id= f_lib_loaded= f_lib_path=

  # __load_lib: true if inside util.sh:lib-load
  test -n "$__load_lib" || local __load_lib=1
  while test $# -gt 0
  do
    lib_id=$(printf -- "${1}" | tr -Cs 'A-Za-z0-9_' '_')
    test -n "$lib_id" || {
      $lib_lib_log error lib "err: lib_id=$lib_id" "" 1 || return
    }
    f_lib_loaded=$(eval printf -- \"\$${lib_id}_lib_loaded\")

    test -n "$f_lib_loaded" || {

        # Note: the equiv. code using sys.lib.sh is above, but since it is not
        # loaded yet keep it written out using plain shell.
        f_lib_path="$( echo "$SCRIPTPATH" | tr ':' '\n' | while read sp
          do
            test -e "$sp/$1.lib.sh" || continue
            echo "$sp/$1.lib.sh"
            break
          done)"

        test -n "$f_lib_path" || {
          $lib_lib_log error "lib" "No path for lib '$1'" "" 1 || return
        }
        . "$f_lib_path"

        # again, func_exists is in sys.lib.sh. But inline here:
        type ${lib_id}_lib_load  2> /dev/null 1> /dev/null && {
          ${lib_id}_lib_load || {
            $lib_lib_log error "lib" "in lib-load $1 ($?)" "$f_lib_path" 1
            return $?
          }
        } || true

        eval "LIB_SRC=\"$LIB_SRC $f_lib_path\""
        eval ${lib_id}_lib_loaded=1
        lib_loaded="$lib_loaded $lib_id"
        # FIXME sep. profile/front-end for shell vs user-scripts
        # $lib_lib_log info "lib" "Finished loading ${lib_id}: OK"
        unset lib_id
    }
    shift
  done
}

# Verify lib was loaded or bail out
lib_assert()
{
  test $# -gt 0 || return
  while test $# -gt 0
  do
    test "$(eval "echo \$${1}_lib_loaded")" = "1" || {
      $lib_lib_log error lib "Assert loaded $1" "" 1
      return 1
    }
    shift
  done
}

# After loaded, execute <lib-id>_lib_init() if defined for each lib in load seq.
lib_init()
{
  test $# -gt 0 || set -- $lib_loaded

  # TODO: init only once, set lib_initd=...
  while test $# -gt 0
  do
    type ${1}_lib_init 2> /dev/null 1> /dev/null && {
      ${1}_lib_init || {
        $lib_lib_log error "lib" "in lib-init $1 ($?)" "" 1
        return $?
      }
    }
    shift
  done
}
