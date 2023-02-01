#!/bin/bash

__get_directories () {
    local directories=("$(ls -d */)")	
    echo $directories
}

__has_pom () {
    myarray=(`find ./ -maxdepth 1 -name "pom.xml"`)
    if [ ${#myarray[@]} -gt 0 ]; then 
        echo "true"
    else 
        echo "false"
    fi
}

__has_common_version () {
    common_version=`cat pom.xml | grep proton-common.version`
    if [[ $common_version ]]; then
        echo true
    else
        echo false
    fi
}

__get_maven_projects () {
    directories=$(__get_directories)
    for directory in ${directories[@]}; do
        cd $directory
        if [ $(__has_pom) == "true" ]; then 
            #This is a global variable and therefore doesn't need echoed
            maven_projects+=("$directory")
        fi
        cd ..
    done
}

get_maven_projects_with_common () {
    __get_maven_projects
    for project in ${maven_projects[@]}; do
        cd $project
        if [ $(__has_common_version) == "true" ]; then 
            maven_projects_with_common+=("$project")
        fi
        cd ..
    done
}

checkout_updating_version_branch () {
    git stash;
    git fetch -p;
    git checkout develop;
    git pull;
    git branch $BRANCH_NAME;
    git checkout $BRANCH_NAME;
}

rollback_to_develop () {
    git restore pom.xml;
    git checkout develop;
    git branch -D $BRANCH_NAME;
}

git_commit () {
    git add pom.xml;
    git commit -m "Updating common version to $NEW_VERSION";
}
update_dependency_version () {
    sed -i '' "s/proton-common.version>.*</proton-common.version>$NEW_VERSION</g" "pom.xml"
}

batch_updates_and_mci () {
    get_maven_projects_with_common
    for project in ${maven_projects_with_common[1]}; do
        cd $project
        checkout_updating_version_branch
        update_dependency_version
        mvn clean install
        if [[ "$?" -ne 0 ]]; then
            failures+=("$project")
            rollback_to_develop
        else
            successes+=("$project")
            git_commit
        fi
        cd ..
    done
}

__create_gh_pr () {
    url=$(gh pr create --title $BRANCH_NAME --body "Updating common version to $NEW_VERSION" --base develop | grep https)
    echo $url >> ../pr_urls
    open $url
}

create_prs () {
    projects=("$@")
    for project in ${projects[@]}; do
        cd $project
        branch=$(git branch --show-current)
        if [ $branch == $BRANCH_NAME ]; then
            echo "Push $project? (y)es/(n)o/(r)ollback"
            read choice
            if [[ $choice == "y" ]]; then
                git push;
                __create_gh_pr
            fi
            if [[ $choice == "r" ]]; then
                rollback_to_develop
            fi
            cd ..
        else
            echo "$project not on Updating-Common-Version Branch"
        fi
    done
}

clean_pr_urls_file () {
    rm pr_urls
}

print_successes_and_failures () {
    echo ""
    echo "===== UPDATES COMPLETE ====="
    echo ""
    echo "Succeeded Update and MCIs:"
    printf '%s\n' "${successes[@]}"
    echo ""
    echo "Failed Update and MCIs:"
    printf '%s\n' "${failures[@]}"
}

is_in_base_folder () {
    #Forward slash after PWD as other scripts in dev tools require it in the BASE_DIR variable
    if [[ ! $PWD/ == $PROTON_REPOS_BASE_DIR ]]; then
        echo "===== NOT IN PROTON BASE DIRECTORY ====="
        echo "===== Exiting ====="
        exit 1
    fi
}

main(){
    is_in_base_folder
    clean_pr_urls_file
    batch_updates_and_mci
    print_successes_and_failures
    echo "Do you want to push Successes (y/n)"
    read choice
    if [[ $choice == "y" ]]; then
        create_prs ${successes[@]}
    else
        echo "Not pushing branches"
    fi
}

PROTON_REPOS_BASE_DIR=$1
NEW_VERSION=$2
BRANCH_NAME=$3

main
