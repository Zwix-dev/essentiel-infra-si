# Dépendances de production uniquement
FROM node:24-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# Étape de test : le build échoue si un test échoue
FROM deps AS test
RUN npm ci
COPY src ./src
COPY test ./test
RUN npm test

# Image livrée (cible par défaut, n'inclut pas les tests)
FROM node:24-alpine AS runtime
ENV NODE_ENV=production
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY package.json ./
COPY src ./src
USER node
EXPOSE 3000
CMD ["node", "src/server.js"]
