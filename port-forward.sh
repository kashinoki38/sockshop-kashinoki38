kubectl get po -n monitoring -l app=prometheus |awk '$3=="Running"{system ("kubectl port-forward -n monitoring "$1" 9090:9090" )}' &
kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 -n monitoring &
kubectl port-forward svc/tracing 16686:80 -n istio-system &
kubectl port-forward svc/kiali 20001:20001 -n istio-system &
