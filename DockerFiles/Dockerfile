# Dockerfile
FROM ruby:3.2

RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
    apt-get update -qq && \
    apt-get install -y nodejs postgresql-client yarn && \
    apt-get clean && rm -rf /var/lib/apt/lists/*


# Set working directory
WORKDIR /app

# Install bundler
COPY Gemfile Gemfile.lock ./
RUN gem install bundler && bundle install

# Copy the app
COPY . .
COPY entrypoint.sh /usr/bin/entrypoint.sh
ENV NODE_OPTIONS=--openssl-legacy-provider
RUN yarn install && \
    yarn add axios@1.4.0 && \
    yarn add -D webpack-cli@3.3.12 && \
    chmod +x /usr/bin/entrypoint.sh && \
    bundle exec rake assets:precompile

ENTRYPOINT ["entrypoint.sh"]

# Expose port
EXPOSE 3000

# Run the server
CMD ["rails", "server", "-b", "0.0.0.0"]
