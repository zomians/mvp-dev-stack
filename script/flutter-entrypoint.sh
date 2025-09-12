#!/bin/bash
set -e

echo "🚀 Flutter Entrypoint Starting (Container-First Version)..."

# カラー出力用
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

log_debug() {
    if [ "$DEBUG" = "true" ]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

# Flutterアプリケーションの存在確認
check_flutter_app() {
    if [ ! -f "pubspec.yaml" ] || [ ! -d "lib" ]; then
        return 1
    fi
    return 0
}

# 新規Flutterアプリケーション生成（コンテナ内で実行）
generate_flutter_app() {
    log_info "No Flutter application found. Generating new application..."
    
    # 現在のディレクトリが空でない場合の対処
    if [ "$(ls -A 2>/dev/null | grep -v '^\.')" ]; then
        log_warn "Directory contains files. Creating Flutter app with force option..."
        # 一時的に既存ファイルを退避
        mkdir -p /tmp/backup
        find . -maxdepth 1 ! -name '.*' -exec mv {} /tmp/backup/ \; 2>/dev/null || true
    fi
    
    # Flutter create実行（現在のディレクトリに作成）
    flutter create . \
        --project-name=flutterapp \
        --org=com.mvp \
        --platforms=web \
        --template=app \
        --overwrite
    
    log_info "Flutter application generated successfully!"
    
    # 初期依存関係の取得
    flutter pub get
}

# 依存関係のインストール
install_dependencies() {
    log_info "Installing Flutter dependencies..."
    
    if [ -f "pubspec.yaml" ]; then
        flutter pub get
        
        # ビルドランナーが必要な場合
        if grep -q "build_runner" pubspec.yaml 2>/dev/null; then
            log_info "Running build_runner..."
            flutter pub run build_runner build --delete-conflicting-outputs || true
        fi
    fi
}

# API接続設定
setup_api_connection() {
    log_info "Setting up API connection..."
    
    # 環境変数からAPI URLを設定
    API_URL="${API_BASE_URL:-http://rails:3000}"
    
    # lib/config/api_config.dart の作成
    mkdir -p lib/config
    cat > lib/config/api_config.dart << EOF
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '$API_URL',
  );
  
  static const Map<String, String> headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  
  static const Duration timeout = Duration(seconds: 30);
}
EOF
    
    log_info "API configuration created at lib/config/api_config.dart"
}

# HTTPパッケージの追加
add_http_packages() {
    if ! grep -q "http:" pubspec.yaml 2>/dev/null; then
        log_info "Adding HTTP packages..."
        
        # pubspec.yamlにhttpパッケージを追加
        flutter pub add http
        flutter pub add dio
        flutter pub add provider
        flutter pub get
    fi
}

# 開発用のサンプルサービス作成
create_sample_service() {
    log_info "Creating sample API service..."
    
    mkdir -p lib/services
    cat > lib/services/api_service.dart << 'EOF'
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  Future<Map<String, dynamic>> getHealth() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/up'),
        headers: ApiConfig.headers,
      ).timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        return {'status': 'healthy', 'message': 'API is running'};
      } else {
        return {'status': 'unhealthy', 'message': 'API returned ${response.statusCode}'};
      }
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Future<dynamic> get(String endpoint) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
        headers: ApiConfig.headers,
      ).timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
        headers: ApiConfig.headers,
        body: json.encode(data),
      ).timeout(ApiConfig.timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to post data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}
EOF
    
    log_info "API service created at lib/services/api_service.dart"
}

# ホットリロード設定
setup_hot_reload() {
    log_info "Configuring hot reload..."
    
    # web/index.htmlの修正（必要な場合）
    if [ -f "web/index.html" ]; then
        # WebSocket接続の設定
        if ! grep -q "window.flutterWebRenderer" web/index.html 2>/dev/null; then
            sed -i '/<head>/a\  <script>window.flutterWebRenderer = "html";</script>' web/index.html 2>/dev/null || true
        fi
    fi
}

# Flutter Doctor実行
run_flutter_doctor() {
    log_info "Running Flutter doctor..."
    flutter doctor -v || log_warn "Flutter doctor reported some issues"
}

# Chrome/Chromiumの設定
setup_chrome() {
    if [ -n "$CHROME_EXECUTABLE" ]; then
        log_info "Setting Chrome executable: $CHROME_EXECUTABLE"
        export CHROME_EXECUTABLE
    fi
    
    # ヘッドレス環境の設定
    if [ "$HEADLESS" = "true" ]; then
        export DISPLAY=:99
        Xvfb :99 -screen 0 1024x768x24 > /dev/null 2>&1 &
        log_info "Started Xvfb for headless mode"
    fi
}

# 開発サーバーの起動準備
prepare_dev_server() {
    log_info "Preparing development server..."
    
    # ポート設定
    WEB_PORT="${FLUTTER_WEB_PORT:-8080}"
    WEB_HOSTNAME="${FLUTTER_WEB_HOSTNAME:-0.0.0.0}"
    
    log_info "Web server will run on http://${WEB_HOSTNAME}:${WEB_PORT}"
    
    # デバッグモードの設定
    if [ "$DEBUG" = "true" ]; then
        log_info "Debug mode enabled"
        export FLUTTER_DEBUG_MODE="true"
    fi
}

# ビルドキャッシュのクリーンアップ
cleanup_cache() {
    if [ "$CLEAN_BUILD" = "true" ]; then
        log_info "Cleaning build cache..."
        flutter clean
        flutter pub get
    fi
}

# 初回起動フラグファイル
INITIALIZED_FLAG="/app/.flutter_initialized"

# メイン処理
main() {
    cd /app
    
    # 初回起動時の処理
    if [ ! -f "$INITIALIZED_FLAG" ]; then
        log_info "First time setup detected..."
        
        # Flutterアプリケーションの確認と生成
        if ! check_flutter_app; then
            generate_flutter_app
        fi
        
        # 初回セットアップ完了フラグ
        touch "$INITIALIZED_FLAG"
        log_info "Initial setup completed!"
    else
        log_info "Flutter application already initialized."
    fi
    
    # 環境セットアップ（毎回実行）
    run_flutter_doctor
    install_dependencies
    add_http_packages
    setup_api_connection
    create_sample_service
    setup_hot_reload
    setup_chrome
    cleanup_cache
    prepare_dev_server
    
    log_info "Flutter entrypoint completed successfully!"
    log_info "Starting Flutter development server..."
    
    # コマンド実行
    exec "$@"
}

# シグナルハンドリング
handle_sigterm() {
    log_warn "Received SIGTERM, shutting down gracefully..."
    # Flutter processの終了
    pkill -TERM flutter || true
    exit 0
}

handle_sigint() {
    log_warn "Received SIGINT, shutting down gracefully..."
    pkill -TERM flutter || true
    exit 0
}

# トラップ設定
trap handle_sigterm SIGTERM
trap handle_sigint SIGINT

# メイン処理実行
main "$@"