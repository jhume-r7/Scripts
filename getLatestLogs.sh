context=$1
app=$2
echo $app
blue=$(tput setaf 6)
normal=$(tput sgr0)

#Switch to chosen context
kubectl config use-context $context; 

#Get data about pods
fieldsWide=$(kubectl get pods --sort-by=.status.startTime -o wide | grep $app | tail -n 2)

#Loop over pods
for field in ${fieldsWide[@]};
do
    #If pod name, print pod name and get logs
    if [[ "$field" =~ ^proton.* ]]; then
        pod_name=${field#"/pod"}
        printf '\n\n\n======= %s ======== \n\n' "${blue}$pod_name${normal}"
        kubectl exec $field -- sh -c "cd logs; cat everything.log; (bash || ash || sh)" | head -n 50
    fi
    #If time elapsed since created, print it - This serves as double check it's gotten the correct ones
    if [[ $field =~ [0-9]+[smh]$ ]]; then
        printf '\n======= %s ======== \n\n' "${blue}$field${normal}"
    fi
done




