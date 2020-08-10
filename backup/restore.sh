#!/bin/bash
# Velero backup  script

BKP=$1

if [[ "$BKP" == "" ]]; then
 echo "Usage: restore.sh <Velero backup name>"
 velero get backup
 exit
fi

velero restore create velero-restore-$(hostname)-$(date +'%d-%m-%Y-%H-%M-%S') --from-backup $BKP --restore-volumes=true

echo ""
echo ""

echo "All restore status"
echo "-----------------"

velero get restore