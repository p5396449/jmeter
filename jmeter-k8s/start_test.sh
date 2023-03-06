#!/usr/bin/env bash

#=== FUNCTION ================================================================
#        NAME: logit
# DESCRIPTION: Log into file and screen.
# PARAMETER - 1 : Level (ERROR, INFO)
#           - 2 : Message
#
#===============================================================================

# jmeter directory in pods
jmeter_directory="/opt/jmeter/apache-jmeter/bin"
GLOBAL_PROPERTIES_CONST="global.properties"

# scenarios/
#      codebase (mve2-p2-mix-scenarios, mve2-p2-single-call etc)
#          jmx (jmx folder that has to match to jmx script:  mve2-p2-mix-scenarios-60kCUs, )
scenarioRootDir="scenarios"
common_split_dataset_dir="./${scenarioRootDir}/common-split-dataset"
common_no_split_dataset_dir="./${scenarioRootDir}/common-no-split-dataset"

logit()
{
    case "$1" in
        "INFO")
            echo -e " [\e[94m $1 \e[0m] [ $(date '+%d-%m-%y %H:%M:%S') ] $2 \e[0m" ;;
        "WARN")
            echo -e " [\e[93m $1 \e[0m] [ $(date '+%d-%m-%y %H:%M:%S') ]  \e[93m $2 \e[0m " && sleep 2 ;;
        "ERROR")
            echo -e " [\e[91m $1 \e[0m] [ $(date '+%d-%m-%y %H:%M:%S') ]  $2 \e[0m " ;;
    esac
}

#=== FUNCTION ================================================================
#        NAME: usage
# DESCRIPTION: Helper of the function
# PARAMETER - None
#
#===============================================================================
usage()
{
  logit "INFO" "-j <filename.jmx>"
  logit "INFO" "-n <namespace>"
  logit "INFO" "-b <codebase>"
  logit "INFO" "-c flag to split and copy csv if you use csv in your test"
  logit "INFO" "-m flag to copy fragmented jmx present in ${scenarioRootDir}/project/module if you use include controller and external test fragment"
  logit "INFO" "-i <injectorNumber> to scale slaves pods to the desired number of JMeter injectors"
  logit "INFO" "-r flag to enable report generation at the end of the test"
  logit "INFO" "-G flag to include file with global properties. Example: -G \"${GLOBAL_PROPERTIES_CONST}\" or -G ./scenarios/common-files/any-file-global.properties"
  exit 1
}

### Parsing the arguments ###
while getopts 'i:b:mj:G:hcrn:' option;
    do
      case $option in
        n	)	namespace=${OPTARG} ;;
        b   )   codebase=${OPTARG} ;;        
        c   )   csv=1 ;;
        m   )   module=1 ;;
        r   )   enable_report=1 ;;
        j   )   jmx=${OPTARG} ;;
        i   )   nb_injectors=${OPTARG} ;; 
        G   )   globalPropertiesFile=${OPTARG} ;;      
        h   )   usage ;;
        ?   )   usage ;;
      esac
done

if [ "$#" -eq 0 ]
  then
    usage
fi

check_input_vars() 
{
  ### CHECKING VARS ###
    if [ -z "${namespace}" ]; then
        logit "ERROR" "Namespace not provided!"
        usage
        namespace=$(awk '{print $NF}' "${PWD}/namespace_export")
    fi

    if [ -z "${codebase}" ]; then
        logit "ERROR" "Codebase not provided!"
        usage  
    fi

    if [ -z "${jmx}" ]; then
        #read -rp 'Enter the name of the jmx file ' jmx
        logit "ERROR" "jmx jmeter project not provided!"
        usage
    fi

    jmx_dir="${jmx%%.*}"

    if [ ! -f "${scenarioRootDir}/${codebase}/${jmx_dir}/${jmx}" ]; then
        logit "ERROR" "Test script file was not found in ${scenarioRootDir}/${codebase}/${jmx_dir}/${jmx}"
        usage
    fi

    # uncoment to make it mandatory 
    # logit "INFO" "File  with global properties: ${globalPropertiesFile}"
    # if [ ! -f "${globalPropertiesFile}" ]; then
    #     logit "ERROR" "File \"${globalPropertiesFile}\" with global properties was not found. The search was performed from the current directory."
    #     usage
    # fi
}



