#!/bin/bash
version=`cat pom.xml | grep version | head -n3 | tail -n1`
extractedVersion=${version%</*}
extractedVersion=${extractedVersion##*>}
echo $extractedVersion | pbcopy
echo "Copied $extractedVersion to clipboard"

