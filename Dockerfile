FROM ruby:2.3-alpine

RUN bundle config --global frozen 1

RUN mkdir -p /app
RUN mkdir -p /pwd
WORKDIR /app

RUN apk add --update alpine-sdk

COPY Gemfile /app/
COPY Gemfile.lock /app/
COPY singularity-cli.gemspec /app/
RUN bundle install

COPY . /app

WORKDIR /pwd
VOLUME ["/pwd", "/ssh"]
CMD ["help"]
ENTRYPOINT ["/app/bin/singularity"]
