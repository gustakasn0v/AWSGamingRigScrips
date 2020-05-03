#!/bin/bash

#set -o xtrace
set -e

oldVersion=`aws ec2 describe-images --filters "Name=platform,Values=windows" --owners 829274763558 --output text --query 'Images[*].Name' | cut -d"V" -f2`
newVersion=$(($oldVersion+1))
echo "Old version is $oldVersion. New version is $newVersion. Press enter to continue"
read
oldImageId=`aws ec2 describe-images --filters "Name=platform,Values=windows" "Name=name,Values=GamingRigV$oldVersion" --owners 829274763558 --output text --query 'Images[0].ImageId'`
oldImageSnapshotId=`aws ec2 describe-images --filters "Name=platform,Values=windows" "Name=name,Values=GamingRigV$oldVersion" --owners 829274763558 --output text --query 'Images[0].BlockDeviceMappings[0].Ebs.SnapshotId'`
instanceId=`aws ec2 describe-instances --output text --filters Name=instance-state-name,Values=running Name=image-id,Values=$oldImageId --query 'Reservations[0].Instances[0].InstanceId'`
echo "InstanceId $instanceId. Press enter to continue"
read

newImageName="GamingRigV$newVersion"
# Image the rig. 
# Possibly use xargs -I {}
echo 'Imaging the rig...'
newImageId=`aws ec2 create-image --name $newImageName --instance-id $instanceId --output text`

# Delete old AMI when the new one is available
newImageState=`aws ec2 describe-images --filters "Name=image-id,Values=$newImageId" --output text --query 'Images[0].State'`
while [ "$newImageState" != "available" ]
do
	echo "New image not available, waiting 10 seconds..."
	sleep 10
	newImageState=`aws ec2 describe-images --filters "Name=image-id,Values=$newImageId" --output text --query 'Images[0].State'`
done

# Cancel the running Spot request and instance
echo "New image available. Terminating instance..."
spotRequestId=`aws ec2 describe-spot-instance-requests --filters 'Name=state, Values=active' --output text --query 'SpotInstanceRequests[0].SpotInstanceRequestId'`
aws ec2 cancel-spot-instance-requests --spot-instance-request-ids $spotRequestId
aws ec2 terminate-instances --instance-ids $instanceId

# Update launch template
echo "Updating old image..."
oldLaunchTemplateVersion=`aws ec2 describe-launch-template-versions --launch-template-name GamingRigTemplate --query 'LaunchTemplateVersions[0].VersionNumber'`
aws ec2 create-launch-template-version --launch-template-name GamingRigTemplate --source-version $oldLaunchTemplateVersion --launch-template-data '{"ImageId":"'"$newImageId"'"}'
newLaunchTemplateVersion=`aws ec2 describe-launch-template-versions --launch-template-name GamingRigTemplate --query 'LaunchTemplateVersions[0].VersionNumber'`
aws ec2 modify-launch-template --launch-template-name GamingRigTemplate --default-version $newLaunchTemplateVersion

echo "Deleting old image. Press enter to continue"
read
aws ec2 deregister-image --image-id $oldImageId
aws ec2 delete-snapshot --snapshot-id $oldImageSnapshotId