recreating_pod_set()
{
    # Recreating each pods
    logit "INFO" "Recreating pod set"
    kubectl -n "${namespace}" delete -f k8s/jmeter/jmeter-master.yaml -f k8s/jmeter/jmeter-slave.yaml 2> /dev/null
    kubectl -n "${namespace}" apply -f k8s/jmeter
    kubectl -n "${namespace}" patch job jmeter-slaves -p '{"spec":{"parallelism":0}}'
    logit "INFO" "Waiting for all slaves pods to be terminated before recreating the pod set"
    while [[ $(kubectl -n ${namespace} get pods -l jmeter_mode=slave -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "" ]]; do echo "$(kubectl -n ${namespace} get pods -l jmeter_mode=slave )" && sleep 1; done
}

starting_jmeter_slave_pods()
{
    # Starting jmeter slave pods 
    if [ -z "${nb_injectors}" ]; then
        logit "WARNING" "Keeping number of injector to 1"
        kubectl -n "${namespace}" patch job jmeter-slaves -p '{"spec":{"parallelism":1}}'
    else
        logit "INFO" "Scaling the number of pods to ${nb_injectors}. "
        kubectl -n "${namespace}" patch job jmeter-slaves -p '{"spec":{"parallelism":'${nb_injectors}'}}'
        logit "INFO" "Waiting for pods to be ready"

        end=${nb_injectors}
        for ((i=1; i<=end; i++))
        do
            validation_string=${validation_string}"True"
        done

        while [[ $(kubectl -n ${namespace} get pods -l jmeter_mode=slave -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}' | sed 's/ //g') != "${validation_string}" ]]; 
        do 
          echo "$(kubectl -n ${namespace} get pods -l jmeter_mode=slave )" && sleep 1; 
        done
        logit "INFO" "Finish scaling the number of pods."
    fi
}

get_pod_details()
{
    #Get Master pod details
    logit "INFO" "Waiting for master pod to be available"
    while [[ $(kubectl -n ${namespace} get pods -l jmeter_mode=master -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "$(kubectl -n ${namespace} get pods -l jmeter_mode=master )" && sleep 1; done

    master_pod=$(kubectl get pod -n "${namespace}" | grep jmeter-master | awk '{print $1}')


    #Get Slave pod details
    slave_pods=($(kubectl get pods -n "${namespace}" | grep jmeter-slave | grep Running | awk '{print $1}'))
    slave_num=${#slave_pods[@]}
    slave_digit="${#slave_num}"
}


copying_modules_and_config_to_pods()
{
    # Copying module and config to pods
    if [ -n "${module}" ]; then
        logit "INFO" "Using modules (test fragments), uploading them in the pods"
        module_dir="${scenarioRootDir}/${codebase}/module"

        logit "INFO" "Number of slaves is ${slave_num}"
        logit "INFO" "Processing directory.. ${module_dir}"

        for modulePath in $(ls ${module_dir}/*.jmx)
        do
            module=$(basename "${modulePath}")

            for ((i=0; i<end; i++))
            do
                printf "Copy %s to %s on %s\n" "${module}" "${jmeter_directory}/${module}" "${slave_pods[$i]}"
                kubectl -n "${namespace}" cp -c jmslave "${modulePath}" "${slave_pods[$i]}":"${jmeter_directory}/${module}" &
            done            
            kubectl -n "${namespace}" cp -c jmmaster "${modulePath}" "${master_pod}":"${jmeter_directory}/${module}" &
        done

        logit "INFO" "Finish copying modules in slave pod"
    fi
}

##################################################################################################
# Copying JMX script to slaves pods
##################################################################################################
copying_jmx_and_no_split_files_to_slave_pods()
{
    logit "INFO" "Copying ${jmx} to slaves pods"
    logit "INFO" "Number of slaves is ${slave_num}"

    for ((i=0; i<end; i++))
    do
        logit "INFO" "Copying ${scenarioRootDir}/${codebase}/${jmx_dir}/${jmx} to ${slave_pods[$i]}"
        
        # logit "INFO" "BEFORE ls -la ${jmeter_directory} for ${slave_pods[$i]}"
        # kubectl exec  -c jmslave "${slave_pods[$i]}" -- ls -la  "${jmeter_directory}"


        # //TODO it looks like we  don't need the one
        kubectl cp -c jmslave "${scenarioRootDir}/${codebase}/${jmx_dir}/${jmx}" -n "${namespace}" "${slave_pods[$i]}:/opt/jmeter/apache-jmeter/bin/" &
        # kubectl cp -c jmslave "${scenarioRootDir}/${codebase}/${jmx_dir}/${jmx}" -n "${namespace}" "${slave_pods[$i]}:/opt/jmeter/bin/" &
        
        
        # Copying no-split-dataset to slave pods
        logit "INFO" "Uploading test specific no split CSV files to pods"
        no_split_dataset_dir="./${scenarioRootDir}/${codebase}/${jmx_dir}/no-split-dataset"
        logit "DEBUG" "Uploading CSV file to pod no_split_dataset_dir=${no_split_dataset_dir}"

       for allNonSplitFiles in $(ls ${no_split_dataset_dir}/*.*)
            do
                logit "INFO" "properties=${allfiles}"
                onefile="${allNonSplitFiles##*/}"
                logit "INFO" "Processing file.. $onefile"
                printf "Copy ${no_split_dataset_dir}/${onefile}" "${slave_pods[$i]}"
                kubectl -n "${namespace}" cp -c jmslave "${no_split_dataset_dir}/${onefile}" "${slave_pods[$i]}":"${jmeter_directory}/${onefile}" &  
            done

    done # for i in "${slave_pods[@]}"

    logit "INFO" "Finish copying scenario to slaves pod"

    for allNonSplitFiles in $(ls ${no_split_dataset_dir}/*.*)
            do
                logit "INFO" "properties=${allfiles}"
                onefile="${allNonSplitFiles##*/}"
                logit "INFO" "Processing file.. $onefile"
                printf "Copy ${no_split_dataset_dir}/${onefile} into ${master_pod}"                
                kubectl -n "${namespace}" cp -c jmmaster "${no_split_dataset_dir}/${onefile}" "${master_pod}":"${jmeter_directory}/${onefile}" &
            done

    logit "INFO" "Copying ${scenarioRootDir}/${codebase}/${jmx_dir}/${jmx} into ${master_pod}"
    kubectl cp -c jmmaster "${scenarioRootDir}/${codebase}/${jmx_dir}/${jmx}" -n "${namespace}" "${master_pod}:${jmeter_directory}" &
    
    # # copy file with global parameters 
    # if [ -f "${scenarioRootDir}/${codebase}/${jmx_dir}/${GLOBAL_PROPERTIES_CONST}" ]; then
    #   logit "INFO" "Copying ${scenarioRootDir}/${codebase}/${jmx_dir}/${GLOBAL_PROPERTIES_CONST} into master pod: ${master_pod}"
    #   kubectl cp -c jmmaster "${scenarioRootDir}/${codebase}/${jmx_dir}/${GLOBAL_PROPERTIES_CONST}" -n "${namespace}" "${master_pod}:${jmeter_directory}" &
    # else 
    #   logit "WARN" "No gobal.properties file was found in this folder: ${scenarioRootDir}/${codebase}/${jmx_dir}. Note that if default parameters are defined, they will be used!" 
    # fi

    # logit "DEBUG" "Check if global properties file: \"${globalPropertiesFile}\" exists on master pod: ${master_pod}"
    if [ -f "${globalPropertiesFile}" ]; then
      logit "INFO" "Copying \"${globalPropertiesFile}\" to master pod: ${master_pod}"
      kubectl cp -c jmmaster "${globalPropertiesFile}" -n "${namespace}" "${master_pod}:${jmeter_directory}/${GLOBAL_PROPERTIES_CONST}" &
    else 
      kubectl rm -f -c jmmaster -n "${namespace}" "${master_pod}:${jmeter_directory}/${GLOBAL_PROPERTIES_CONST}" &
      logit "WARN" "Starting with no \"${GLOBAL_PROPERTIES_CONST}\" file (not provided). Note that if default parameters are defined, they will be used! Existing on the pod \"${GLOBAL_PROPERTIES_CONST}\" file was removed!"
    fi

}

install_plugins_on_slave_pods()
{
    logit "INFO" "Installing needed plugins on slave pods"
    ## Starting slave pod 
    {
        echo "cd ${jmeter_directory}"    
        echo "export _JAVA_OPTIONS=-Djava.io.tmpdir=${jmeter_directory}"        
        echo "sh PluginsManagerCMD.sh install-for-jmx ${jmx} > plugins-install.out 2> plugins-install.err"        

        echo "jmeter-server -Dserver.rmi.localport=50000 -Dserver_port=1099 -Jserver.rmi.ssl.disable=true >> jmeter-injector.out 2>> jmeter-injector.err &"
        echo "trap 'kill -10 1' EXIT INT TERM"
      
        # echo "java -jar /opt/jmeter/apache-jmeter/lib/jolokia-java-agent.jar start JMeter >> jmeter-injector.out 2>> jmeter-injector.err"
        echo "java -Xms1024m -Xmx2560m -XX:MaxMetaspaceSize=512m -server -jar /opt/jmeter/apache-jmeter/lib/jolokia-java-agent.jar start JMeter >> jmeter-injector.out 2>> jmeter-injector.err"

        # echo "java -jar /opt/jmeter/lib/jolokia-java-agent.jar start JMeter >> jmeter-injector.out 2>> jmeter-injector.err"
        echo "wait"
    } > "${scenarioRootDir}/${codebase}/${jmx_dir}/jmeter_injector_start.sh"
}

# Clean up common split dataset 
clean_up_common_split_dataset()
{
    for ((i=0; i<=9; i++))
        do
        if ls ${scenarioRootDir}/common-split-dataset/*.csv${i}* 1> /dev/null 2>&1; then
            printf "Remove all these %s files\n" "${scenarioRootDir}/common-split-dataset/*.csv${i}"
            rm ${scenarioRootDir}/common-split-dataset/*.csv${i}*
        fi
    done
}


# Clean up split dataset 
clean_up_split_dataset()
{
    for ((i=0; i<=9; i++))
        do
        if ls ${scenarioRootDir}/${codebase}/${jmx_dir}/split-dataset/*.csv${i}* 1> /dev/null 2>&1; then
            printf "Remove all these %s files\n" "${scenarioRootDir}/${codebase}/${jmx_dir}/split-dataset/*.csv${i}"
            rm ${scenarioRootDir}/${codebase}/${jmx_dir}/split-dataset/*.csv${i}*
        fi
    done
}


#################################### common-split-dataset #############################################
copy_common_split_dataset()
{
    # Copying common-split-dataset to slave pods
    if [ -n "${csv}" ]; then
        logit "INFO" "Splitting and uploading Common CSV files to the pods"
        dataset_dir=./${scenarioRootDir}/common-split-dataset

        for csvfilefull in $(ls ${dataset_dir}/*.csv)
            do
                logit "INFO" "csvfilefull=${csvfilefull}"
                csvfile="${csvfilefull##*/}"
                logit "INFO" "Processing file.. $csvfile"
                lines_total=$(cat "${csvfilefull}" | wc -l)
                slave_num_split=$((slave_num-1))
                if [[ ${slave_num_split} -gt 1 ]]
                then     
                    logit "INFO" "lines_total: \"${lines_total}\"; slave_num: \"${slave_num}\" "       
                    lines_per_file=$((lines_total/slave_num))
                    logit "INFO" "lines_per_file  ${lines_per_file}"
                    logit "INFO" "split --suffix-length=\"${slave_digit}\" -d -l \"${lines_per_file}\" \"${csvfilefull}\" \"${csvfilefull}/\""
                    split --suffix-length="${slave_digit}" -d -l "${lines_per_file}" "${csvfilefull}" "${csvfilefull}"
                    #use gnu split (typically on Mac) - install it first. It should support this --suffix-length
                    #gsplit --suffix-length="${slave_digit}" -d -l "${lines_per_file}" "${csvfilefull}" "${csvfilefull}"
                    
                    for ((i=0; i<end; i++))
                    do
                        if [ ${slave_digit} -eq 2 ] && [ ${i} -lt 10 ]; then
                            j=0${i}
                        elif [ ${slave_digit} -eq 2 ] && [ ${i} -ge 10 ]; then
                            j=${i}
                        elif [ ${slave_digit} -eq 3 ] && [ ${i} -lt 10 ]; then
                            j=00${i}
                        elif [ ${slave_digit} -eq 3 ] && [ ${i} -ge 100 ]; then
                            j=${i}
                        elif [ ${slave_digit} -eq 3 ] && [ ${i} -ge 10 ]; then
                            j=0${i}
                        elif [ ${slave_digit} -eq 4 ] && [ ${i} -ge 1000 ]; then
                            j=${i}
                        elif [ ${slave_digit} -eq 4 ] && [ ${i} -ge 100 ]; then
                            j=0${i}    
                        elif [ ${slave_digit} -eq 4 ] && [ ${i} -ge 10 ]; then
                            j=00${i}
                        elif [ ${slave_digit} -eq 4 ] && [ ${i} -lt 10 ]; then
                            j=000${i}    
                        else 
                            j=${i}                    
                        fi  
                
                        printf "Copy %s to %s on %s\n" "${csvfilefull}${j}" "${csvfile}" "${slave_pods[$i]}"
                        kubectl -n "${namespace}" cp -c jmslave "${csvfilefull}${j}" "${slave_pods[$i]}":"${jmeter_directory}/${csvfile}" &                     
                    done      
                else                
                    i=0
                    printf "Copy %s to %s on %s\n" "${csvfilefull}" "${csvfile}" "${slave_pods[$i]}"
                    kubectl -n "${namespace}" cp -c jmslave "${csvfilefull}" "${slave_pods[$i]}":"${jmeter_directory}/${csvfile}" & 
                fi
            
        done
    fi
}

copy_split_dataset_to_slave_pods()
{

    # Copying split-dataset to slave pods
    if [ -n "${csv}" ]; then
        logit "INFO" "Splitting and uploading Test Specific CSV files to the pods"
        dataset_dir=./${scenarioRootDir}/${codebase}/${jmx_dir}/split-dataset

        for csvfilefull in $(ls ${dataset_dir}/*.csv)
            do
                logit "INFO" "csvfilefull=${csvfilefull}"
                csvfile="${csvfilefull##*/}"
                logit "INFO" "Processing file.. $csvfile"
                lines_total=$(cat "${csvfilefull}" | wc -l)
                slave_num_split=$((slave_num-1))
                if [[ ${slave_num_split} -ge 1 ]]
                then              
                    lines_per_file=$((lines_total/slave_num))
                    logit "INFO" "lines_total: \"${lines_total}\"; slave_num: \"${slave_num}\" "   
                    logit "INFO" "split --suffix-length=\"${slave_digit}\" -d -l \"${lines_per_file}\" \"${csvfilefull}\" \"${csvfilefull}/\""
                    split --suffix-length="${slave_digit}" -d -l "${lines_per_file}" "${csvfilefull}" "${csvfilefull}"
                    #use gnu split (typically on Mac) - install it first. It should support this --suffix-length
                    #gsplit --suffix-length="${slave_digit}" -d -l "${lines_per_file}" "${csvfilefull}" "${csvfilefull}"
                    
                    for ((i=0; i<end; i++))
                    do
                        if [ ${slave_digit} -eq 2 ] && [ ${i} -lt 10 ]; then
                            j=0${i}
                        elif [ ${slave_digit} -eq 2 ] && [ ${i} -ge 10 ]; then
                            j=${i}
                        elif [ ${slave_digit} -eq 3 ] && [ ${i} -lt 10 ]; then
                            j=00${i}
                        elif [ ${slave_digit} -eq 3 ] && [ ${i} -ge 100 ]; then
                            j=${i}
                        elif [ ${slave_digit} -eq 3 ] && [ ${i} -ge 10 ]; then
                            j=0${i}
                        elif [ ${slave_digit} -eq 4 ] && [ ${i} -ge 1000 ]; then
                            j=${i}
                        elif [ ${slave_digit} -eq 4 ] && [ ${i} -ge 100 ]; then
                            j=0${i}    
                        elif [ ${slave_digit} -eq 4 ] && [ ${i} -ge 10 ]; then
                            j=00${i}
                        elif [ ${slave_digit} -eq 4 ] && [ ${i} -lt 10 ]; then
                            j=000${i}    
                        else 
                            j=${i}                    
                        fi
                                                
                        printf "Copy %s to %s on %s\n" "${csvfilefull}${j}" "${csvfile}" "${slave_pods[$i]}"
                        kubectl -n "${namespace}" cp -c jmslave "${csvfilefull}${j}" "${slave_pods[$i]}":"${jmeter_directory}/${csvfile}" & 
                    done
                else                                    
                    i=0
                    printf "Copy %s to %s on %s\n" "${csvfilefull}" "${csvfile}" "${slave_pods[$i]}"
                    kubectl -n "${namespace}" cp -c jmslave "${csvfilefull}" "${slave_pods[$i]}":"${jmeter_directory}/${csvfile}" & 
                fi            
        done
    fi

    wait
    logit "INFO" "Done with coping CSV files"

}

start_jmeter_on_pods()
{
    for ((i=0; i<end; i++))
    do
        logit "INFO" "Starting jmeter server on pod=${i}; pod name=${slave_pods[$i]} in parallel"
        kubectl cp -c jmslave "${scenarioRootDir}/${codebase}/${jmx_dir}/jmeter_injector_start.sh" -n "${namespace}" "${slave_pods[$i]}:/opt/jmeter/jmeter_injector_start"
        kubectl exec -c jmslave -i -n "${namespace}" "${slave_pods[$i]}" -- /bin/bash "/opt/jmeter/jmeter_injector_start" &  
    done
}

copy_load_test_sh_file_to_master()
{
    slave_list=$(kubectl -n ${namespace} describe endpoints jmeter-slaves-svc | grep ' Addresses' | awk -F" " '{print $2}')
    logit "INFO" "JMeter slave list : ${slave_list}"
    slave_array=($(echo ${slave_list} | sed 's/,/ /g'))

    if [ -n "${enable_report}" ]; then
        report_command_line="--reportatendofloadtests --reportoutputfolder ./report/report-${jmx}-$(date +"%F_%H%M%S")"
    fi

    echo "slave_array=(${slave_array[@]}); index=${slave_num} && while [ \${index} -gt 0 ]; do for slave in \${slave_array[@]}; do if echo 'test open port' 2>/dev/null > /dev/tcp/\${slave}/1099; then echo \${slave}' ready' && slave_array=(\${slave_array[@]/\${slave}/}); index=\$((index-1)); else echo \${slave}' not ready'; fi; done; echo 'Waiting for slave readiness'; sleep 2; done" > "${scenarioRootDir}/${codebase}/${jmx_dir}/load_test.sh"

    { 
        echo "echo \"Installing needed plugins for master\""            
        echo "cd ${jmeter_directory}"
        echo "export _JAVA_OPTIONS=-Djava.io.tmpdir=${jmeter_directory}"
        echo "sh PluginsManagerCMD.sh install-for-jmx ${jmx}" 
        
        echo "echo \"Starting PT test now...\""
        # echo "jmeter ${param_host} ${param_user} ${report_command_line} --logfile ./report/${jmx}_$(date +"%F_%H%M%S").jtl --nongui --testfile ${jmx} -Dserver.rmi.ssl.disable=true --remoteexit --remotestart ${slave_list} >> jmeter-master.out 2>> jmeter-master.err &"        
        echo "jmeter -G${GLOBAL_PROPERTIES_CONST} ${report_command_line} --logfile ./report/${jmx}_$(date +"%F_%H%M%S").jtl --nongui --testfile ${jmx} -Dserver.rmi.ssl.disable=true --remoteexit --remotestart ${slave_list} >> jmeter-master.out 2>> jmeter-master.err &"

        echo "trap 'kill -10 1' EXIT INT TERM"
      
        echo "java  -Xms3072m -Xmx3584m -XX:MaxMetaspaceSize=512m -server -DSun.rmi.transport.connectionTimeout=4200000 -jar /opt/jmeter/apache-jmeter/lib/jolokia-java-agent.jar start JMeter >> jmeter-master.out 2>> jmeter-master.err"
            
        echo "wait"      
        #echo "if [ -d \"./report/\" ];  then if [ \"$(ls -A ./report/)\" ]; then echo \" gsutil cp ./report/*.* gs://gke-hammer-jmeter-logs/\"; fi fi"
    } >> "${scenarioRootDir}/${codebase}/${jmx_dir}/load_test.sh"

    logit "INFO" "Copying ${scenarioRootDir}/${codebase}/${jmx_dir}/load_test.sh into  ${master_pod}:/opt/jmeter/load_test"
    kubectl cp -c jmmaster "${scenarioRootDir}/${codebase}/${jmx_dir}/load_test.sh" -n "${namespace}" "${master_pod}:/opt/jmeter/load_test"


    logit "INFO" "LOAD_TEST AFTER ls -la ${jmeter_directory} for ${slave_pods[$i]}"
    kubectl exec  -c jmmaster  "${master_pod}" "${master_pod}"  -- ls -la /opt/jmeter/load_test
}

load_files_from_common_folders()
{
    if [ -f "./${scenarioRootDir}/${codebase}/${jmx_dir}/no-split-dataset/include-common-no-split-csv.txt" ]; then
        input="./${scenarioRootDir}/${codebase}/${jmx_dir}/no-split-dataset/include-common-no-split-csv.txt"                                                                        
        while IFS= read -r line
        do
            if [[ "${line}" =~ ^#.*  ]];  then
                echo "skip the comment: $line"
            else
                # echo "$line"
                cp ${common_no_split_dataset_dir}/${line} ./${scenarioRootDir}/${codebase}/${jmx_dir}/no-split-dataset/
            fi
        done <"$input"
    fi

    if [ -f "./${scenarioRootDir}/${codebase}/${jmx_dir}/split-dataset/include-common-split-csv.txt" ]; then 
        input="./${scenarioRootDir}/${codebase}/${jmx_dir}/split-dataset/include-common-split-csv.txt"                                                                        
        while IFS= read -r line
        do
            if [[ "${line}" =~ ^#.*  ]];  then
                echo "skip the comment: $line"
            else
                # echo "$line"
                cp ${common_split_dataset_dir}/${line} ./${scenarioRootDir}/${codebase}/${jmx_dir}/split-dataset/
            fi
        done <"$input"
    fi
}
printEmptyLines() 
{
    printf "\n\n\n\n\n\n\n\n\n\n"
}

###########################################################################################################################

check_input_vars
load_files_from_common_folders

recreating_pod_set

starting_jmeter_slave_pods

get_pod_details

copying_modules_and_config_to_pods

copying_jmx_and_no_split_files_to_slave_pods

install_plugins_on_slave_pods

clean_up_common_split_dataset

clean_up_split_dataset

copy_load_test_sh_file_to_master


# uncomment to make a pause to review the pods
# printEmptyLines 
# read -p "=================================================> Please press Enter to proceed:" proceed

# copy_common_split_dataset;
copy_split_dataset_to_slave_pods;
start_jmeter_on_pods;

# uncomment to make a pause to review the pods
# printEmptyLines 
# read -p "=================================================> Please type Y and Enter to start test:" proceed
# if [ $proceed != "Y" ] 
# then
#    exit 0
# fi

logit "INFO" "Starting the performance test"
kubectl exec -c jmmaster -i -n "${namespace}" "${master_pod}" -- /bin/bash "/opt/jmeter/load_test"
clean_up_split_dataset;