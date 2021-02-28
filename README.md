<!-- TODO
- 監視
  - Prometheusラベルが揺れないようにしたい
  - 永続化
- パラメータ化する部分
  - Deploymentレプリカ数
  - ZIPKIN向け先
- istio対応
- Jaeger
  - Headerいるの？
  - どうやって足すのが簡易？
- ArgoCD
- Flagger
- 前提条件
  - バージョン

 -->

## 概要

sock-shop をサンプルアプリとして、Observability と負荷試験自動化スタックを追加した資材です。

- Sockshop 公式 HP：https://microservices-demo.github.io/
- 参考元 Reposity：
  - https://github.com/microservices-demo/microservices-demo
  - https://github.com/fjudith/microservices-demo
  - https://github.com/kashinoki38/microservices-demo/tree/master/deploy/kubernetes

### 導入スタック＆前提条件

- GKE 1.17.15-gke.800
- Istio 1.6.11 (istioctl 使用して導入)
  ```bash
  > istioctl version
  client version: 1.6.11
  control plane version: 1.6.11-gke.0
  data plane version: 1.6.11-gke.0 (15 proxies)
  ```
- prometheus-community/kube-prometheus-stack : Chart version 13.7.2 (Helm 使用して導入)
- loki/loki-stack : 2.3.1 (Helm 使用して導入)
- flagger/flagger : 1.6.3 (Helm 使用して導入)
- flagger/loadtester : 0.18.0 (Docker イメージは独自で Jmeter 追加したイメージ) (Kustomize で導入)
  - kashinoki38/jmeter-flagger
  <!-- - EFK //TODO -->

## セットアップ手順

### 1. istio マニフェストデプロイ (istioctl 使用して導入)

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

### 2. Prometheus （kube-prometheus-stack、Helm 使用して導入）

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

### 3. Loki（Helm 使用して導入）

```bash
> helm upgrade -i loki-stack loki-stack/ -n monitoring
> helm list -n monitoring
NAME                    NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                           APP VERSION
loki-stack              monitoring      1               2021-02-23 01:50:30.7269591 +0900 JST   deployed        loki-stack-2.3.1                v2.1.0

```

### 4. SockShop クラスタデプロイ（Kustomize 使用して導入）

sock-shop namespace と jmeter namespace がデプロイされ、Sock-shop のクラスタ（service, deployment, gateway, virtualservice）と Loadtest のクラスタ（service, deployment, configmap）がデプロイされる。

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

### 5. Flagger （Helm 使用して導入）

Flagger 自体のデプロイは Helm で実施。

```bash
$ helm upgrade -i flagger flagger/ \
 -n istio-sytem \
 —set slack.url=https://hooks.slack.com/services/YOUR-WEBHOOK-ID \
 —set slack.channel=general \
 —set slack.user=flagger

$ helm list -n istio-system
NAME    NAMESPACE       REVISION        UPDATED                                 STATUS          CHART           APP VERSION
flagger istio-system    1               2021-02-23 09:35:00.4708245 +0900 JST   deployed        flagger-1.6.3   1.6.3

$ helm get values flagger
USER-SUPPLIED VALUES:
metricsServer: http://prometheus.monitoring:9090
slack:
  channel: 'general'
  url: https://hooks.slack.com/services/YOUR-WEBHOOK-ID
  user: flagger
```

#### Canary.yaml

Flagger の設定として`canary.yaml`をデプロイする。

```bash
$ kubectl apply -f canary.yaml -n sock-shop
$ kubectl get canary -n sock-shop
NAME        STATUS        WEIGHT   LASTTRANSITIONTIME
sock-shop   Initialized   0        2021-02-23T13:54:07Z
```

Canary をデプロイすると自動的にターゲットリソースが以下のように変更される。  
具体的にはターゲットの Deployment に関連する service に`-primary`と`-canary`が追加｡  
ターゲットの Deployment に`-primary`が追加。  
VirtualService が追加。（Destination が`front-end-primary`と`front-end-canary`）

```bash
$ kubectl get all -n sock-shop | grep front-end
pod/front-end-7b5f8c5b59-hlgxk           2/2     Running   0          72m
pod/front-end-primary-76c6668fbb-qtc2q   2/2     Running   0          3m41s
service/front-end           ClusterIP   10.179.3.9      <none>        80/TCP                       20h
service/front-end-canary    ClusterIP   10.179.5.186    <none>        80/TCP                       3m41s
service/front-end-primary   ClusterIP   10.179.3.89     <none>        80/TCP                       3m41s
deployment.apps/front-end           1/1     1            1           20h
deployment.apps/front-end-primary   1/1     1            1           3m41s
replicaset.apps/front-end-7b5f8c5b59           1         1         1       72m
replicaset.apps/front-end-primary-76c6668fbb   1         1         1       3m41s

$ kubectl get vs
NAME        GATEWAYS                        HOSTS   AGE
front-end   [sock-shop/sock-shop-gateway]   [*]     13s


$ kubectl describe canary sock-shop -n sock-shop | tail
Events:
  Type     Reason  Age                    From     Message
  ----     ------  ----                   ----     -------
  Warning  Synced  5m15s                  flagger  front-end-primary.sock-shop not ready: wa
iting for rollout to finish: observed deployment generation less then desired generation
  Normal   Synced  4m16s (x2 over 5m16s)  flagger  all the metrics providers are available!
  Normal   Synced  4m15s                  flagger  Initialization done! sock-shop.sock-shop
```

##### Flagger の監視対象

対象となる deployment を`.spec.targetRef`に記載。  
当該 Deployment に変更が加わった際に Canary Analysis が開始される。

```yaml
spec:
  # deployment reference
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: front-end
```

##### デプロイ手法と Canary Analysis 設定

