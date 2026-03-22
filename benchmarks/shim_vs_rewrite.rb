# frozen_string_literal: true

# Benchmark: shim (current untyped path) vs class_eval rewrite (prototype)
# Run with: bundle exec ruby benchmarks/shim_vs_rewrite.rb

require 'benchmark/ips'

puts "\n=== LowType: Shim vs class_eval Rewrite ==="
puts "config.type_checking = false"
puts "ruby #{RUBY_VERSION} (#{RUBY_PLATFORM})\n\n"

# ─── SHIM PATH ───────────────────────────────────────────────────────────────
# Load with type_checking disabled BEFORE requiring low_type so the shim path
# is used for ShimSubject.

require_relative '../lib/low_type'

LowType.configure { |c| c.type_checking = false }

# Force shim by temporarily setting klass to nil in redefine
original_redefine = Low::Redefiner.method(:redefine)
Low::Redefiner.define_singleton_method(:redefine) do |method_proxies:, class_proxy:, klass: nil|
  original_redefine.call(method_proxies:, class_proxy:, klass: nil)
end

class ShimSubject
  include LowType

  def greet(name: String | 'world')
    "Hello, #{name}!"
  end

  def calculate(value: Integer | 0)
    value * 2
  end
end

# Restore original redefine for rewrite path
Low::Redefiner.define_singleton_method(:redefine) do |method_proxies:, class_proxy:, klass: nil|
  original_redefine.call(method_proxies:, class_proxy:, klass:)
end

# ─── REWRITE PATH ────────────────────────────────────────────────────────────

class RewriteSubject
  include LowType

  def greet(name: String | 'world')
    "Hello, #{name}!"
  end

  def calculate(value: Integer | 0)
    value * 2
  end
end

# ─── PLAIN RUBY BASELINE ─────────────────────────────────────────────────────

class PlainSubject
  def greet(name: 'world')
    "Hello, #{name}!"
  end

  def calculate(value: 0)
    value * 2
  end
end

shim    = ShimSubject.new
rewrite = RewriteSubject.new
plain   = PlainSubject.new

# ─── BENCHMARK: greet ────────────────────────────────────────────────────────

puts "--- greet(name: 'Ruby') ---\n\n"

Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)

  x.report('plain Ruby (baseline)')       { plain.greet(name: 'Ruby') }
  x.report('shim (current)')              { shim.greet(name: 'Ruby') }
  x.report('class_eval rewrite (prototype)') { rewrite.greet(name: 'Ruby') }

  x.compare!
end

puts "\n--- calculate(value: 42) ---\n\n"

Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)

  x.report('plain Ruby (baseline)')       { plain.calculate(value: 42) }
  x.report('shim (current)')              { shim.calculate(value: 42) }
  x.report('class_eval rewrite (prototype)') { rewrite.calculate(value: 42) }

  x.compare!
end
