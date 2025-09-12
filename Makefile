# MVP Development Lifecycle Automation
# Rails 8.0.2.1 + Flutter 3.32.5

.PHONY: help init build up down clean test deploy logs shell

# デフォルトターゲット
help: ## ヘルプを表示
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# 初期化
init: ## プロジェクト初期化（Rails/Flutter生成）
	@echo "🚀 Initializing MVP project..."
	@[ -d railsapp ] || docker run --rm -v $${PWD}:/app -w /app ruby:3.4.5 bash -c "gem install rails -v 8.0.2.1 && rails new railsapp --database=sqlite3 --javascript=bun --css=tailwind --skip-git"
	@[ -d flutterapp ] || docker run --rm -v $${PWD}:/app -w /app ghcr.io/cirruslabs/flutter:3.32.5 flutter create flutterapp
	@echo "✅ Project initialized"

# ビルド
build: ## Dockerイメージをビルド
	@docker compose build --parallel

build-nocache: ## キャッシュなしでビルド
	@docker compose build --no-cache --parallel

# 起動/停止
up: ## サービス起動
	@docker compose up -d && echo "✅ Services started" && make logs-tail

down: ## サービス停止
	@docker compose down

restart: down up ## サービス再起動

# ログ管理
logs: ## 全ログ表示
	@docker compose logs

logs-tail: ## ログをtail表示
	@docker compose logs -f --tail=50

logs-rails: ## Railsログのみ
	@docker compose logs -f rails

logs-flutter: ## Flutterログのみ
	@docker compose logs -f flutter

# 開発用コマンド
shell-rails: ## Railsコンテナにシェル接続
	@docker compose exec rails bash

shell-flutter: ## Flutterコンテナにシェル接続
	@docker compose exec flutter bash

console: ## Rails consoleを起動
	@docker compose exec rails bundle exec rails console

migrate: ## DBマイグレーション実行
	@docker compose exec rails bundle exec rails db:migrate

seed: ## DBシード実行
	@docker compose exec rails bundle exec rails db:seed

# テスト
test: ## テスト実行
	@docker compose exec rails bundle exec rails test
	@docker compose exec flutter flutter test

test-rails: ## Railsテストのみ
	@docker compose exec rails bundle exec rails test

test-flutter: ## Flutterテストのみ
	@docker compose exec flutter flutter test

# クリーンアップ
clean: ## 全コンテナ/ボリューム削除
	@docker compose down -v --remove-orphans
	@docker system prune -f

clean-all: clean ## プロジェクトファイルも削除
	@rm -rf railsapp flutterapp
	@echo "⚠️  All project files removed"

# デプロイ準備
assets: ## アセットプリコンパイル
	@docker compose exec rails bundle exec rails assets:precompile

flutter-build: ## Flutter本番ビルド
	@docker compose exec flutter flutter build web --release

deploy-prep: assets flutter-build ## デプロイ準備完了
	@echo "✅ Deploy preparation complete"

# ステータス確認
status: ## サービスステータス確認
	@docker compose ps

health: ## ヘルスチェック
	@echo "Rails: $$(curl -s -o /dev/null -w '%{http_code}' http://localhost:3000/up || echo 'DOWN')"
	@echo "Flutter: $$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8080 || echo 'DOWN')"

# ワンライナー初期起動
quickstart: init build up ## 初回セットアップ＆起動（アプローチ1）
	@echo "🎉 MVP is ready!"
	@echo "Rails: http://localhost:3000"
	@echo "Flutter: http://localhost:8080"

# デバッグ
debug-rails: ## Railsデバッグモード
	@docker compose exec rails bundle exec rails server -b 0.0.0.0 -p 3000 --debug

debug-flutter: ## Flutterデバッグモード
	@docker compose exec flutter flutter run -d web-server --web-hostname=0.0.0.0 --web-port=8080 --debug

# 環境別起動
up-staging: ## ステージング環境で起動
	@docker compose --env-file .env.staging up -d

up-production: ## 本番環境で起動
	@docker compose --env-file .env.production -f compose.yaml -f compose.production.yaml up -d

# 本番環境
prod-build: ## 本番イメージをビルド
	@docker compose -f compose.yaml -f compose.production.yaml build --parallel

prod-up: ## 本番環境を起動
	@docker compose -f compose.yaml -f compose.production.yaml up -d
	@echo "✅ Production services started"

prod-down: ## 本番環境を停止
	@docker compose -f compose.yaml -f compose.production.yaml down

prod-deploy: prod-build prod-up ## 本番デプロイ実行
	@echo "🚀 Production deployed successfully"

prod-logs: ## 本番環境のログ
	@docker compose -f compose.yaml -f compose.production.yaml logs -f --tail=100
	@mkdir -p backups
	@docker compose exec rails bash -c "sqlite3 db/development.sqlite3 '.backup /tmp/backup.db'" 
	@docker compose cp rails:/tmp/backup.db ./backups/backup_$$(date +%Y%m%d_%H%M%S).db
	@echo "✅ Backup created"

restore: ## 最新バックアップをリストア
	@latest=$$(ls -t backups/*.db | head -1); \
	[ -z "$$latest" ] && echo "❌ No backup found" && exit 1; \
	docker compose cp $$latest rails:/tmp/restore.db && \
	docker compose exec rails bash -c "sqlite3 db/development.sqlite3 '.restore /tmp/restore.db'" && \
	echo "✅ Restored from $$latest"