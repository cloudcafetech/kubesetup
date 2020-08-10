#!/bin/bash
# Velero backup restore script

NS=$2
CLUSTER=$1

if [ "$CLUSTER" == "" ]; then
 echo "Usage: backup.sh <CLUSTER NAME> <NAMESPACE>"
 echo "List of clusters:"
 kubectl config get-contexts | grep -v NAME | awk '{print $2}'
 exit
fi

if [[ "$NS" == "" ]]; then
 velero backup create velero-bkp-$CLUSTER.all-resources.$(date +'%d-%m-%Y-%H-%M-%S') --include-resources '*'
else
 velero backup create velero-bkp-$CLUSTER.$NS.full-$(date +'%d-%m-%Y-%H-%M-%S') --snapshot-volumes --include-namespaces $NS
fi

echo ""
echo ""

echo "All backup status"
echo "-----------------"

velero get backup