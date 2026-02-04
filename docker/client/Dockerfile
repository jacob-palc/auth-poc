FROM node:18.16.0
 
WORKDIR /app
ENV PATH /app/node_modules/.bin:$PATH
COPY package.json ./
 
# Force Node.js DNS to prioritize IPv4
ENV NODE_OPTIONS="--dns-result-order=ipv4first"
 
RUN yarn config set network-family ipv4
 
RUN yarn install --ignore-engines
 
RUN yarn add bootstrap@5.2.3
 
COPY . ./

COPY ./env.sh .
COPY .env .
# Make our shell script executable
RUN chmod +x env.sh

EXPOSE 3000:3000
ENTRYPOINT ["yarn","start","/app/env.sh"]