# frozen_string_literal: true

module RuboCop
  module Cop
    module Style
      # Access modifiers should be declared to apply to a group of methods
      # or inline before each method, depending on configuration.
      #
      # @example EnforcedStyle: group (default)
      #
      #   # bad
      #
      #   class Foo
      #
      #     private def bar; end
      #     private def baz; end
      #
      #   end
      #
      #   # good
      #
      #   class Foo
      #
      #     private
      #
      #     def bar; end
      #     def baz; end
      #
      #   end
      # @example EnforcedStyle: inline
      #
      #   # bad
      #
      #   class Foo
      #
      #     private
      #
      #     def bar; end
      #     def baz; end
      #
      #   end
      #
      #   # good
      #
      #   class Foo
      #
      #     private def bar; end
      #     private def baz; end
      #
      #   end
      class AccessModifierDeclarations < Cop
        include ConfigurableEnforcedStyle

        GROUP_STYLE_MESSAGE = [
          '`%<access_modifier>s` should not be',
          'inlined in method definitions.'
        ].join(' ')

        INLINE_STYLE_MESSAGE = [
          '`%<access_modifier>s` should be',
          'inlined in method definitions.'
        ].join(' ')

        def on_send(node)
          return unless access_modifier?(node)

          if offense?(node)
            add_offense(node, location: :selector) do
              opposite_style_detected
            end
          else
            correct_style_detected
          end
        end

        private

        def offense?(node)
          group_offense?(node) ||
            inline_offense?(node) ||
            invalid_access_modifier_offense?(node)
        end

        def group_offense?(node)
          group_style? &&
            access_modifier_is_inlined?(node) &&
            access_modifier_can_be_grouped?(node)
        end

        def inline_offense?(node)
          inline_style? && access_modifier_is_not_inlined?(node)
        end

        def invalid_access_modifier_offense?(node)
          access_modifier_must_be_inlined?(node) &&
            access_modifier_is_not_inlined?(node)
        end

        def group_style?
          style == :group
        end

        def inline_style?
          style == :inline
        end

        def access_modifier_can_be_grouped?(node)
          !access_modifier_must_be_inlined?(node)
        end

        def access_modifier_must_be_inlined?(node)
          private_class_method_modifier?(node)
        end

        def access_modifier_is_inlined?(node)
          node.arguments.any?
        end

        def access_modifier_is_not_inlined?(node)
          !access_modifier_is_inlined?(node)
        end

        def message(node)
          access_modifier = node.loc.selector.source

          if group_style? && access_modifier_can_be_grouped?(node)
            format(GROUP_STYLE_MESSAGE, access_modifier: access_modifier)
          elsif inline_style? || access_modifier_must_be_inlined?(node)
            format(INLINE_STYLE_MESSAGE, access_modifier: access_modifier)
          end
        end

        def access_modifier?(node)
          node.access_modifier? || private_class_method_modifier?(node)
        end

        def private_class_method_modifier?(node)
          node.method_name == :private_class_method
        end
      end
    end
  end
end
