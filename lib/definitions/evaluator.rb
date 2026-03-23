# frozen_string_literal: true

require 'expressions'
require 'lowkey'

require_relative '../expressions/expression_helpers'
require_relative '../expressions/type_expression'
require_relative '../syntax/syntax'
require_relative '../types/complex_types'
require_relative '../types/status'

module Low
  # Evaluate code stored in strings into constants and values.
  # ┌────────┐     ┌─────────┐     ┌─────────────┐     ┌─────────┐     ┌─────────┐
  # │ Lowkey │     │ Proxies │     │ Expressions │     │ LowType │     │ Methods │
  # └────┬───┘     └────┬────┘     └──────┬──────┘     └────┬────┘     └────┬────┘
  #      │              │                 │                 │               │
  #      │ Parses AST   │                 │                 │               │
  #      ├─────────────►│                 │                 │               │
  #      │              │                 │                 │               │
  #      │              │ Stores          │                 │               │
  #      │              ├────────────────►│                 │               │
  #      │              │                 │                 │               │
  #      │              │                 │ Evaluates <-- YOU ARE HERE.     |
  #      │              │                 │◄────────────────┤               │
  #      │              │                 │                 │               │
  #      │              │                 │                 │ Redefines     │
  #      │              │                 │                 ├──────────────►│
  #      │              │                 │                 │               │
  #      │              │                 │ Validates       │               │
  #      │              │                 │◄┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┤
  #      │              │                 │                 │               │
  class Evaluator
    include ExpressionHelpers
    include Types
    using LowType::Syntax

    def instance_evaluate(proxy:, klass: nil)
      eval(proxy.value, binding, proxy.file_path, proxy.start_line) # rubocop:disable Security/Eval
    rescue NameError => e
      # If eval fails with a NameError, try resolving the constant from the including class.
      # This fixes Issue #31 — user-defined constants like PaymentMethod are not in the
      # Evaluator's binding, but are accessible via klass.const_get.
      raise unless klass && e.name

      const_name = e.name
      begin
        const_value = klass.const_get(const_name)
      rescue NameError
        raise e
      end

      # Temporarily inject the constant into the Low namespace so eval can resolve it,
      # then remove it immediately to avoid polluting the namespace.
      Low.const_set(const_name, const_value)
      begin
        eval(proxy.value, binding, proxy.file_path, proxy.start_line) # rubocop:disable Security/Eval
      ensure
        Low.send(:remove_const, const_name) if Low.const_defined?(const_name, false)
      end
    end

    class << self
      def evaluate(method_proxies:, klass: nil)
        require_relative '../syntax/union_types' if LowType.config.union_type_expressions

        method_proxies.each_value do |method_proxy|
          evaluate_param_proxy_expressions(method_proxy:, klass:)
          evaluate_return_proxy_expression(return_proxy: method_proxy.return_proxy) if method_proxy.return_proxy
        end
      end

      def evaluate_param_proxy_expressions(method_proxy:, klass: nil)
        begin # rubocop:disable Style/RedundantBegin
          method_proxy.tagged_params(:value).each do |param_proxy|
            expression = new.instance_evaluate(proxy: param_proxy, klass:)
            param_proxy.expression = cast_type_expression(expression:, method_proxy:)
          end
        rescue NameError => e
          mp = method_proxy
          raise NameError, "Unknown type '#{e.name}' for #{mp.scope} at #{mp.file_path}:#{mp.start_line}"
        end
      end

      def evaluate_return_proxy_expression(return_proxy:)
        begin
          expression = new.instance_evaluate(proxy: return_proxy)
        rescue NameError
          rp = return_proxy
          raise NameError, "Unknown return type '#{rp.value}' for #{rp.scope} at #{rp.file_path}:#{rp.start_line}"
        end

        expression = TypeExpression.new(type: expression) unless expression.is_a?(TypeExpression)

        return_proxy.expression = expression
      end

      private

      def cast_type_expression(expression:, method_proxy:)
        if expression.is_a?(::Expressions::Expression)
          return expression
        elsif expression.instance_of?(Class) && expression.name == 'Low::Dependency'
          return expression.new(provider_key: method_proxy.name)
        elsif TypeQuery.type?(expression)
          return TypeExpression.new(type: expression)
        end

        nil
      end
    end
  end
end
