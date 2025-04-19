# k8s-kind-helm-basic チュートリアル

> **目的:** kind クラスタ上に **Helm だけ** を使って Node.js API コンテナをデプロイし、ローカル `http://localhost:8000` でアクセスできるようにする最小構成。Ingress / Prometheus / Grafana / Argo CD / Kustomize などは一切使用しません。

---

## 0. 前提

| 項目 | バージョン例 |
|------|--------------|
| OS   | Ubuntu 22.04 / Amazon Linux 2023 |
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

```
charts/
└─ nodejs-api/
   ├─ Chart.yaml
   ├─ values.yaml
   └─ templates/
        ├─ deployment.yaml
        └─ service.yaml
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
image:
  repository: 986154984217.dkr.ecr.ap-northeast-1.amazonaws.com/container-nodejs-api-8000
  tag: v1.0.4
  pullPolicy: IfNotPresent
service:
  type: NodePort
  port: 8000
  nodePort: 30080
resources: {}
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

### 2‑4. service.yaml
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nodejs-api
  labels: { app: nodejs-api }
spec:
  type: {{ .Values.service.type }}
  selector: { app: nodejs-api }
  ports:
    - port: {{ .Values.service.port }}
      targetPort: 8000
      nodePort: {{ .Values.service.nodePort }}
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
helm install api charts/nodejs-api --namespace default
```

---

## 5. 動作確認

```bash
kubectl get pods,svc

# Web ブラウザ
open http://localhost:8000/        # ヘルスチェック
open http://localhost:8000/api-docs  # Swagger UI
```

---

## 6. クリーンアップ

```bash
helm uninstall api
kind delete cluster --name basic
```

---

### 完了 🎉

これで **kind + Helm** を使った最小限の Node.js API デプロイが完了しました。後から Ingress や監視を追加する場合は、このチャートにテンプレートや依存チャートを追記するだけで簡単に拡張できます。

