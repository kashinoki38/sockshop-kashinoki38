<!-- TODO
- 監視
  - Prometheusラベルが揺れないようにしたい
  - 永続化
- パラメータ化する部分
  - Deploymentレプリカ数
  - ZIPKIN向け先
- istio対応
  - unknown(Kialiで確認可能)
  - InboundPassThrough(Kialiで確認可能)
  - Jaeger
    - Headerいるの？
    - どうやって足すのが簡易？
  - カスタマイズ項目
- Logging
  - Loki? EFK?
- ArgoCD
- Flagger
- 前提条件
  - バージョン

 -->

## 概要

sockshop の Kubernetes サンプルをカスタマイズした Kustomize 資材です。

- Sockshop 公式 HP：https://microservices-demo.github.io/
- 参考元 Reposity：
  - https://github.com/microservices-demo/microservices-demo
  - https://github.com/fjudith/microservices-demo
  - https://github.com/kashinoki38/microservices-demo/tree/master/deploy/kubernetes

### 前提条件

- GKE 1.17.15-gke.800
- Istio 1.6.11
  ```bash
  > istioctl version
  client version: 1.6.11
  control plane version: 1.6.11-gke.0
  data plane version: 1.6.11-gke.0 (15 proxies)
  ```
- prometheus-community/kube-prometheus-stack : Chart version 13.7.2
- loki-stack : 2.3.1.
- EFK //TODO

## セットアップ手順

### istio マニフェストデプロイ

事前に Kubernetes マニフェスト確認

```bash
$ istioctl manifest generate -f istio-manifest-v1.6.11.yaml
```

マニフェスト適用

```bash
$ istioctl upgrade -f istio-manifest-v1.6.11.yaml
...
✔ Istio core installed
✔ Istiod installed
✔ Ingress gateways installed
✔ Addons installed
✔ Installation complete
```

#### Kiali の設定

##### Credential（Secret 作成）

```bash
$ KIALI_USERNAME=$(read -p 'Kiali Username: ' uval && echo -n $uval | base64)
Kiali Username: admin
$ KIALI_PASSPHRASE=$(read -sp 'Kiali Passphrase: ' pval && echo -n $pval | base64)
Kiali Passphrase:
$ cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: kiali
  namespace: istio-system
  labels:
    app: kiali
type: Opaque
data:
  username: $KIALI_USERNAME
  passphrase: $KIALI_PASSPHRASE
EOF
```

### Prometheus

`kube-prometheus-stack`(旧 Prometheus-Operator)を使用。  
https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack

```bash
> kubectl create ns monitoring
> helm upgrade -i kube-prometheus-stack -f kube-prometheus-stack/values.yaml  kube-prometheus-stack/ -n monitoring
Release "kube-prometheus-stack" has been upgraded. Happy Helming!
NAME: kube-prometheus-stack
LAST DEPLOYED: Wed Feb 17 04:29:42 2021
NAMESPACE: monitoring
STATUS: deployed
REVISION: 2
NOTES:
kube-prometheus-stack has been installed. Check its status by running:
  kubectl --namespace monitoring get pods -l "release=kube-prometheus-stack"

Visit https://github.com/prometheus-operator/kube-prometheus for instructions on how to create & configure Alertmanager and Prometheus instances using the Operator.

> helm list -n monitoring
NAME                    NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                           APP VERSION
kube-prometheus-stack   monitoring    1               2021-02-19 01:53:54.9194679 +0900 JST   deployed        kube-prometheus-stack-13.7.2    0.45.0

> kubectl get po -n monitoring
NAME                                                       READY   STATUS    RESTARTS   AGE
alertmanager-kube-prometheus-stack-alertmanager-0          2/2     Running   0          2m33s
kube-prometheus-stack-grafana-5c4fbd566f-vmkjw             2/2     Running   0          2m44s
kube-prometheus-stack-kube-state-metrics-db6d5b5cb-kpszl   1/1     Running   0          2m44s
kube-prometheus-stack-operator-f55f8b965-rdtnc             1/1     Running   0          2m44s
kube-prometheus-stack-prometheus-node-exporter-8v852       1/1     Running   0          2m44s
kube-prometheus-stack-prometheus-node-exporter-drhsv       1/1     Running   0          2m44s
kube-prometheus-stack-prometheus-node-exporter-gr9xh       1/1     Running   0          2m44s
kube-prometheus-stack-prometheus-node-exporter-jtbk8       1/1     Running   0          2m44s
kube-prometheus-stack-prometheus-node-exporter-szqgx       1/1     Running   0          2m44s
kube-prometheus-stack-prometheus-node-exporter-tggqj       1/1     Running   0          2m44s
prometheus-kube-prometheus-stack-prometheus-0              2/2     Running   0          2m32s

> kubectl get svc -n monitoring
NAME                                             TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
alertmanager-operated                            ClusterIP   None            <none>        9093/TCP,9094/TCP,9094/UDP   74m
kube-prometheus-stack-alertmanager               ClusterIP   10.179.7.210    <none>        9093/TCP                     74m
kube-prometheus-stack-grafana                    ClusterIP   10.179.0.232    <none>        80/TCP                       74m
kube-prometheus-stack-kube-state-metrics         ClusterIP   10.179.13.106   <none>        8080/TCP                     74m
kube-prometheus-stack-operator                   ClusterIP   10.179.7.213    <none>        443/TCP                      74m
kube-prometheus-stack-prometheus                 ClusterIP   10.179.9.170    <none>        9090/TCP                     74m
kube-prometheus-stack-prometheus-node-exporter   ClusterIP   10.179.5.94     <none>        9100/TCP                     74m
prometheus-operated                              ClusterIP   None            <none>        9090/TCP                     74m

```

