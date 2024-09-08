FROM node:23-bookworm-slim

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update
RUN apt-get install apt-utils -y
RUN apt-get install tree vim.tiny -y

RUN mkdir -p /opt/faucet
WORKDIR /opt/faucet
COPY . .
RUN yarn install

RUN echo "#!/bin/bash" >> start.sh
RUN echo "yarn run faucet" >> start.sh
RUN chmod +x start.sh

ENTRYPOINT ["./start.sh"]
