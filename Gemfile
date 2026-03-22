# frozen_string_literal: true

source 'https://gem.coop'

# Specify your gem's dependencies in low_type.gemspec
gemspec

group :development do
  gem 'expressions', path: '../expressions' if File.exist?('../expressions')
  gem 'low_dependency', path: '../low_dependency' if File.exist?('../low_dependency')
  # gem 'lowkey', path: '../lowkey' if File.exist?('../lowkey')

  gem 'benchmark-ips'
  gem 'pry'
  gem 'pry-nav'
  gem 'rack'
  gem 'rack-test'
  gem 'rake', '~> 13.0'
  gem 'rspec', '~> 3.0'
  gem 'rubocop', require: false
  gem 'sinatra'
end