#### Dashboard へのアクセス

外部公開していなくてもポートフォワードでダッシュボードへアクセス可能。  
`port-forward.sh`使える。

```bash
> ./port-forward.sh
Forwarding from 127.0.0.1:3000 -> 3000
Forwarding from [::1]:3000 -> 3000
```

##### Grafana の Credential

`grafana.adminPassword`で`admin`ユーザのパスワードを設定可能。  
以下デフォルト。  
| user | password |
| ----- | ------------- |
| admin | prom-operator |

#### Grafana Dashboard 追加

Helm チャートの`grafana.sidecar.dashboards.enabled`を`true`にしているため、
Grafana ダッシュボード JSON を`grafana.sidecar.dashboards.label`で定義されたラベルを持つ ConfigMap で定義するとインポートしてくれる。

##### Dashboard の ConfigMap マニフェスト作成方法

https://github.com/prometheus-community/helm-charts/blob/main/charts/kube-prometheus-stack/hack/sync_grafana_dashboards.py  
上記 py を参考にローカルの JSON を読むように改修。

26 行目からの`charts`リストに以下のようなダッシュボード JSON リンクを追記。

```python
# Source files list
charts = [
  ...
    {
        'source': 'grafana-dashboards-base/node-exporter-dashboard.json',
        'destination': 'kube-prometheus-stack/templates/grafana/dashboards-1.14',
        'type': 'json',
        'min_kubernetes': '1.14.0-0'
    },
  ...
```

`sync_grafana_dashboards.py`実行。  
Dashboard 用の ConfigMap yaml が生成される。

```bash
> python3 sync_grafana_dashboards.py
> ll ./kube-prometheus-stack/templates/grafana/dashboards-1.14/
...
-rwxrwxrwx 1 kashinoki38 kashinoki38 294K Feb 19 02:50 pod-detail-dashboard.yaml*
...
```

ConfigMap マニフェストを生成後、`helm upgrade`を実施することで ConfigMap がデプロイされた後、Grafana にもダッシュボードが反映される。

```bash
> helm upgrade kube-prometheus-stack -f kube-prometheus-stack/values.yaml kube-prometheus-stack/ -n monitoring
Release "kube-prometheus-stack" has been upgraded. Happy Helming!
NAME: kube-prometheus-stack
LAST DEPLOYED: Fri Feb 19 02:51:06 2021
NAMESPACE: monitoring
STATUS: deployed
REVISION: 4
NOTES:
kube-prometheus-stack has been installed. Check its status by running:
  kubectl --namespace monitoring get pods -l "release=kube-prometheus-stack"

Visit https://github.com/prometheus-operator/kube-prometheus for instructions on how to create & configure Alertmanager and Prometheus instances using the Operator.

> kubectl get cm
...
kube-prometheus-stack-pod-detail-dashboard                1      5m59s
...
```

### Loki

```bash
> helm upgrade -i loki-stack loki-stack/ -n monitoring
```

### SockShop クラスタデプロイ

sock-shop namespace と jmeter namespace がデプロイされる。

```bash
$ kubectl apply -f sock-shop-ns.yaml
$ kubectl apply -f jmeter-ns.yaml
$ kustomize build overlays/ | kubectl apply -f -
```

**アンデプロイ**

```bash
$ kustomize build overlays/ | kubectl delete -f -
```

#### カスタマイズ

`overlays/`配下の`kustomization.yaml`で Kustomize のパッチ当て。

## Jmeter 実行

#### ユーザデータ準備

