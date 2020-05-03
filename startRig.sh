#!/bin/bash

#set -o xtrace
set -e

aws ec2 run-instances --launch-template LaunchTemplateId=lt-039e68a1ae9c451d8