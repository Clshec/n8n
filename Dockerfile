# Stage 1: Build
FROM node:24-alpine AS builder

# Install build dependencies
RUN apk add --no-cache python3 make g++ git

# Set up pnpm and zx
RUN npm install -g pnpm@10.32.1 zx

WORKDIR /app

# Copy all files (filtered by .dockerignore)
COPY . .

# Install dependencies (frozen-lockfile ensures reproducibility)
RUN pnpm install --frozen-lockfile

# Build the project using turbo
RUN pnpm build

# Run the build script to create the 'compiled' production output
# This creates the ./compiled directory
RUN node scripts/build-n8n.mjs

# Stage 2: Runtime
FROM node:24-alpine

# Set environment variables for Coolify compatibility
ENV NODE_ENV=production
ENV N8N_RELEASE_TYPE=stable
ENV SHELL=/bin/sh

# Install OS dependencies required by n8n
RUN apk update && \
    apk upgrade --no-cache && \
    apk add --no-cache \
        git \
        openssh \
        openssl \
        graphicsmagick \
        tini \
        tzdata \
        ca-certificates \
        libc6-compat \
        bash

WORKDIR /home/node

# Copy compiled n8n from builder stage
COPY --from=builder /app/compiled /usr/local/lib/node_modules/n8n
COPY --from=builder /app/docker/images/n8n/docker-entrypoint.sh /

# Link the executable and set permissions
RUN ln -s /usr/local/lib/node_modules/n8n/bin/n8n /usr/local/bin/n8n && \
    mkdir -p /home/node/.n8n && \
    chown -R node:node /home/node && \
    chmod +x /docker-entrypoint.sh && \
    rm -rf /root/.npm /tmp/*

# n8n default port
EXPOSE 5678/tcp

USER node

ENTRYPOINT ["tini", "--", "/docker-entrypoint.sh"]
