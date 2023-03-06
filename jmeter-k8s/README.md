
!/usr/bin/env bash
#to access the cluster 
gcloud container clusters get-credentials <GKE-CLUSTER> --region northamerica-northeast1 --project <GCP-PROJECT>



#make sure to set current the right current branch usig git checkout <branch-name> than make the changes in Dockerfile file and any other related changees. 
#then execute the following commands when there isno git TAG like this below (mve3-new-image-test-v2)
# the tag will be created to trigger cloud build 
git commit -a -m "Code clean-up and build new image" && \
git push && \
git tag  && \
git tag -a mve3-v10 -m "Code clean-up and build new image" && \
git push --tag 

# execute the following commands below if the git TAG mve3-new-image-test-v2 already exists. 
# the tag will be deleted and then created again to trigger cloud build 
git commit -a -m "Code clean-up and build new image" && \
git push && \
git tag  && \
git tag -d mve3-v10 && \
git push --delete origin mve3-v10 && \
git tag -a mve3-v10 -m "Code clean-up and build new image" && \
git push --tag 