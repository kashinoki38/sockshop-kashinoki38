# 概要

sockshop の Kubernetes サンプルをカスタマイズした Kustomize 資材です。

- Sockshop 公式 HP：https://microservices-demo.github.io/
- 参考元 Reposity：https://github.com/kashinoki38/microservices-demo/tree/master/deploy/kubernetes

# 実行方法

```bash
$ kustomize build overlays/ | k apply -f -
```

# カスタム箇所

## istio の導入

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

### Jaeger/ZIPKIN の向き先

//TODO

```yaml
env:
  - name: ZIPKIN
    value: zipkin.jaeger.svc.cluster.loca
```

## prometheus operator

## Jmeter
