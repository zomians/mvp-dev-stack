#!/bin/bash
set -e

echo "🚀 Rails Entrypoint Starting..."

# カラー出力用
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ログ関数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Railsアプリケーションの存在確認
check_rails_app() {
    if [ ! -f "Gemfile" ] || [ ! -f "config/application.rb" ]; then
        return 1
    fi
    return 0
}

# 新規Railsアプリケーション生成
generate_rails_app() {
    log_info "Generating new Rails application..."
    
    # 一時的にカレントディレクトリの内容を退避
    if [ "$(ls -A)" ]; then
        log_warn "Directory not empty, backing up existing files..."
        mkdir -p /tmp/backup
        mv * /tmp/backup/ 2>/dev/null || true
        mv .* /tmp/backup/ 2>/dev/null || true
    fi
    
    # Rails new実行
    rails new . \
        --database=sqlite3 \
        --javascript=bun \
        --css=tailwind \
        --skip-git \
        --skip-test \
        --force
    
    log_info "Rails application generated successfully!"
}

# 依存関係のインストール
install_dependencies() {
    log_info "Installing dependencies..."
    
    # Bundler依存関係
    if [ -f "Gemfile" ]; then
        log_info "Installing Ruby gems..."
        bundle config set --local path '/usr/local/bundle'
        bundle config set --local without 'production'
        bundle install --jobs 4 --retry 3
    fi
    
    # JavaScript依存関係
    if [ -f "package.json" ]; then
        log_info "Installing JavaScript packages..."
        if command -v bun &> /dev/null; then
            bun install
        elif command -v npm &> /dev/null; then
            npm install
        fi
    fi
}

# データベースセットアップ
setup_database() {
    log_info "Setting up database..."
    
    # データベース作成
    bundle exec rails db:create 2>/dev/null || log_warn "Database already exists"
    
    # マイグレーション実行
    bundle exec rails db:migrate
    
    # シード実行（存在する場合）
    if [ -f "db/seeds.rb" ] && [ -s "db/seeds.rb" ]; then
        log_info "Running database seeds..."
        bundle exec rails db:seed
    fi
}

# 開発用の初期設定
setup_development() {
    log_info "Setting up development environment..."
    
    # credentials:editが必要な場合の対応
    if [ ! -f "config/master.key" ] && [ -f "config/credentials.yml.enc" ]; then
        log_warn "Generating new master key..."
        EDITOR="echo" bundle exec rails credentials:edit
    fi
    
    # Tailwind CSS のビルド監視設定
    if [ -f "tailwind.config.js" ]; then
        log_info "Setting up Tailwind CSS..."
        bundle exec rails tailwindcss:install 2>/dev/null || true
    fi
    
    # Action Cable設定（Redis使用）
    if [ -n "$REDIS_URL" ] || [ -n "$REDIS_HOST" ]; then
        log_info "Configuring Action Cable with Redis..."
        cat > config/cable.yml << EOF
development:
  adapter: redis
  url: redis://${REDIS_HOST:-redis}:${REDIS_PORT:-6379}/1
  channel_prefix: railsapp_development
EOF
    fi
    
    # メール設定（MailCatcher使用）
    if [ -n "$MAILCATCHER_HOST" ] || [ -f "/.dockerenv" ]; then
        log_info "Configuring MailCatcher..."
        cat >> config/environments/development.rb << 'EOF'

# MailCatcher configuration
Rails.application.configure do
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: ENV.fetch("MAILCATCHER_HOST", "mailcatcher"),
    port: 1025
  }
  config.action_mailer.raise_delivery_errors = false
end
EOF
    fi
}

# アセットのプリコンパイル（必要な場合）
compile_assets() {
    if [ "$RAILS_ENV" = "production" ] || [ "$PRECOMPILE_ASSETS" = "true" ]; then
        log_info "Precompiling assets..."
        bundle exec rails assets:precompile
    fi
}

# pidファイルのクリーンアップ
cleanup_pid() {
    if [ -f tmp/pids/server.pid ]; then
        log_warn "Removing stale server.pid..."
        rm -f tmp/pids/server.pid
    fi
}

# ヘルスチェック用エンドポイントの作成
create_health_endpoint() {
    if [ ! -f "config/routes.rb" ]; then
        return
    fi
    
    # /up エンドポイントが存在しない場合は作成
    if ! grep -q "get.*up.*Rails.application" config/routes.rb 2>/dev/null; then
        log_info "Creating health check endpoint..."
        
        # Rails 7.1以降のhealth_checkを使用
        sed -i '2i\  get "up" => "rails/health#show", as: :rails_health_check' config/routes.rb 2>/dev/null || \
        # 旧バージョン用フォールバック
        cat >> config/routes.rb << 'EOF'

Rails.application.routes.draw do
  get "up" => proc { [200, {}, ["OK"]] }
end
EOF
    fi
}

# メイン処理
main() {
    cd /app
    
    # Railsアプリケーションの確認と生成
    if ! check_rails_app; then
        log_warn "Rails application not found!"
        generate_rails_app
    fi
    
    # 環境セットアップ
    install_dependencies
    setup_database
    setup_development
    create_health_endpoint
    compile_assets
    cleanup_pid
    
    log_info "Rails entrypoint completed successfully!"
    log_info "Starting Rails server..."
    
    # コマンド実行
    exec "$@"
}

# トラップ設定（グレースフルシャットダウン）
trap 'log_warn "Received SIGTERM, shutting down..."; exit 0' SIGTERM
trap 'log_warn "Received SIGINT, shutting down..."; exit 0' SIGINT

# メイン処理実行
main "$@"