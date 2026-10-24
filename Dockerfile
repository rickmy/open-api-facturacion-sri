# =================================================
# Multi-stage Dockerfile for Open API Facturación SRI (NestJS)
# =================================================

# -----------------------------
# Stage 1: Build
# -----------------------------
FROM node:22.23.4-alpine AS builder

# Set working directory
WORKDIR /app

# git required for npm to resolve git-pinned node-forge
RUN apk add --no-cache git

# Copy package files first (for caching)
COPY package*.json ./

# Install ALL dependencies (including devDependencies for build)
RUN npm install --legacy-peer-deps

# Copy source code
COPY . .

# Build the application
RUN npm run build

# Remove devDependencies after build
RUN npm prune --production

# -----------------------------
# Stage 2: Production
# -----------------------------
FROM node:22.23.4-alpine AS production

# Set environment to production
ENV NODE_ENV=production
ENV TZ=America/Guayaquil

# Install tzdata for timezone support and dumb-init for proper signal handling
RUN apk add --no-cache tzdata dumb-init

# Create non-root user
RUN addgroup -g 1001 -S nodejs && adduser -S nestjs -u 1001 -G nodejs

# Set working directory
WORKDIR /app

# Copy package files
COPY --from=builder /app/package*.json ./

# Copy production dependencies from builder
COPY --from=builder /app/node_modules ./node_modules

# Copy built application
COPY --from=builder /app/dist ./dist

# Create directories for volumes
RUN mkdir -p /data/templates /data/pdfs /data/certs /data/xmls \
    /data/pdfs/con_firma /data/pdfs/others /data/pdfs/documents /data/pdfs/images \
    && chown -R nestjs:nodejs /app /data

# Expose the application port
EXPOSE 3001

# Run as non-root user
USER nestjs

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3001/status || exit 1

# Start the application with dumb-init as PID 1
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "dist/main"]
