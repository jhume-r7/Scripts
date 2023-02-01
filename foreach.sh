#############################################
# Do For all repos
# runs a command in each child directory
# that is a git repository under directory $1
# Usage:
#   - _for_each_repo <directory> <command>...
#############################################
_for_each_repo() {
   start=$(date +%s)
    REPO_DIR="${1:-pwd}"
    BATCH=$2
    arrBATCH=($(echo $BATCH | tr ";" "\n"))
    shift 2
    CMD=($@)
    git config --global color.ui always
    START_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"  WARNINGS=0
    OUTPUT_FDS=()
    for CODE_DIR in ${arrBATCH[@]}; do
      exec {OUTPUT_FD}<> <(do_for_repo "$REPO_DIR${CODE_DIR}" "${START_DIR}" $CMD)
      OUTPUT_FDS=("${OUTPUT_FDS[@]}" ${OUTPUT_FD})
    done
    RESFILE=$(mktemp)
    for OUTPUT_FD in "${OUTPUT_FDS[@]}"; do
      # read from the fd until EOF then close it
      cat <&"${OUTPUT_FD}" | tee -a $RESFILE
      exec {OUTPUT_FD}<&-
    done
    set +x
    git config --global --unset color.ui
    # Return to Start
    cd ${START_DIR}
    end=$(date +%s)
    printf "start: %s, end: %s, took %s seconds" "$(date -r ${start})" "$(date -r ${end})" "$((end-start))" >&2
}

do_for_repo() {
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

repos_batch_0=(
    "proton-common-pom"

    "proton-common"

    "proton-external-clients-ipims-app;
    proton-external-clients-bifrost;
    proton-external-clients-idr;
    proton-external-clients-mcdb;
    proton-alert-store-app;
    proton-static-data-store-app"

"proton-notification-consolidation-consumer-app"
    "proton-alert-actions-app;
    proton-alert-consumer-app;
    proton-external-notifier-app;
    proton-key-service-app"
    "proton-alert-enrichment-consumer-app;
    proton-alert-search-app"
    "proton-task-management-app"
    "proton-change-notification-consumer-bifrost-app;
    proton-regional-api-app;
    proton-env-tools"
    "proton-global-coordinator-app"
    "proton-class3-api-gateway-app;
    proton-class1-api-gateway-app"
)



for DIR_BATCH in ${repos_batch_0[@]}; do
    _for_each_repo $1 $DIR_BATCH $2 
done
