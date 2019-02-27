# frozen_string_literal: true

require 'pry'

module RuboCop
  module Cop
    module Style
      class ReRaise < Cop
        include ConfigurableEnforcedStyle

        PREFER_IMPLICIT_MSG = 'Prefer implicit `%<keyword>s`'
        PREFER_EXPLICIT_MSG = 'Prefer explicit `%<keyword>s` (with argument)'
        PREFER_EXPLICIT_MSG_WITH_IDENTIFIER = 'Prefer explicit `%<keyword>s %<identifier>s`'

        def on_send(node)
          return unless %i[fail raise].include?(node.method_name)

          if implicit_style? && explicitly_raising?(node) &&
              variables_match?(node) && variable_not_shadowed?(node)
            add_offense(node, message: format(PREFER_IMPLICIT_MSG, keyword: node.method_name))
          elsif explicit_style? && implicitly_raising?(node) &&
            variable_not_shadowed?(node)
            if (identifier = rescue_variable_name(node))
            add_offense(node, message: format(PREFER_EXPLICIT_MSG_WITH_IDENTIFIER, keyword: node.method_name, identifier: identifier))
            else
            add_offense(node, message: format(PREFER_EXPLICIT_MSG, keyword: node.method_name))
            end
          end
        end

        def autocorrect(node)
          lambda do |corrector|
            if implicit_style?
              remove_arguments(corrector, node)
            elsif explicit_style?
              identifier = rescue_variable_name(node)

              if identifier
                if node.parenthesized_call?
                  insert_only_argument(corrector, node, identifier)
                else
                  add_only_argument(corrector, node, identifier)
                end
              end
            end
          end
        end

        private

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

        def_node_search :shadow?, <<-PATTERN
          (lvasgn % _)
        PATTERN

        def implicit_style?
          style == :implicit
        end

        def explicit_style?
          style == :explicit
        end

        def variables_match?(node)
          rescue_variable_name(node) == raise_local_variable(node)
        end

        def implicitly_raising?(node)
          raise_local_variable(node).nil?
        end

        def explicitly_raising?(node)
          raise_local_variable(node)
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

        def variable_not_shadowed?(node)
          !variable_shadowed?(node)
        end

        def variable_shadowed?(node)
          parent = most_recent_rescue(node)
          identifier = rescue_variable_name(node)

          (parent.children & node.ancestors).any? { |n| shadow?(n, identifier) }
        end

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
