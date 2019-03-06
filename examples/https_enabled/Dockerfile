# Base
FROM node:alpine AS base
ENV HOME=/home/node
WORKDIR $HOME/app
RUN chown -R node:node $HOME/*
USER node
COPY package*.json ./

# Dependencies
FROM base AS dependencies
RUN npm set progress=false && npm config set depth 0
RUN npm install --only=production
RUN cp -R node_modules prod_node_modules
RUN npm install

# Release
FROM dependencies as release

COPY --from=dependencies $HOME/app/prod_node_modules ./node_modules
COPY . .

EXPOSE 3000

CMD ["node", "."]
