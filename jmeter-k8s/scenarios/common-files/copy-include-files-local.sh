common_split_dataset_dir="../../common-split-dataset";
common_no_split_dataset_dir="../../common-no-split-dataset";

function load_files_from_common_folders() {
    input="./no-split-dataset/include-common-no-split-csv.txt"                                                                        
    while IFS= read -r line
    do
        if [[ "${line}" =~ ^#.*  ]];  then
            echo "skip the comment: $line"
        else
            # echo "$line"
            cp ${common_no_split_dataset_dir}/${line} ./no-split-dataset/
        fi
    done <"$input"

    input="./split-dataset/include-common-split-csv.txt"                                                                        
    while IFS= read -r line
    do
        if [[ "${line}" =~ ^#.*  ]];  then
            echo "skip the comment: $line"
        else
            # echo "$line"
            cp ${common_split_dataset_dir}/${line} ./split-dataset/
        fi
    done <"$input"
 }
 load_files_from_common_folders