`.spe.analysis`にて設定

- Canary Release の場合

  - `maxWeight`%まで`stepWeight`%ずつ新規 Deployment へトランザクションを増加させる割り振る
  - リトライ間隔(`interval`), rollback するまでののリトライ回数(`threshold`)

- Blue/Green デプロイメントの場合
  - `maxWeight`, `stepWeight`を設定せず、`iterations`を設定することで Blue/Green デプロイメントを実現可能。
  - 1 分 ×`iterations`の間、Canary Analysis が実施される。

```yaml
analysis:
  # schedule interval (default 60s)
  interval: 1m
  # max number of failed metric checks before rollback
  threshold: 5
  # max traffic percentage routed to canary
  # percentage (0-100)
  # maxWeight: 50
  # canary increment step
  # percentage (0-100)
  # stepWeight: 10
  # You can use the blue/green deployment strategy by replacing stepWeight/maxWeight with iterations in the analysis spec:
  # With this configuration Flagger will run conformance and load tests on the canary pods for ten minutes.
  iterations: 15
```

##### 判定条件として metrics

`.spec.analysis.metrics`にて Canary Analysis 中の判定条件を設定できる。

```yaml
analysis:
  ...
  metrics:
    - name: request-success-rate
      # minimum req success rate (non 5xx responses)
      # percentage (0-100)
      thresholdRange:
        min: 99
      interval: 1m
    - name: request-duration
      # maximum req duration P99
      # milliseconds
      thresholdRange:
        max: 1000
      interval: 30s
```

###### MetricTemplate

```yaml
apiVersion: flagger.app/v1beta1
kind: MetricTemplate
metadata:
  name: request-duration-custome
  namespace: istio-system
spec:
  provider:
    type: prometheus
    address: http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090
  query: |
    histogram_quantile(0.95, 
      sum(
        irate(
          istio_request_duration_milliseconds_bucket{
            reporter="destination",
            destination_workload=~"front-end",
            destination_workload_namespace=~"sock-shop"
          }[2m]
        )
      ) by (le)
    )
```

`canary.yaml`

```yaml
metrics:
  - name: request-duration-custome
    templateRef:
      name: request-duration-custome
      namespace: istio-system
  ...
```

//TODO
追加のメトリクス（リソース）

##### Flagger の Webhook としての Jmeter

sock-shop の Kustomize にて以下 Deployment と Service が導入済み。

- svc/jmeter-flagger-loadtester
- deploy/jmeter-flagger-loadtester
  `canary.yaml`

```yaml
webhooks:
  ...
  - name: load-test
    url: http://jmeter-flagger-loadtester.jmeter/
    timeout: 5s
    metadata:
      # /jmeter/apache-jmeter-*/bin/jmeter -n -t $1 -Dserver.rmi.ssl.disable=true -JServerName=$2 -JNumOfThreads=$3 -JRampUp=$4 -JDuration=$5 -JTPM=$6
      cmd: '/bin/bash /load_test /scenario.jmx "front-end-canary.sock-shop" "50" "180" "600" "3000"'
```

##### Jmeter Scenario 更新方法

`base/kustomization.yaml`の以下定義により Kustomize で jmx ファイルを ConfigMap 化している。

```yaml
configMapGenerator:
  - name: jmeter-scenario-load-test
    files:
      - scenario.jmx
  - name: jmeter-scenario-user-preparation
    files:
      - preparation.jmx
```

`base/scenario.jmx`を更新し、Kustomize 再実行で ConfigMap が生成される。  
`kubectl apply -f'にて更新すると更新分が`metadata.annotations`に入り切らずエラーが出る。 シナリオを更新する場合は`kubectl create -f`を使用すること。

```bash
$ kustomize build overlays/ | kubectl apply -f -
Error from server (Invalid): error when creating "STDIN": ConfigMap "jmeter-scenario-load-test-kg4kc24f6t" is invalid: metadata.annotations: Too long: must have at most 262144 bytes
Error from server (Invalid): error when creating "STDIN": ConfigMap "jmeter-scenario-user-preparation-gh5g4kgk66" is invalid: metadata.annotations: Too long: must have at most 262144 bytes

# deploy/jmeter-flagger-loadtesterを削除しkubectl create -f で再デプロイすること
$ kubectl delete deploy jmeter-flagger-loadtester
$ kustomize build overlays/ | kubectl create -f -
configmap/jmeter-scenario-load-test-kg4kc24f6t created
configmap/jmeter-scenario-user-preparation-gh5g4kgk66 created
deployment.apps/jmeter-flagger-loadtester created
```

生成される ConfigMap には末尾に Hash が追加されるが、その ConfigMap を参照する Deployment のマニフェストは自動で書き換えられる。

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jmeter-flagger-loadtester
  namespace: jmeter
spec:
...
        volumeMounts:
        - mountPath: /scenario
          name: jmeter-scenario-load-test
          subPath: scenario.jmx
        - mountPath: /scenario
          name: jmeter-scenario-user-preparation
          subPath: preparation.jmx
      volumes:
      - configMap:
          defaultMode: 420
          name: jmeter-scenario-load-test-kg4kc24f6t
        name: jmeter-scenario-load-test
      - configMap:
          defaultMode: 420
          name: jmeter-scenario-user-preparation-gh5g4kgk66
        name: jmeter-scenario-user-preparation

```

##### jmeter-flagger Docker イメージ

`weaveworks/flagger-loadtester`に jmeter 資材を注入したコンテナイメージを以下コマンドでビルド

```bash
$ cd jmeter
$ docker build -t jmeter-flagger -f jmeter-flagger.dockerfile .
$ docker run -d --name jmeter-flagger jmeter-flagger:latest
```

## Jmeter 手動実行

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
