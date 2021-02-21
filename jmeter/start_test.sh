#!/usr/bin/env bash
namespace=jmeter-2
jmx="$1"
[ -n "$jmx" ] || read -p 'Enter path to the jmx file ' jmx

if [ ! -f "$jmx" ];
then
    echo "Test script file was not found in PATH"
    echo "Kindly check and input the correct file path"
    exit
fi

test_name="$(basename "$jmx")"

#Get Master pod details

master_pod=`kubectl -n $namespace get po | grep jmeter-master | awk '{print $1}'`
kubectl -n $namespace cp "socks.csv" "$master_pod:/socks.csv"
kubectl -n $namespace cp "userlist.csv" "$master_pod:/userlist.csv"
kubectl -n $namespace cp "$jmx" "$master_pod:/$test_name"

## Echo Starting Jmeter load test

kubectl -n $namespace exec -ti $master_pod -- /bin/bash /load_test "$test_name"
# /jmeter/apache-jmeter-*/bin/jmeter -n -t $1 -Dserver.rmi.ssl.disable=true