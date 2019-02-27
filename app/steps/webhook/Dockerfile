FROM ruby:2.5-alpine

COPY Gemfile* ./

RUN bundle install

COPY . .

ENTRYPOINT export && bundle exec rake
