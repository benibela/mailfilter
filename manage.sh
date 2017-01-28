#/bin/bash
DIR="$( cd "$( dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")" )" && pwd )"
source $DIR/../../../manageUtils.sh

mirroredProject mailfilter

BASE=$HGROOT/programs/data/mailfilter

case "$1" in
mirror)
  syncHg  
;;

esac

