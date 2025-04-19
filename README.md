# k8s-kind-helm-basic チュートリアル

> **目的:** kind クラスタ上に **Helm だけ** を使って Node.js API コンテナをデプロイし、ローカル `http://localhost:8000` でアクセスできるようにする最小構成。Ingress / Prometheus / Grafana / Argo CD / Kustomize などは一切使用しません。

---

## 0. 前提

| 項目 | バージョン例 |
|------|--------------|
| OS   | Ubuntu 22.04 / Amazon Linux 2023 |
| kind | v0.23.0 |
| kubectl | v1.29.x |
| Helm | v3.14.x |
| Docker | 24.0+ |
| AWS CLI | v2 (ECR 認証用) |

> **作業ディレクトリ:** `~/dev/k8s-kind-helm-basic`
>
> **GitHub Repo:** <https://github.com/kurosawa-kuro/k8s-kind-helm-basic>
>
> **ECR イメージ:** `986154984217.dkr.ecr.ap-northeast-1.amazonaws.com/container-nodejs-api-8000:v1.0.4`
>
> **Node.js API Git:** <https://github.com/kurosawa-kuro/container-nodejs-api-8000>

```bash
mkdir -p ~/dev && cd ~/dev
git clone https://github.com/kurosawa-kuro/k8s-kind-helm-basic.git
cd k8s-kind-helm-basic
```

---

## 1. kind クラスタ作成

`kind-config.yaml`（NodePort: **30080 → localhost:8000** にマッピング）

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 30080
        hostPort: 8000
```

```bash
kind create cluster --name basic --config kind-config.yaml
kubectl cluster-info --context kind-basic
```

---

## 2. Helm チャート構成

```bash
# Helm チャートの作成
helm create nodejs-api
```

チャートの構成：
```
nodejs-api/
├─ Chart.yaml
├─ values.yaml
└─ templates/
     ├─ deployment.yaml
     ├─ service.yaml
     ├─ ingress.yaml
     ├─ hpa.yaml
     ├─ serviceaccount.yaml
     └─ NOTES.txt
```

### 2‑1. Chart.yaml
```yaml
apiVersion: v2
name: nodejs-api
version: 0.1.0
appVersion: "1.0.4"
```

### 2‑2. values.yaml
```yaml
# Default values for nodejs-api.
# This is a YAML-formatted file.
# Declare variables to be passed into your templates.

# This will set the replicaset count more information can be found here: https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/
replicaCount: 1

# This sets the container image more information can be found here: https://kubernetes.io/docs/concepts/containers/images/
image:
  repository: 986154984217.dkr.ecr.ap-northeast-1.amazonaws.com/container-nodejs-api-8000
  # This sets the pull policy for images.
  pullPolicy: IfNotPresent
  # Overrides the image tag whose default is the chart appVersion.
  tag: v1.0.4

# This is for the secrets for pulling an image from a private repository more information can be found here: https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/
imagePullSecrets: []
# This is to override the chart name.
nameOverride: ""
fullnameOverride: ""

# This section builds out the service account more information can be found here: https://kubernetes.io/docs/concepts/security/service-accounts/
serviceAccount:
  # Specifies whether a service account should be created
  create: true
  # Automatically mount a ServiceAccount's API credentials?
  automount: true
  # Annotations to add to the service account
  annotations: {}
  # The name of the service account to use.
  # If not set and create is true, a name is generated using the fullname template
  name: ""

# This is for setting Kubernetes Annotations to a Pod.
# For more information checkout: https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/
podAnnotations: {}
# This is for setting Kubernetes Labels to a Pod.
# For more information checkout: https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/
podLabels: {}

podSecurityContext: {}
  # fsGroup: 2000

securityContext: {}
  # capabilities:
  #   drop:
  #   - ALL
  # readOnlyRootFilesystem: true
  # runAsNonRoot: true
  # runAsUser: 1000

# This is for setting up a service more information can be found here: https://kubernetes.io/docs/concepts/services-networking/service/
service:
  # This sets the service type more information can be found here: https://kubernetes.io/docs/concepts/services-networking/service/#publishing-services-service-types
  type: NodePort
  # This sets the ports more information can be found here: https://kubernetes.io/docs/concepts/services-networking/service/#field-spec-ports
  port: 8000
  nodePort: 30080

