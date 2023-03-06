#!/usr/bin/env bash
export JVM_ARGS="-Xms5g -Xmx5g -XX:NewSize=5g -XX:MaxNewSize=5g" 

source ../../common-files/copy-include-files-local.sh

#make calculation here and pass them as  parameters

# jmeter.sh -t dummy-test-v1.jmx  -Dno_split_dataset_dir=./no-split-dataset/ -Dsplit_dataset_dir=./split-dataset/ -Gsplit_dataset_dir1=./split-dataset1/ -Gapi_env=GKE-6.8
jmeter.sh -t dummy-test-v1.jmx  -Dno_split_dataset_dir=./no-split-dataset/ -Dsplit_dataset_dir=./split-dataset/ -Gglobal.properties
