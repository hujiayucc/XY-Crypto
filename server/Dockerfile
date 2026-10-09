FROM node:20-alpine
WORKDIR /app
COPY package.json ./
COPY src ./src
COPY public ./public
COPY data ./data
ENV NODE_ENV=production
ENV HOST=0.0.0.0
ENV PORT=8787
EXPOSE 8787
USER node
CMD ["node", "src/server.mjs"]
