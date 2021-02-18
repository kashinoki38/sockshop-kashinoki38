kubectl get po -n monitoring-2 -l app=prometheus |awk '$3=="Running"{system ("kubectl port-forward -n monitoring-2 "$1" 9090:9090" )}' &
kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 &
kubectl port-forward svc/tracing 16686:16686 -n istio-system &
kubectl port-forward svc/kiali 20001:20001 -n istio-system &
