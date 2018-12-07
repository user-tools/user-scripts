#!/bin/sh


src_lib_load()
{
  test -n "$sentinel_comment" || sentinel_comment="#"
}


# Insert into file using `ed`. Accepts literal content as argument.
# file-insert-at 1:file-name[:line-number] 2:content
# file-insert-at 1:file-name 2:line-number 3:content
file_insert_at_spc=" ( FILE:LINE | ( FILE LINE ) ) INSERT "
file_insert_at()
{
  test -x "$(which ed)" || error "'ed' required" 1

  test -n "$*" || error "arguments required" 1

  local file_name= line_number=
  fnmatch *:[0-9]* "$1" && {
    file_name=$(echo $1 | cut -f 1 -d :)
    line_number=$(echo $1 | cut -f 2 -d :)
    shift 1
  } || {
    file_name=$1; shift 1
    line_number=$1; shift 1
  }

  test -e "$file_name" || error "no file $file_name" 1
  test -n "$1" || error "content expected" 1
  echo "$1" | grep -q '^\.$' && {
    error "Illegal ed-command in input stream"
    return 1
  }

  # use ed-script to insert second file into first at line
  # Note: this loses trailing blank lines
  # XXX: should not have ed period command. Cannot sync this function, file-insert-at
  stderr info "Inserting at $file_name:$line_number"
  echo "${line_number}a
$1
.
w" | ed -s $file_name
}

# Replace one entire line using Sed.
file_replace_at() # ( FILE:LINE | ( FILE LINE ) ) INSERT
{
  test -n "$*" || error "arguments required" 1
  test -z "$4" || error "too many arguments" 1

  local file_name= line_number=

  fnmatch *:[0-9]* "$1" && {
    file_name=$(echo $1 | cut -f 1 -d :)
    line_number=$(echo $1 | cut -f 2 -d :)
    shift 1
  } || {
    file_name=$1; shift 1
    line_number=$1; shift 1
  }

  test -e "$file_name" || error "no file: $file_name" 1
  test -n "$line_number" || error "no line_number: $file_name: '$1'" 1
  test -n "$1" || error "nothing to insert" 1

  set -- "$( echo "$1" | sed 's/[\#&\$]/\\&/g' )"
  $gsed -i $line_number's#.*#'"$1"'#' "$file_name"
}


# Quietly get the first grep match' into where-line and parse out line number
file_where_grep() # 1:where-grep 2:file-path
{
  test -n "$1" || {
    error "where-grep arg required"
    return 1
  }
  test -e "$2" -o "$2" = "-" || {
    error "file-where-grep: file-path or input arg required '$2'"
    return 1
  }
  where_line="$(grep -n "$@" | head -n 1)"
  line_number=$(echo "$where_line" | sed 's/^\([0-9]*\):\(.*\)$/\1/')
}


# XXX: no escape for insert string
file_replace_at_sed()
{
  test -n "$*" || error "arguments required" 1

  local file_name= line_number=

  fnmatch *:[0-9]* "$1" && {
    file_name=$(echo $1 | cut -f 1 -d :)
    line_number=$(echo $1 | cut -f 2 -d :)
    shift 1
  } || {
    file_name=$1; shift 1
    line_number=$1; shift 1
  }

  test -e "$file_name" || error "no file $file_name" 1
  test -n "$line_number" || error "no line_number" 1
  test -n "$1" || error "nothing to insert" 1

  sed $line_number's/.*/'$1'/' $file_name
}


# Start at Line, verbosely output that line and all before matching Grep.
# Stops at non-matching line, returns 0. first-line == 3:Line for not match
grep_to_first() # 1:Grep 2:File-Path 3:Line
{
  from_line=$3
  while true
  do
    tail -n +$3 "$2" | head -n 1 | grep -q "$1" || break
    set -- "$1" "$2" "$(( $3 - 1 ))"
  done
  test $from_line -gt $3 || return
  first_line=$3
}


# Like grep-to-first but go forward matching for Grep.
grep_to_last() # 1:Grep 2:File-Path 3:Line
{
  from_line=$3
  while true
  do
    tail -n +$3 "$2" | head -n 1 | grep -q "$1" || break
    set -- "$1" "$2" "$(( $3 + 1 ))"
  done
  test $from_line -lt $3 || return
  last_line=$3
}

get_lines()
{
  test -n "$*" || error "arguments required" 1

  local file_name= line_number=

  fnmatch *:[0-9]* "$1" && {
    file_name=$(echo $1 | cut -f 1 -d :)
    line_number=$(echo $1 | cut -f 2 -d :)
    shift 1
  } || {
    file_name=$1; shift 1
    line_number=$1; shift 1
  }

  test -n "$1" || set -- 1

  tail -n +$line_number $file_name | head -n $1
}

