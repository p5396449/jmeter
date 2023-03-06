#!/usr/bin/env bash
export https_proxy=

########## for account creation 
docker build --no-cache --platform linux/amd64 -t amatveev74/avs-jmeter-acc-creation:1.0 .

docker tag amatveev74/avs-jmeter-acc-creation:1.0 gcr.io/cto-opus-gke-hammer-np-dfe04d/avs-jmeter-acc-creation:1.0

docker tag amatveev74/avs-jmeter-acc-creation:1.0 gcr.io/cto-video-svc-registry-np-f69f/avs-jmeter-acc-creation:1.0 

docker push gcr.io/cto-opus-gke-hammer-np-dfe04d/avs-jmeter-acc-creation:1.0


  gcloud builds submit --region=northamerica-northeast1 --tag gcr.io/cto-video-svc-registry-np-f69f/avs-jmeter-acc-creation:1.0

#PROJECT ID = cto-opus-gke-hammer-np-dfe04d
docker images
docker tag e6cc9916d366 amatveev74/avs-jmeter:1.0
docker push amatveev74/avs-jmeter:1.0 


docker tag e6cc9916d366 amatveev74/avs-jmeter-stress-test:1.0
docker push amatveev74/avs-jmeter-stress-test:1.0 
image: amatveev74/avs-jmeter-stress-test:1.0


# JMeter image from scatch 
docker images
docker tag 18808cbaf373 amatveev74/avs-jmeter:2.0
docker push amatveev74/avs-jmeter:2.0  


docker image rm
or 
d rmi image-ID


#clean all cache  
docker system prune -a 

d run -dit k8s-jmeter

gcloud artifacts repositories create jmeter-docker-repo --repository-format=docker --location=northamerica-northeast1-a --description="AVS JMeter Docker repository"



################################ Jan 26, 2023
unset https_proxy
docker build --no-cache --compress --platform linux/amd64 -t amatveev74/jmgcpgke:1.0 .
docker push amatveev74/jmgcpgke:1.0