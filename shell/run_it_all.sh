#!/usr/bin/bash -xv
#/usr/bin/env bash

echo 'Install DNF, AWSCLI, ANSIBLE, PYTHON3 & BOTO3'
which dnf >/dev/null 2>&1
if [ $? -ne 0 ]; then
  sudo yum install dnf -y
fi

which python3 >/dev/null 2>&1
if [ $? -ne 0 ]; then
  sudo yum install python3 python3-pip python3-devel libselinux-python3 -y
fi

which ansible >/dev/null 2>&1
if [ $? -ne 0 ]; then
  sudo python3 -m pip install ansible awscli wheel setuptools pyOpenSSL acme-tiny boto boto3 botocore
fi

##echo AWS CONFIGURE
aws configure

echo CREATE SELF SIGNED SSL CERTIFICATE
cd ~/aws-ecs-svc/
mkdir -p docker/certs && cd docker/certs

##Create the config
cat <<EOF > castore.cfg
[ req ]
default_bits = 2048
default_keyfile = ran-devops-net.key
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no
[ req_distinguished_name ]
C = US
ST = VA
L = Richmond
O = devops.net
OU = devops.net
CN= ran.devops.net ## Use your domain
emailAddress = user@email.com ## Use your email address
[v3_ca]
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid:always,issuer:always
basicConstraints = CA:true
[v3_req]
## Extensions to add to a certificate request
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
EOF

openssl genrsa -out castore.key 2048
openssl req -x509 -new -nodes -key castore.key -days 3650 -config castore.cfg -out castore.pem

openssl genrsa -out ran-devops-net.key 2048
openssl req -new -key ran-devops-net.key -out ran-devops-net.csr -config castore.cfg
openssl x509 -req -in ran-devops-net.csr -CA castore.pem -CAkey castore.key -CAcreateserial -out ran-devops-net.crt -days 365

cd ../../ansible
pwd
# Download & install vault, terraform, jq
ansible-playbook ./play-build.yml --tags prepare_management_server,first_time_run
# Build VPC, ECS, ECR  
ansible-playbook ./play-build.yml --skip-tags prepare_management_server,first_time_run

cd ../terraform/vpc-ecs-n-ecr-environment
DOCKER_REPO_URL=`terraform output|grep docker_repo_url|awk '{print $3}'`
codecommit_ssh_url=`terraform output|grep codecommit_repo_url|awk '{print $3}'`
git clone $codecommit_ssh_url app_source
cd app_source
cp ../helloApp/dockerfile-dir/buildspec.yml  ../helloApp/dockerfile-dir/Dockerfile-web  ../helloApp/dockerfile-dir/index.html .
git add .
git commit -m 'master init'
git push origin master
cd ../helloApp/dockerfile-dir/
$(aws ecr get-login --no-include-email --region $AWS_DEFAULT_REGION)
IMAGE_REPO_NAME=hello-app
IMAGE_TAG=1
docker build -t $IMAGE_REPO_NAME:$IMAGE_TAG -f ./Dockerfile-web .
docker tag $IMAGE_REPO_NAME:$IMAGE_TAG $DOCKER_REPO_URL:$IMAGE_TAG
#docker tag $IMAGE_REPO_NAME:$IMAGE_TAG $DOCKER_REPO_URL:latest
echo Build completed on `date`
echo Pushing the Docker image...
docker push $DOCKER_REPO_URL:$IMAGE_TAG

echo docker_image=${DOCKER_REPO_URL}:IMAGE_TAG > ../terraform.tfvars
