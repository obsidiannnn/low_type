# frozen_string_literal: true

# Benchmark: shim (current untyped path) vs class_eval rewrite (prototype)
#
# Run with: bundle exec ruby benchmarks/shim_vs_rewrite.rb
#
# This benchmark measures the per-call overhead of the two execution paths
# when config.type_checking is disabled:
#
#   Shim path (current):
#     Every call → prepended define_method → Lowkey proxy lookup → untyped_args → super
#
#   Rewrite path (prototype):
#     Every call → plain Ruby method defined via class_eval → no shim, no lookup

require 'benchmark/ips'
require_relative '../lib/low_type'

# ─── SHIM PATH ───────────────────────────────────────────────────────────────
# Force the original shim behavior by monkey-patching redefine to pass klass: nil.
# This isolates the shim path regardless of the prototype changes in low_type.rb.

module ShimForce
  def redefine(method_proxies:, class_proxy:, klass: nil)
    if LowType.config.type_checking
      send(:typed_methods, method_proxies:, class_proxy:)
    else
      send(:untyped_methods, method_proxies:, class_proxy:, klass: nil)
    end
  end
end

LowType.configure { |c| c.type_checking = false }

Low::Redefiner.singleton_class.prepend(ShimForce)

class ShimSubject
  include LowType

  def greet(name: String | 'world')
    "Hello, #{name}!"
  end

  def calculate(value: Integer | 0)
    value * 2
  end
end

Low::Redefiner.singleton_class.prepend(Module.new do
  def redefine(method_proxies:, class_proxy:, klass: nil)
    super(method_proxies:, class_proxy:, klass:)
  end
end)

# ─── REWRITE PATH ────────────────────────────────────────────────────────────
# Use the prototype rewrite path — klass is passed, class_eval rewrite applies.

class RewriteSubject
  include LowType

  def greet(name: String | 'world')
    "Hello, #{name}!"
  end

  def calculate(value: Integer | 0)
    value * 2
  end
end

# ─── BENCHMARK ───────────────────────────────────────────────────────────────

shim    = ShimSubject.new
rewrite = RewriteSubject.new

puts "\n=== LowType: Shim vs class_eval Rewrite ==="
puts "config.type_checking = false\n\n"

Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)

  x.report('shim — greet (current)') do
    shim.greet(name: 'Ruby')
  end

  x.report('rewrite — greet (prototype)') do
    rewrite.greet(name: 'Ruby')
  end

  x.compare!
end

puts "\n"

Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)

  x.report('shim — calculate (current)') do
    shim.calculate(value: 42)
  end

  x.report('rewrite — calculate (prototype)') do
    rewrite.calculate(value: 42)
  end

  x.compare!
end
