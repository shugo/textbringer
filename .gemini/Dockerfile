FROM ruby:3.4-slim

# Install build-essential for native extensions
RUN apt-get update -qq && apt-get install -y build-essential libncursesw5-dev libffi-dev libyaml-dev

# Install Node.js
RUN apt-get install -y nodejs npm

# Install gemini
RUN npm install -g @google/gemini-cli

# Set the working directory
WORKDIR /usr/src/app
RUN mkdir -p lib/textbringer

# Copy Gemfile and Gemfile.lock
COPY textbringer.gemspec Gemfile Gemfile.lock ./
COPY lib/textbringer/version.rb lib/textbringer/

# Install dependencies
RUN bundle install

CMD ["bash"]
