#############################################
# Do For all repos
# runs a command in each child directory
# that is a git repository under directory $1
# Usage:
#   - _for_each_repo <directory> <command>...
#############################################
function _for_each_repo() {
   start=$(date +%s)
    REPO_DIR="${1:-pwd}"
    shift
    CMD="${@}"
    git config --global color.ui always
    START_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"  WARNINGS=0
    OUTPUT_FDS=()
    for CODE_DIR in `find ${REPO_DIR} -type d -maxdepth 1 | sort `; do
      exec {OUTPUT_FD}<> <(do_for_repo "${CODE_DIR}" "${START_DIR}" $@)
      OUTPUT_FDS=("${OUTPUT_FDS[@]}" ${OUTPUT_FD})
    done
    RESFILE=$(mktemp)
    for OUTPUT_FD in "${OUTPUT_FDS[@]}"; do
      # read from the fd until EOF then close it
      cat <&"${OUTPUT_FD}" | tee -a $RESFILE
      exec {OUTPUT_FD}<&-
    done
    git config --global --unset color.ui
    # Return to Start
    cd ${START_DIR}
    end=$(date +%s)
    printf "start: %s, end: %s, took %s seconds" "$(date -r ${start})" "$(date -r ${end})" "$((end-start))" >&2
}

#############################################
# Do For Repo
# runs a command in a directory if it is a git repo
# Usage:
#   - do_for_repo <directory> <command>...
#############################################
function do_for_repo() {
  local CODE_DIR=$1
  local START_DIR=$2
  shift 2
  CMD=$@
  git -C ${CODE_DIR} rev-parse --is-inside-work-tree &> /dev/null
  IS_REPO_RESPONSE=$?
  if [ ${IS_REPO_RESPONSE} -eq 0 ]; then
     cd ${CODE_DIR}
     CMDOUT=$(eval ${CMD} 2>&1)
     RC=$?
      if [[ -n "${CMDOUT}" ]]; then
         if [[ "${RC}" -gt 0 ]] ; then
            COLOR=${RED}
         else
            COLOR=${YELLOW}
         fi
          printf "%s\n%s\n\n" "${COLOR}${CODE_DIR}${NORMAL}" "${CMDOUT}"
      fi
  fi
}

_for_each_repo $1 $2
