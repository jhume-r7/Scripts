#!/bin/bash
versionBumpType=$1
version=`cat pom.xml | grep version | head -n3 | tail -n1`
extractedVersion=${version%-SNAPSHOT</*}
extractedVersion=${extractedVersion##*>}

versionsArray=(${extractedVersion//./ })

if [[ "$versionBumpType" == "Major" ]] ; then
    (( versionsArray[0]++ ))
    versionsArray[1]=0
    versionsArray[2]=0
fi
if [[ "$versionBumpType" == "Minor" ]] ; then
    (( versionsArray[1]++ ))
    versionsArray[2]=0
fi
if [[ "$versionBumpType" == "Revision" ]] ; then
    (( versionsArray[2]++ ))
fi

branch_name="RELEASE-${versionsArray[0]}.${versionsArray[1]}.${versionsArray[2]}"

git checkout develop;
git pull;
git checkout -b $branch_name
url=$( git push | grep https)
echo $url
open $url