# This block is for setting up the ingress for more information can be found here: https://kubernetes.io/docs/concepts/services-networking/ingress/
ingress:
  enabled: false
  className: ""
  annotations: {}
    # kubernetes.io/ingress.class: nginx
    # kubernetes.io/tls-acme: "true"
  hosts:
    - host: chart-example.local
      paths:
        - path: /
          pathType: ImplementationSpecific
  tls: []
  #  - secretName: chart-example-tls
  #    hosts:
  #      - chart-example.local

resources: {}
  # We usually recommend not to specify default resources and to leave this as a conscious
  # choice for the user. This also increases chances charts run on environments with little
  # resources, such as Minikube. If you do want to specify resources, uncomment the following
  # lines, adjust them as necessary, and remove the curly braces after 'resources:'.
  # limits:
  #   cpu: 100m
  #   memory: 128Mi
  # requests:
  #   cpu: 100m
  #   memory: 128Mi

# This is to setup the liveness and readiness probes more information can be found here: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/
livenessProbe:
  httpGet:
    path: /
    port: http
readinessProbe:
  httpGet:
    path: /
    port: http

# This section is for setting up autoscaling more information can be found here: https://kubernetes.io/docs/concepts/workloads/autoscaling/
autoscaling:
  enabled: false
  minReplicas: 1
  maxReplicas: 100
  targetCPUUtilizationPercentage: 80
  # targetMemoryUtilizationPercentage: 80

# Additional volumes on the output Deployment definition.
volumes: []
# - name: foo
#   secret:
#     secretName: mysecret
#     optional: false

# Additional volumeMounts on the output Deployment definition.
volumeMounts: []
# - name: foo
#   mountPath: "/etc/foo"
#   readOnly: true

nodeSelector: {}

tolerations: []

affinity: {}
```

### 2‑3. deployment.yaml
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "nodejs-api.fullname" . }}
  labels: { app: nodejs-api }
spec:
  replicas: 1
  selector:
    matchLabels: { app: nodejs-api }
  template:
    metadata:
      labels: { app: nodejs-api }
    spec:
      containers:
        - name: api
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - containerPort: 8000
          env:
            - name: CURRENT_ENV
              value: "kind"
```


---

## 3. (オプション) ECR イメージを kind へ取り込み

```bash
aws ecr get-login-password --region ap-northeast-1 | \
  docker login --username AWS --password-stdin 986154984217.dkr.ecr.ap-northeast-1.amazonaws.com

docker pull 986154984217.dkr.ecr.ap-northeast-1.amazonaws.com/container-nodejs-api-8000:v1.0.4
kind load docker-image 986154984217.dkr.ecr.ap-northeast-1.amazonaws.com/container-nodejs-api-8000:v1.0.4 --name basic
```

*クラスタが外部レジストリから直接 pull できる場合はスキップ可。*

---

## 4. Helm デプロイ

```bash
# nodejs-apiディレクトリ内で実行する場合
helm install api . --namespace default

# または、プロジェクトルートディレクトリで実行する場合
helm install api nodejs-api --namespace default
```

---

## 5. 動作確認

```bash
kubectl get pods,svc

# ポートフォワードの設定（必須）
kubectl port-forward svc/api-nodejs-api 8000:8000 -n default &

# Web ブラウザ
open http://localhost:8000/        # ヘルスチェック
open http://localhost:8000/api-docs  # Swagger UI
```

> **注意:** アプリケーションにアクセスするには、必ずポートフォワードの設定が必要です。ポートフォワードが設定されていない場合、`localhost:8000` にアクセスできません。

---

## 6. クリーンアップ

```bash
# Helm リリースの削除
helm uninstall api

# クラスタの削除
kind delete cluster --name basic
```

---

### 完了 🎉

これで **kind + Helm** を使った最小限の Node.js API デプロイが完了しました。後から Ingress や監視を追加する場合は、このチャートにテンプレートや依存チャートを追記するだけで簡単に拡張できます。

