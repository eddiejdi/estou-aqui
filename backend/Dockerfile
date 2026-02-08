FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --production=false

COPY . .

EXPOSE 3000

CMD ["npm", "run", "dev"]
