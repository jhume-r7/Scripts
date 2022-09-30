#!/bin/bash
checkout_ucv_branch () {
	echo "===== Sync With Develop ====="
	git stash;
	git checkout develop;
	git pull;
	echo "===== Creating UCV Branch ====="
	git branch Updating-Common-Version;
	git checkout Updating-Common-Version;
}

update_pom_version () {
	echo "===== Updating Common Version ====="
	file_name="pom.xml"
	new_version=$1
	sed -i '' "s/proton-common.version>.*</proton-common.version>$new_version</g" $file_name
}


build_commit () {
	git add pom.xml;
	git commit -m "Updating Common Version";
}

create_pr () {
	echo "===== Pushing! ====="
	if git push; then
		echo "===== Creating PR! ====="
		url=$( gh pr create -B develop -t "Updating Common Version to $1" -b "Updating Common Version" | grep https)
		echo $url >> pr_urls.txt
		open $url
	else
		echo "!!!!! Git Push Failed. !!!!!"
	fi

}

update_and_pr () {
	checkout_ucv_branch
	update_pom_version $1
	mvn clean install
	if [[ "$?" -ne 0 ]] ; then
		echo "====== Build failed, rolling back ====="
		git restore pom.xml
		git checkout develop
		git branch -D Updating-Common-Version
	else
		build_commit
		create_pr $1
	fi
}

has_pom () {
	myarray=(`find ./ -maxdepth 1 -name "pom.xml"`)
	if [ ${#myarray[@]} -gt 0 ]; then 
	    echo true 
	else 
	    echo false
	fi
}

get_ignored_files () {
	oIFS="$IFS"; IFS=, ; set -- $1 ; IFS="$oIFS"
	for i in "$@"; do
		ignored_files+=($i)
	done
}

empty_pr_urls_file () {
	echo "" > pr_urls.txt
}

main () {
	empty_pr_urls_file
	local files=("$(ls -d */)")
	for file in ${files[@]}; do
		cd $file
		if ! [[ " ${ignored_files[@]} " =~ " ${file%%/*} " ]]; then
			has_pom="$(has_pom)"
			if [ "$has_pom" == "true" ]; then
				echo "===== $file: Update Common? y/n ====="
				read;
				if [ "${REPLY}" == "y" ]; then
					update_and_pr $1
				else
					echo "===== Skipping $file ====="
				fi
			fi
		fi
		cd ..
	done
}

ignored_files=(proton-common-pom)
get_ignored_files $2
version=$1
main $version

