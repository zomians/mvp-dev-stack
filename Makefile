# MVP Development Lifecycle Automation
# Rails 8 + Flutter 3

include .env.development
export

# Colors for output
YELLOW := \033[1;33m
GREEN := \033[1;32m
RED := \033[1;31m
NC := \033[0m # No Color

# Docker Compose command
DC := docker compose -f compose.development.yaml --env-file .env.development

.PHONY: help
help: ## ヘルプ表示
	@echo "${GREEN}MVP Development Stack - Make Commands${NC}"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "${YELLOW}%-20s${NC} %s\n", $$1, $$2}'

.PHONY: setup
setup: build rails-new flutter-create up ## 初期セットアップ

.PHONY: build
build: ## Dockerイメージを全てビルド
	@echo "${GREEN}Building Docker images...${NC}"
	$(DC) build --parallel

.PHONY: build-nocache
build-nocache: ## キャッシュなしでビルド
	$(DC) build --no-cache --parallel

.PHONY: up
up: ## サービス起動
	$(DC) up -d
	@echo "${GREEN}Services started! Rails: http://localhost:${RAILS_PORT} Flutter: http://localhost:${FLUTTER_PORT}${NC}"
	@make logs-tail

.PHONY: down
down: ## サービス停止
	$(DC) down

.PHONY: restart
restart: down up ## サービス再起動
	@echo "${GREEN}Services restarted!${NC}"
	@make logs-tail

.PHONY: logs
logs: ## 全ログ表示
	$(DC) logs -f

.PHONY: logs-tail
logs-tail: ## ログをtail表示
	$(DC) logs -f --tail=50

.PHONY: test
test: ## テスト実行
	$(DC) exec railsservice bundle exec rails test
	$(DC) exec flutterservice flutter test

.PHONY: clean
clean: ## 全コンテナ/ボリューム削除
	$(DC) down --volumes --remove-orphans
	$(DC) system prune -f
	@echo "${GREEN}Cleaned up all containers and volumes!${NC}"

.PHONY: rails-new
rails-new: ## 新規Railsアプリ作成
	@rm -rf ${RAILS_APP_NAME}
	@echo "${GREEN}Creating new Rails application...${NC}"
	@[ -d ${RAILS_APP_NAME} ] || \
		$(DC) run --rm --no-deps railsservice bash -c " \
			gem install rails -v ${RAILS_VERSION} \
			&& rails new ${RAILS_APP_NAME} \
				--database=sqlite3 \
				--javascript=esbuild \
				--css=tailwind \
				--skip-git \
		"
	@echo "${GREEN}Rails app created successfully!${NC}"

.PHONY: rails-shell
rails-shell: ## Railsコンテナにシェル接続
	$(DC) run --rm railsservice bash

.PHONY: rails-migrate
rails-migrate: ## DBマイグレーション実行
	$(DC) exec railsservice bundle exec rails db:migrate

.PHONY: rails-routes
rails-routes: ## ルーティング一覧表示
	$(DC) exec railsservice bundle exec rails routes

.PHONY: bundle-install
bundle-install: ## Run bundle install with specific version
	$(DC) run --rm railsservice bash -c "bundle _${BUNDLER_VERSION}_ install"
	@echo "${GREEN}Bundle installed successfully!${NC}"

.PHONY: bundle-add
bundle-add: ## Gem追加（例: make bundle-add gem=devise）
ifndef gem
	$(error "Please specify a gem name, e.g., make bundle-add gem=devise")
endif
	$(DC) run --rm railsservice bundle add $(gem)
	@echo "${GREEN}Gem '$(gem)' added. Remember to run 'make rails-migrate' if needed.${NC}"

.PHONY: rails-generate
rails-generate: ## Generate Rails code (usage: make rails-generate TYPE="scaffold" NAME="Post title:string")
	@if [ -z "$(TYPE)" ] || [ -z "$(NAME)" ]; then \
		echo "${RED}Usage: make rails-generate TYPE=\"scaffold\" NAME=\"Post title:string\"${NC}"; \
		exit 1; \
	fi
	$(DC) run --rm railsservice bundle exec rails generate $(TYPE) $(NAME)

.PHONY: rails-test
rails-test: ## Railsテストのみ
	$(DC) exec railsservice bundle exec rails test

.PHONY: flutter-create
flutter-create: ## Create new Flutter application
	@echo "${GREEN}Creating new Flutter application...${NC}"
	@[ -d ${FLUTTER_APP_NAME} ] || \
		$(DC) run --rm --no-deps flutterservice flutter create --org com.mvp --project-name mvp_app .
# 		docker run --rm -v $${PWD}:/app -w /app ghcr.io/cirruslabs/flutter:3.32.5 flutter create flutterapp
	@echo "${GREEN}Flutter app created successfully!${NC}"

.PHONY: flutter-shell
flutter-shell: ## Flutterコンテナにシェル接続
	$(DC) exec flutterservice bash

.PHONY: flutter-clean
flutter-clean: ## Clean Flutter build
	$(DC) exec flutterservice flutter clean

.PHONY: flutter-pub-get
flutter-pub-get: ## Get Flutter dependencies
	$(DC) exec flutterservice flutter pub get

.PHONY: flutter-test
flutter-test: ## Flutterテストのみ
	$(DC) exec flutterservice flutter test
