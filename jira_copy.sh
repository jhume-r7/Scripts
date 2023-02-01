function task {
   export task=$(git branch --show-current | grep -o "ALERT-\d[0-9]*")
}

function jira {
  task;
 url="https://issues.corp.rapid7.com/browse/$task"
  echo $url | pbcopy
  echo "Copied $url to clipboard"
}

jira;
