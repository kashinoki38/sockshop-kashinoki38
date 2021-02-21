ps aux |egrep " kubectl port-forward" | awk '{system("kill "$2)}'
