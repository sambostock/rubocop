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

          rescue_root_node = ancestor_rescue_node(node)
          rescue_variable = rescue_root_node && rescue_node(rescue_root_node)
          raise_variable = raise_local_variable(node)

          if implicit_style? && raise_variable
            if rescue_variable == raise_variable # && rescue_variable_not_shadowed # FIXME
              # rescue => error
              #   raise error
              add_offense(node)
            end
          elsif explicit_style? && raise_variable.nil?
            # TODO: Should !rescue_variable.nil? be a special case?
            #   rescue => error
            #     raise

            add_offense(node)
          end
        end

        def autocorrect(node)
          lambda do |corrector|
            if implicit_style?
              range = node.location.expression.with(begin_pos: node.location.selector.end_pos)
              corrector.remove(range)
            elsif explicit_style?
              rescue_root_node = ancestor_rescue_node(node)
              rescue_variable = rescue_root_node && rescue_node(rescue_root_node)

              if rescue_variable
                if node.parenthesized_call?
                  corrector.insert_after(node.location.begin, rescue_variable)
                else
                  corrector.insert_after(node.location.expression, " #{rescue_variable}")
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

        def ancestor_rescue_node(node)
          node.each_ancestor.find(&:rescue_type?)
        end
      end
    end
  end
end
