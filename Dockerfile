FROM ruby:2.3

RUN bundle config --global frozen 1

RUN mkdir -p /app
RUN mkdir -p /pwd
WORKDIR /app

COPY Gemfile /app/
COPY Gemfile.lock /app/
COPY singularity-cli.gemspec /app/
RUN bundle install

COPY . /app

WORKDIR /pwd
VOLUME ["/pwd", "/ssh"]
ENTRYPOINT /app/bin/singularity
