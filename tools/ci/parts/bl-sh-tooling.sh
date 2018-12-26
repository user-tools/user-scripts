#!/bin/ash


# CI baseline: Check executable tools
for x in bin/* tools/sh/init.sh tools/sh/init-here.sh
do
  test -e "$x" -a -x "$x" || {
    print_yellow "" "No executable path '$x', skipped"
    continue
  }

  ./$x && print_green $x OK || print_red $x ERR:$?
done

# CI baseline: Check shell scripts
for x in sh-init-here sh-test sh-package sh-composure
do
  test -e $x || {
    print_yellow "" "No shell script '$x', skipped"
    continue
  }

  sh ./$x && print_green $x OK || print_red $x ERR:$?
done