# find '<func>()' line and see if its preceeded by a comment. Return comment text.
func_comment()
{
  test -n "$1" || error "function name expected" 1
  test -n "$2" -a -e "$2" || error "file expected: '$2'" 1
  test -z "$3" || error "surplus arguments: '$3'" 1

  # find function line number, or return 1 ending function for no comment
  grep_line="$(grep -n "^\s*$1()" "$2" | cut -d ':' -f 1)"
  case "$grep_line" in [0-9]* ) ;; * ) return 1 ;; esac

  lines=$(echo "$grep_line" | count_words)
  test $lines -gt 1 && {
    error "Multiple lines for function '$1'"
    return 1
  }

  # find first comment line
  grep_to_first '^\s*#' "$2" "$(( $grep_line - 1 ))"

  # return and reformat comment lines
  source_lines "$2" $first_line $grep_line | sed -E 's/^\s*#\ ?//'
}

grep_head_comment_line()
{
  head_comment_line="$($ggrep -m 1 '^[[:space:]]*# .*\..*$' "$1")" || return
  echo "$head_comment_line" | sed 's/^[[:space:]]*# //g'
}

# Get first proper comment with period character, ie. retrieve single line
# non-directive, non-header with eg. description line. See alt. grep-list-head.
read_head_comment()
{
  local r=''

  # Scan #-diretives to first proper comment line
  read_lines_while "$1" 'echo "$line" | grep -qE "^\s*#[^ ]"' || r=$?
  test -n "$line_number" || return

  # If no line matched start at firstline
  test -n "$r" && first_line=1 || first_line=$(( $line_number + 1 ))

  # Read rest, if still commented.
  read_lines_while "$1" 'echo "$line" | grep -qE "^\s*#(\ .*)?$"' $first_line || return

  width_lines=$line_number
  last_line=$(( $first_line + $width_lines - 1 ))
  lines_slice $first_line $last_line "$1" | $gsed 's/^\s*#\ \?//'
}

# Echo exact contents of the #-commented file header, or return 1
# backup-header-comment file [suffix-or-abs-path]
backup_header_comment() # Src-File [.header]
{
  test -n "$2" || set -- "$1" ".header"
  fnmatch "/*" "$2" \
    && backup_file="$2" \
    || backup_file="$1$2"
  # find last line of header, add output to backup
  read_head_comment "$1" >"$backup_file" || return $?
}


# Return span of lines from Src, starting output at Start-Line and ending
# Span-Lines later, or at before End-Line.
#
#   Span-Lines = End-Line - Start-Line.
#
# If no end is given, then Src must a file and the end is set to the file
# length. Start is set to 0 if empty.
# TODO: cleanup and manage start-line, end-line, span-lines env code.
#
source_lines() # Src Start-Line End-Line [Span-Lines]
{
  test -f "$1" || return
  test -n "$2" && start_line=$2 || start_line=0
  test -n "$Span_Lines" || Span_Lines=$4
  test -n "$Span_Lines" || {
    end_line=$3
    test -n "$end_line" || end_line=$(count_lines "$1")
    Span_Lines=$(( $end_line - $start_line ))
  }
  tail -n +$start_line $1 | head -n $Span_Lines
}


source_line() # Src Start-Line
{
  source_lines "$1" "$2" "$(( $2 + 1 ))"
}


# Given a shell script line with a source command to a relative or absolute
# path (w/o shell vars or subshells), replace that line with the actual contents
# of the sourced file.
expand_source_line() # Src-File Line
{
  test -f "$1" || error "expand_source_line file '$1'" 1
  test -n "$2" || error "expand_source_line line" 1
  local srcfile="$(source_lines "$1" "$2" "" 1 | awk '{print $2}')"
  test -f "$srcfile" || error "src-file $*: '$srcfile'" 1
  expand_line "$@" "$srcfile" || return
  trueish "$keep_source" || rm $srcfile
  info "Replaced line with resolved src of '$srcfile'"
}


# See expandline, uses and removes 'srcfile' if requested
expand_srcline()
{
  test -f "$srcfile" || error "src-file $*: '$srcfile'" 1
  expand_line "$@" "$srcfile"
  trueish "$keep_source" || rm $srcfile
  info "Replaced line with resolved src of '$srcfile'"
}


# Strip sentinel line and insert external file
expand_line() # Src-File Line Include-File
{
  file_truncate_lines "$1" "$(( $2 - 1 ))" "$2" &&
  file_insert_at $1:$(( $2 - 1 )) "$(cat "$3")"
}