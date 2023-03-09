#!/usr/bin/env bash

### Parsing the arguments ###
while getopts 'i:mj:hcrn:' option;
    do
      case $option in
        n	)	namespace=${OPTARG}   ;;
      esac
done
master_pod=$(kubectl get pod -n "${namespace}" | grep jmeter-master | awk '{print $1}')

kubectl -n "${namespace}" exec -c jmmaster -ti "${master_pod}" -- bash /opt/jmeter/apache-jmeter/bin/stoptest.sh
