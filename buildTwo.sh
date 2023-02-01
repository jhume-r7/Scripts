#!/bin/bash
mvn clean install
if [[ "$?" -ne 0 ]] ; then
	cd ..
    cd ~/Code/proton/$1
    mvn clean install
fi
