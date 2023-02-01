blue=$(tput setaf 6)
normal=$(tput sgr0)

__get_directories () {
    local directories=("$(ls -d */)")	
    echo $directories
}

print_branches () {
    directories=$(__get_directories)
    for directory in ${directories[@]}; do
        cd $directory
        inside_git_repo="$(git rev-parse --is-inside-work-tree 2>/dev/null)"

        if [ "$inside_git_repo" ]; then
            branch=$(git branch --show-current)
            printf 'Project: %-60s Branch: %s\n' "${blue}$directory${normal}" "${blue}$branch${normal}"
        fi
        cd ..
    done
}

base_dir=$1
current_dir=$PWD
cd $base_dir
print_branches
cd $current_dir
