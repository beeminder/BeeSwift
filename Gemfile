# frozen_string_literal: true

source "https://rubygems.org"

git_source(:github) {|repo_name| "https://github.com/#{repo_name}" }

gem "fastlane"
gem "xcode-install"
gem "cocoapods"
gem "rest-client"

eval_gemfile('fastlane/Pluginfile') if File.exist?(plugins_path)
