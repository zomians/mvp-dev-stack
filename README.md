# MVP Development Stack

Rails 8 + Flutter による高速 MVP 開発環境

## 🎯 特徴

- **ゼロコンフィグ起動**: アプリケーション未作成でも自動生成
- **マルチステージビルド**: 開発/本番環境の最適化
- **ホットリロード**: Rails/Flutter 両方で開発効率最大化
- **API 連携済み**: Flutter→Rails API 接続設定済み
- **ワンライナー操作**: Makefile による仕組み化

## 📋 必要要件

- Docker Desktop 4.0+
- Docker Compose v2.0+
- Make
- Git

## 🚀 クイックスタート

```bash
# リポジトリをクローン
git clone <repository-url>
cd myapp

# 環境変数設定
cp .env.example .env

# 初回セットアップ＆起動（ホスト側で生成）
make quickstart
```

## 🔗 アクセス URL

| サービス    | URL                   | 説明              |
| ----------- | --------------------- | ----------------- |
| Rails       | http://localhost:3000 | バックエンド API  |
| Flutter     | http://localhost:8080 | フロントエンド UI |
| MailCatcher | http://localhost:1080 | メール確認 UI     |
| Redis       | localhost:6379        | キャッシュ/キュー |

## 📁 プロジェクト構成

```
myapp/
├── Makefile                    # オーケストレーション
├── compose.yaml               # 開発環境設定
├── compose.production.yaml    # 本番環境設定
├── .env.example              # 環境変数例
│
├── Dockerfile.rails          # Railsマルチステージビルド
├── Dockerfile.flutter        # Flutterマルチステージビルド
│
├── script/
│   ├── rails-entrypoint.sh  # Rails初期化スクリプト
│   └── flutter-entrypoint.sh # Flutter初期化スクリプト
│
├── nginx/
│   └── conf.d/
│       └── default.conf      # Nginx設定
│
├── railsapp/                 # Railsアプリケーション
└── flutterapp/              # Flutterアプリケーション
```

## 🛠 主要コマンド

### 基本操作

```bash
make help         # ヘルプ表示
make init         # プロジェクト初期化
make build        # イメージビルド
make up           # サービス起動
make down         # サービス停止
make restart      # サービス再起動
make status       # ステータス確認
make health       # ヘルスチェック
```

### 開発

```bash
make shell-rails   # Railsコンテナにシェル接続
make shell-flutter # Flutterコンテナにシェル接続
make console       # Rails consoleを起動
make migrate       # DBマイグレーション実行
make seed          # DBシード実行
```

### ログ

```bash
make logs          # 全ログ表示
make logs-tail     # ログをtail表示
make logs-rails    # Railsログのみ
make logs-flutter  # Flutterログのみ
```

### テスト

```bash
make test          # 全テスト実行
make test-rails    # Railsテストのみ
make test-flutter  # Flutterテストのみ
```

### デバッグ

```bash
make debug-rails   # Railsデバッグモード
make debug-flutter # Flutterデバッグモード
```

### バックアップ

```bash
make backup        # DBバックアップ作成
make restore       # 最新バックアップをリストア
```

### 本番環境

```bash
make prod-build    # 本番イメージビルド
make prod-up       # 本番環境起動
make prod-down     # 本番環境停止
make prod-deploy   # 本番デプロイ実行
make prod-logs     # 本番環境ログ
```

### クリーンアップ

```bash
make clean         # コンテナ/ボリューム削除
make clean-all     # プロジェクトファイルも削除
```

## 🔧 カスタマイズ

### 環境変数

`.env`ファイルで以下を設定可能：

- `RAILS_ENV`: Rails 環境（development/production）
- `SECRET_KEY_BASE`: Rails 秘密鍵
- `DATABASE_URL`: データベース接続 URL
- `API_BASE_URL`: Flutter→Rails API URL
- `FLUTTER_WEB_PORT`: Flutter 開発サーバーポート

### マルチステージビルド

各 Dockerfile には以下のステージがあります：

**Dockerfile.rails**

- `base`: 基本依存関係
- `dependencies`: 依存関係ビルダー
- `development`: 開発環境（デフォルト）
- `production`: 本番環境

**Dockerfile.flutter**

- `flutter-base`: Flutter SDK
- `dependencies`: 依存関係ビルダー
- `development`: 開発環境（デフォルト）
- `web-builder`: 本番ビルド
- `production`: Nginx サーバー

### API 連携

Flutter から Rails API への接続は自動設定されます：

- `lib/config/api_config.dart`: API 設定
- `lib/services/api_service.dart`: API サービス

## 📝 開発フロー

### 1. 新機能開発

```bash
# Railsでモデル作成
make shell-rails
rails generate model User name:string email:string
rails db:migrate
exit

# Flutterで画面作成
make shell-flutter
# lib/screens/user_list.dart を編集
exit

# 変更を確認
make logs-tail
```

### 2. データベース操作

```bash
# マイグレーション作成
make shell-rails
rails generate migration AddAgeToUsers age:integer
exit

# マイグレーション実行
make migrate

# シード実行
make seed
```

### 3. テスト実行

```bash
# 全テスト
make test

# 個別テスト
make test-rails
make test-flutter
```

## 🚢 本番デプロイ

### 1. 環境変数設定

```bash
# .env.productionを作成
cp .env.example .env.production
# 本番用の値を設定
```

### 2. ビルド＆デプロイ

```bash
# 本番イメージビルド
make prod-build

# デプロイ実行
make prod-deploy
```

### 3. SSL 設定（Let's Encrypt）

```bash
# Certbot実行
docker run --rm -v ./ssl:/etc/letsencrypt certbot/certbot certonly --webroot -w /var/www/certbot -d yourdomain.com
```

## 🐛 トラブルシューティング

### ポート競合

```bash
# 使用中のポート確認
lsof -i :3000
lsof -i :8080

# 別ポートで起動
RAILS_PORT=3001 FLUTTER_PORT=8081 make up
```

### ビルドエラー

```bash
# キャッシュクリア
make clean
make build-nocache
```

### データベースエラー

```bash
# DB再作成
make shell-rails
rails db:drop db:create db:migrate
exit
```

### Flutter 依存関係エラー

```bash
make shell-flutter
flutter clean
flutter pub get
exit
```

## 📚 参考資料

- [Rails Guides](https://guides.rubyonrails.org/)
- [Flutter Documentation](https://docs.flutter.dev/)
- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)

## 📄 ライセンス

MIT License

## 🤝 コントリビューション

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request
