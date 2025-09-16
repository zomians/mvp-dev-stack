# syntax=docker/dockerfile:1
ARG RUBY_VERSION=3.4.5
ARG RAILS_VERSION=8.0.2.1
ARG NODE_VERSION=20
ARG APP_NAME=railsapp

# ========================================
# Base Image
# お試し: docker build -t mvpapp . && docker run --rm -it -v $(pwd):/opt -p 3000:3000 mvpapp bash
# ========================================
FROM ruby:${RUBY_VERSION}-slim AS base

# 基本パッケージインストール
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    git \
    libyaml-dev \
    && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Railsインストール
ARG RAILS_VERSION
RUN gem install rails -v ${RAILS_VERSION} --no-document

# Node.jsとBunインストール
ARG NODE_VERSION
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g bun@latest && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 作業ディレクトリ設定
ARG APP_NAME
WORKDIR /${APP_NAME}

# ========================================
# Dependencies Builder
# ========================================
FROM base AS build

# bundle install
ARG APP_NAME
COPY ${APP_NAME}/Gemfile* ./
RUN bundle install --jobs 4 --retry 3;

# bun install
COPY ${APP_NAME}/package*.json ${APP_NAME}/bun.lockb* ./
RUN if [ -f package.json ]; then \
      bun install --frozen-lockfile || bun install; \
    else \
      echo "package.json not found, skipping bun install"; \
    fi

# ========================================
# Development Stage
# ========================================
FROM build AS development

# 環境変数設定(composeで上書き可能)
ENV LANG=C.UTF-8 \
    TZ=Asia/Tokyo \
    NODE_ENV=development \
    RAILS_ENV=development \
    RACK_ENV=development \
    RAILS_SERVE_STATIC_FILES=true \
    RAILS_LOG_TO_STDOUT=true \
    WEB_CONCURRENCY=2 \
    MAX_THREADS=5

# 追加パッケージ
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    neovim \
    less \
    && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# アプリケーションコード(実際はcomposeでマウントされる)
ARG APP_NAME
COPY ${APP_NAME}/ ./

# エントリポイント設定
COPY script/rails-entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/rails-entrypoint.sh
ENTRYPOINT ["rails-entrypoint.sh"]

# デフォルトコマンド
CMD ["bin/rails", "server", "-b", "0.0.0.0"]