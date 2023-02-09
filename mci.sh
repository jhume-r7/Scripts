#!/bin/bash
mvn clean install
if [[ "$?" -ne 0 ]] ; then
	say techno
else
	say tech yes
fi
