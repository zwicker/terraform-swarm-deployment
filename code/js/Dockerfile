FROM node:4-onbuild

COPY . /node
RUN cd /node && npm install
CMD node hello.js
EXPOSE 3000