```bash
> cd jmeter
> vi start_test.sh #負荷量調整
...
24: # /jmeter/apache-jmeter-*/bin/jmeter -n -t $1 -Dserver.rmi.ssl.disable=true -JServerName=$2 -JNumOfThreads=$3 -JRampUp=$4 -JDuration=$5 -JTPM=$6
25: kubectl -n $namespace exec -ti $master_pod -- /bin/bash /load_test "$test_name" "34.84.80.98" "10" "10" "600" "300"

> bash start_test.sh
Enter path to the jmx file
preparation.jmx #指定
```

#### 試験実施

```bash
> cd jmeter
> vi start_test.sh #負荷量調整
...
24: # /jmeter/apache-jmeter-*/bin/jmeter -n -t $1 -Dserver.rmi.ssl.disable=true -JServerName=$2 -JNumOfThreads=$3 -JRampUp=$4 -JDuration=$5 -JTPM=$6
25: kubectl -n $namespace exec -ti $master_pod -- /bin/bash /load_test "$test_name" "34.84.80.98" "100" "180" "900" "6000"

> bash start_test.sh
Enter path to the jmx file
scenario.jmx #指定
```

## デフォルト SockShop からのカスタム箇所

### istio の導入

### namespace への`istio-injection`追加。

`deploy/kubernetes/manifests/00-sock-shop-ns.yaml`

```yaml
kind: Namespace
metadata:
  name: sock-shop
  labels:
    istio-injection: enabled
```

### 各 deployment への`sidecar.istio.io/proxyCPU`追加。

`deploy/kubernetes/manifests/carts-dep.yaml`

```yaml
metadata:
  labels:
    app: carts
  annotations:
    sidecar.istio.io/proxyCPU: "10m"
spec:
  containers:
    - name: carts
```

### 各 deployment のサービスポート名追加。

（Istio テレメトリ収集のための修正）  
https://kiali.io/documentation/validations/#_kia0601_port_name_must_follow_protocol_suffix_form  
https://istio.io/docs/ops/configuration/traffic-management/protocol-selection/#manual-protocol-selection  
＞ Istio では、サービスポートが「protocol-suffix」の命名形式に従う必要があります。「-suffix」部分はオプションです。命名がこの形式と一致しない場合（または未定義の場合）、Istio は定義で定義されているプロトコルではなく、すべてのトラフィック TCP を処理します。ダッシュはプロトコルとサフィックスの間に必要な文字です。たとえば、「http2foo」は無効ですが、「http2-foo」は有効です（http2 プロトコルの場合）。

`deploy/kubernetes/manifests/carts-svc.yml`

```yaml
spec:
  ports:
    - name: http-carts
      protocol: TCP
      port: 80
      targetPort: 80
  selector:
    app: carts
```

### Grafana のダッシュボード

### Prometheus Operator のスクレイプ

#### service monitor

以下の`service monitor`について、node 名を`node`ラベルとして取ってくるように`relabeling`を追加

- kube-state-metrics
- node exporter

```yaml
  serviceMonitor:
    ...
    relabelings:
      - sourceLabels: [__meta_kubernetes_pod_node_name]
        targetLabel: node
    ...
```

#### additionalScrapeConfigs

Istio のテレメトリをスクレイプするように`additionalScrapeConfigs`を追加。

```yaml
additionalScrapeConfigs:
  # Mixer scrapping. Defaults to Prometheus and mixer on same namespace.
  #
  - job_name: "istio-mesh"
    kubernetes_sd_configs:
      - role: endpoints
        namespaces:
          names:
            - istio-system
    relabel_configs:
      - source_labels:
          [__meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
        action: keep
        regex: istio-telemetry;prometheus
  # Scrape config for envoy stats
  - job_name: "envoy-stats"
    metrics_path: /stats/prometheus
    kubernetes_sd_configs:
      - role: pod

    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_container_port_name]
        action: keep
        regex: ".*-envoy-prom"
      - source_labels:
          [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: $1:15090
        target_label: __address__
      - action: labeldrop
        regex: __meta_kubernetes_pod_label_(.+)
      - source_labels: [__meta_kubernetes_namespace]
        action: replace
        target_label: namespace
      - source_labels: [__meta_kubernetes_pod_name]
        action: replace
        target_label: pod_name
```

### Kiali の Prometheus 向き先

```yaml
spec:
  ...
  values:
  ...
    kiali:
    ...
      prometheusAddr: http://prometheus.monitoring.svc.cluster.local:9090
```

### Jaeger/ZIPKIN の向き先

//TODO

```yaml
env:
  - name: ZIPKIN
    value: zipkin.jaeger.svc.cluster.local
```

## Jmeter
