# frozen_string_literal: true

module RuboCop
  module Cop
    module Style
      # Attribute method access should be modified either implicitly with group access modifiers, or explicitly
      # overridden with inline access modifiers.
      #
      # @example EnforcedStyle: implicit (default)
      #   # Modify attribute method access by defining them within access modifier groups.
      #
      #   # bad
      #   attr_reader :foo
      #   private :foo
      #
      #   # bad
      #   attr_writer :foo
      #   private :foo=
      #
      #   # good
      #   private
      #
      #   attr_reader :foo
      #
      #   # good
      #   private
      #
      #   attr_writer :foo
      #
      # @example EnforcedStyle: explicit
      #   # Modify attribute method access by defining them in outside any access modifier group, and explicitly
      #   overridding their access
      #
      #   # bad
      #   private
      #
      #   attr_reader :foo
      #
      #   # bad
      #   private
      #
      #   attr_writer :foo
      #
      #   # good
      #   attr_reader :foo
      #   private :foo
      #
      #   # good
      #   attr_writer :foo
      #   private :foo=
      #
      class PrivateAttributes < Cop
        include ConfigurableEnforcedStyle

        DEFINE_IMPLICIT_ATTR_ACCESSOR_WRITER_MESSAGE = "Make `%{attribute_name}=` %{access_modifier} by defining " \
          "`%{attribute_method} :%{attribute_name}` in a `%{access_modifier}` section, or by extracting " \
          "`attr_writer :%{attribute_name}` defined in a `%{access_modifier}` section"
        DEFINE_IMPLICIT_ATTR_ACCESSOR_READER_MESSAGE = "Make `%{attribute_name}` %{access_modifier} by defining " \
          "`%{attribute_method} :%{attribute_name}` in a `%{access_modifier}` section, or by extracting " \
          "`attr_reader :%{attribute_name}` defined in a `%{access_modifier}` section"
        DEFINE_IMPLICIT_ATTR_WRITER_MESSAGE = "Make `%{attribute_name}=` %{access_modifier} by defining " \
          "`%{attribute_method} :%{attribute_name}` in a `%{access_modifier}` section"
        DEFINE_IMPLICIT_ATTR_READER_MESSAGE = "Make `%{attribute_name}` %{access_modifier} by defining " \
          "`%{attribute_method} :%{attribute_name}` in a `%{access_modifier}` section"

        DEFINE_EXPLICIT_ATTR_ACCESSOR_MESSAGE = "Make `%{attribute_name}` and `%{attribute_name}=` %{access_modifier}" \
          " by defining `attr_accessor :%{attribute_name}` outside the %{access_modifier} section, and explicitly " \
          "calling `%{access_modifier} :%{attribute_name}, :%{attribute_name}=`"
        DEFINE_EXPLICIT_ATTR_READER_MESSAGE = "Make `%{attribute_name}` %{access_modifier} by defining " \
          "`attr_reader :%{attribute_name}` outside the %{access_modifier} section, and explicitly calling " \
          "`%{access_modifier} :%{attribute_name}`"
        DEFINE_EXPLICIT_ATTR_WRITER_MESSAGE = "Make `%{attribute_name}=` %{access_modifier} by defining " \
          "`attr_writer :%{attribute_name}` outside the %{access_modifier} section, and explicitly calling " \
          "`%{access_modifier} :%{attribute_name}=`"

        def_node_matcher :access_modifier_with_arguments?, <<-PATTERN
          (send nil? ${:public :private :protected}
            $(sym _)+
          )
        PATTERN

        def_node_matcher :getter_definition?, <<-PATTERN
          (send nil? {:attr_accessor :attr_reader}
            <(sym %1) ...>
          )
        PATTERN

        def_node_matcher :setter_definition?, <<-PATTERN
          (send nil? {:attr_accessor :attr_writer}
            <(sym %1) ...>
          )
        PATTERN

        def_node_matcher :attribute_method?, <<-PATTERN
          (send nil? {:attr_accessor :attr_reader :attr_writer}
            $...
          )
        PATTERN

        def on_send(node)
          if implicit_style?
            check_implicit_style_respected(node)
          elsif explicit_style?
            check_explicit_style_respected(node)
          end
        end

        private

        def implicit_style?
          style == :implicit
        end

        def explicit_style?
          style == :explicit
        end

        def check_implicit_style_respected(node)
          access_modifier_with_arguments?(node) do |access_modifier, message_nodes|
            message_nodes.each do |message_node|
              break unless node.parent

              message_name = message_node.value
              break unless (definition = find_definition message_name, node.parent)

              attribute_name = message_name.to_s.chomp('=').to_sym

              message_template =
                if definition.method_name == :attr_accessor
                  if message_name.to_s.end_with? '='
                    DEFINE_IMPLICIT_ATTR_ACCESSOR_WRITER_MESSAGE
                  else
                    DEFINE_IMPLICIT_ATTR_ACCESSOR_READER_MESSAGE
                  end
                else
                  if message_name.to_s.end_with? '='
                    DEFINE_IMPLICIT_ATTR_WRITER_MESSAGE
                  else
                    DEFINE_IMPLICIT_ATTR_READER_MESSAGE
                  end
                end

              offense_message = format(
                message_template,
                attribute_name: attribute_name,
                access_modifier: access_modifier,
                attribute_method: definition.method_name,
              )

              add_offense(message_node, message: offense_message)
            end
          end
        end

        def check_explicit_style_respected(node)
          attribute_method?(node) do |attributes|
            access_modifier_node = node.parent.each_child_node
              .take_while { |sibling_node| sibling_node != node }
              .find(&:bare_access_modifier_declaration?)

            break unless access_modifier_node
            access_modifier = access_modifier_node.method_name

            attributes.each do |attribute|
              attribute_name = attribute.value

              message_template =
                case node.method_name
                when :attr_accessor
                  DEFINE_EXPLICIT_ATTR_ACCESSOR_MESSAGE
                when :attr_reader
                  DEFINE_EXPLICIT_ATTR_READER_MESSAGE
                when :attr_writer
                  DEFINE_EXPLICIT_ATTR_WRITER_MESSAGE
                end

              message_template && add_offense(
                attribute,
                message: format(message_template, attribute_name: attribute_name, access_modifier: access_modifier),
              )
            end
          end
        end

        def find_definition(message_name, parent_node)
          if message_name.to_s.end_with? '='
            attribute_name = normalize(message_name)
            parent_node.children.find { |node| setter_definition?(node, attribute_name) }
          else
            parent_node.children.find { |node| getter_definition?(node, message_name) }
          end
        end

        def normalize(message_name)
          message_name.to_s.chomp('=').to_sym
        end
      end
    end
  end
end
