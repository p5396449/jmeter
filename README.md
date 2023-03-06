# Telus AVS Performance Tests 

## Testing in a VM

A VM [jmeter-vm](https://console.cloud.google.com/compute/instancesDetail/zones/northamerica-northeast1-a/instances/jmeter-vm?project=cto-opus-gke-hammer-np-dfe04d) is available for carrying out performance tests. 

JMeter is installed in this VM.

Directory /var/jmeter/tests has all user test folders. JMX test scripts should be stored here for all your tests. All users can read each others tests but can only execute their own tests

### Steps

1. Login (SSH) to your home directory from [GCP Console](https://console.cloud.google.com/compute/instances?project=cto-opus-gke-hammer-np-dfe04d)
2. You can clone the performance testing code from Github 
```bash
git clone https://github.com/telus-csd-tvs/jmeter
git checkout branchname
```
3. To start a test in GCP
```bash
cd branchName
./start_test.sh
```
4. To Stop a test in GCP
```bash
cd checkedOutBranch
./stop_test.sh
```
5. To start a test locally, 
```bash
cd /var/jmeter/tests/yourTestFolder

jmeter -n -t testFile.jmx [-p propertiesFile] [-l resultsFile.jtl] [-j logFile.log] -e -o [outputFolder] -H proxyServerHostIP -P proxyServerPort
```
6. To stop a test locally
```bash
cd /var/jmeter/tests/yourTestFolder
stopjmeter
```
7. To checkin your code
```bash
cd checkedOutBranch
cp /var/jmeter/tests/yourTestFolder/yourJMXFile yourTestFileFolder
git add .
git commit -m yorCommitMessage
git push origin branchName
```
