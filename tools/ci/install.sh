#!/bin/sh

export_stage install && announce_stage

# Call for dev setup
$script_util/parts/init.sh all

test -d $HOME/bin/.git || {
  rm -rf $HOME/bin || true
  ln -s $HOME/build/bvberkum/script-mpe $HOME/bin
}


sudo ln -s $HOME /srv/home-local


# XXX: . $ci_util/deinit.sh
