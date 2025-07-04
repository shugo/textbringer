FROM mcr.microsoft.com/devcontainers/ruby:3.4-bullseye

WORKDIR /workspace

RUN apt-get update -qq && apt-get install --no-install-recommends -y \
    build-essential libncursesw5-dev libffi-dev libyaml-dev

COPY ../textbringer.gemspec ../Gemfile ../Gemfile.lock ./
RUN mkdir -p lib/textbringer
COPY ../lib/textbringer/version.rb lib/textbringer/
RUN bundle install
