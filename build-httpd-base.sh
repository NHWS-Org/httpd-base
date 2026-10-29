#!/bin/bash 
ImageName=napalmzrpi/httpd-base:latest

cd ./httpd-base

#--platform linux/arm/v7,linux/arm64/v8,linux/amd64 \
docker buildx build \
--push \
--platform linux/arm64,linux/amd64 \
--tag $ImageName .