# k8s-kind-helm-basic Makefile

# 変数定義
CLUSTER_NAME := basic
NAMESPACE := default
RELEASE_NAME := api
CHART_PATH := nodejs-api
PORT := 8000

# デフォルトターゲット
.PHONY: help
help:
	@echo "k8s-kind-helm-basic チュートリアル用 Makefile"
	@echo ""
	@echo "使用方法:"
	@echo "  make <ターゲット>"
	@echo ""
	@echo "ターゲット:"
	@echo "  setup           - 初期セットアップ（リポジトリのクローン）"
	@echo "  cluster-create  - kindクラスタの作成"
	@echo "  cluster-delete  - kindクラスタの削除"
	@echo "  cluster-info    - クラスタ情報の表示"
	@echo "  cluster-status  - クラスタの状態確認"
	@echo "  deploy          - Helmチャートのデプロイ"
	@echo "  undeploy        - Helmリリースの削除"
	@echo "  port-check      - ポート使用状況の確認"
	@echo "  port-kill       - ポートを使用しているプロセスの強制終了"
	@echo "  port-forward    - ポートフォワードの設定"
	@echo "  port-forward-stop - ポートフォワードの停止"
	@echo "  test            - アプリケーションの動作確認"
	@echo "  cleanup         - すべてのリソースのクリーンアップ"

# 初期セットアップ
.PHONY: setup
setup:
	mkdir -p ~/dev && cd ~/dev && \
	git clone https://github.com/kurosawa-kuro/k8s-kind-helm-basic.git && \
	cd k8s-kind-helm-basic

# クラスタ作成
.PHONY: cluster-create
cluster-create:
	kind create cluster --name $(CLUSTER_NAME) --config kind-config.yaml
	kubectl cluster-info --context kind-$(CLUSTER_NAME)

# クラスタ削除
.PHONY: cluster-delete
cluster-delete:
	kind delete cluster --name $(CLUSTER_NAME)

# クラスタ情報表示
.PHONY: cluster-info
cluster-info:
	kubectl cluster-info --context kind-$(CLUSTER_NAME)

# クラスタ状態確認
.PHONY: cluster-status
cluster-status:
	kind get clusters
	kubectl get nodes
	kubectl get all -n $(NAMESPACE)

# Helmチャートのデプロイ
.PHONY: deploy
deploy:
	helm install $(RELEASE_NAME) $(CHART_PATH) --namespace $(NAMESPACE)

# Helmリリースの削除
.PHONY: undeploy
undeploy:
	helm uninstall $(RELEASE_NAME) --namespace $(NAMESPACE)

# ポート使用状況の確認
.PHONY: port-check
port-check:
	@echo "ポート $(PORT) の使用状況を確認中..."
	@if command -v lsof >/dev/null 2>&1; then \
		sudo lsof -i :$(PORT); \
	elif command -v netstat >/dev/null 2>&1; then \
		sudo netstat -tulpn | grep $(PORT); \
	else \
		echo "lsof または netstat コマンドが見つかりません"; \
	fi

# ポートを使用しているプロセスの強制終了
.PHONY: port-kill
port-kill:
	@echo "ポート $(PORT) を使用しているプロセスを強制終了中..."
	@if command -v lsof >/dev/null 2>&1; then \
		PID=$$(sudo lsof -t -i:$(PORT)); \
		if [ -n "$$PID" ]; then \
			echo "PID $$PID を終了します"; \
			sudo kill -9 $$PID; \
		else \
			echo "ポート $(PORT) を使用しているプロセスはありません"; \
		fi \
	else \
		echo "lsof コマンドが見つかりません"; \
	fi

# ポートフォワードの設定
.PHONY: port-forward
port-forward:
	@echo "ポートフォワードを設定中..."
	kubectl port-forward svc/$(RELEASE_NAME)-nodejs-api $(PORT):$(PORT) -n $(NAMESPACE) &

# ポートフォワードの停止
.PHONY: port-forward-stop
port-forward-stop:
	@echo "ポートフォワードを停止中..."
	pkill -f "kubectl port-forward.*$(PORT)"

# アプリケーションの動作確認
.PHONY: test
test:
	@echo "アプリケーションの動作確認中..."
	curl -s http://localhost:$(PORT) || echo "接続できません"
	curl -s http://localhost:$(PORT)/healthz || echo "ヘルスチェックに失敗しました"
	curl -s http://localhost:$(PORT)/posts || echo "APIエンドポイントにアクセスできません"

# すべてのリソースのクリーンアップ
.PHONY: cleanup
cleanup:
	@echo "すべてのリソースをクリーンアップ中..."
	make port-forward-stop
	make undeploy
	make cluster-delete
