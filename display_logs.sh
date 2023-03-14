echo $2 > .chosen_app.txt

if [[ "$1" == "staging" ]];
then
    itermocil staging_logs;
fi
if [[ "$1" == "production" ]];
then
    itermocil production_logs;
fi
