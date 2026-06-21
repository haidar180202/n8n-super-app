FROM node:22-alpine

RUN apk add --no-cache ffmpeg tini
RUN npm install -g n8n@2.20.7

USER node
ENV N8N_USER_FOLDER=/home/node/.n8n
WORKDIR /home/node

ENTRYPOINT ["tini", "--"]
CMD ["n8n"]
