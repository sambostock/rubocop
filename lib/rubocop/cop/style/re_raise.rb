# frozen_string_literal: true

require 'pry'

module RuboCop
  module Cop
    module Style
      class ReRaise < Cop
        include ConfigurableEnforcedStyle

        MSG = 'BAD_PLACEHOLDER' # FIXME

        def_node_matcher :raise_local_variable, <<-PATTERN
          (send nil? {:raise :fail} (lvar $_))
        PATTERN

        def_node_matcher :rescue_node, <<-PATTERN
          (rescue _
            (resbody _ {(lvasgn $_) $nil?}
              _
            )
            _
          )
        PATTERN

        def on_send(node)
          return unless %i[fail raise].include?(node.method_name)

          rescue_variable = rescue_variable_name(node)
          raise_variable = raise_local_variable(node)

          if implicit_style? && raise_variable
            if rescue_variable == raise_variable && rescue_variable_not_shadowed?(node)
              add_offense(node)
            end
          elsif explicit_style? && raise_variable.nil?
            add_offense(node)
          end
        end

        def autocorrect(node)
          lambda do |corrector|
            if implicit_style?
              remove_arguments(corrector, node)
            elsif explicit_style?
              rescue_variable = rescue_variable_name(node)

              if rescue_variable
                if node.parenthesized_call?
                  insert_only_argument(corrector, node, rescue_variable)
                else
                  add_only_argument(corrector, node, rescue_variable)
                end
              end
            end
          end
        end

        private

        def implicit_style?
          style == :implicit
        end

        def explicit_style?
          style == :explicit
        end

        def remove_arguments(corrector, node)
          corrector.remove(arguments_range(node))
        end

        def insert_only_argument(corrector, node, argument)
          corrector.insert_after(node.location.begin, argument)
        end

        def add_only_argument(corrector, node, argument)
          corrector.insert_after(node.location.expression, " #{argument}")
        end

        def arguments_range(node)
          node.location.expression.with(begin_pos: node.location.selector.end_pos)
        end

        def rescue_variable_not_shadowed?(node)
          parent = most_recent_rescue(node)
          identifier = rescue_variable_name(node)

          !shadow?(parent, identifier)
        end

        def_node_search :shadow?, <<-PATTERN
          (lvasgn % _)
        PATTERN

        def rescue_variable_name(node)
          rescue_root_node = most_recent_rescue(node)
          rescue_root_node && rescue_node(rescue_root_node).tap do |variable|
            yield variable if block_given?
          end
        end

        def most_recent_rescue(node)
          node.each_ancestor.find(&:rescue_type?)
        end
      end
    end
  end
end
