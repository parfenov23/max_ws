# frozen_string_literal: true

require_relative "lib/max_ws/version"

Gem::Specification.new do |s|
  s.name        = "max_ws"
  s.version     = MaxWs::VERSION
  s.summary     = "WebSocket client for MAX messenger API"
  s.description = "ORM-like WebSocket client for MAX (max.ru) messenger platform. " \
                  "Provides chat management, messaging, contacts, reactions, and more."
  s.authors     = ["Maksim Pervushin"]
  s.license     = "MIT"
  s.homepage    = "https://github.com/maxpass/max_ws"

  s.required_ruby_version = ">= 3.1"

  s.files = Dir["lib/**/*.rb"]

  s.add_dependency "faye-websocket", "~> 0.11"
  s.add_dependency "eventmachine",   "~> 1.2"
end
