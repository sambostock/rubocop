# frozen_string_literal: true

module RuboCop
  module AST
    # A node extension for `resbody` nodes. This will be used in place of a
    # plain node when the builder constructs the AST, making its methods
    # available to all `resbody` nodes within RuboCop.
    class ResbodyNode < Node
      # Returns the body of the `rescue` clause.
      #
      # @return [Node, nil] The body of the `resbody`.
      def body
        node_parts[2]
      end

      # Returns the array of classes being rescued, or nil if none were
      # specified
      # FIXME: Verify and finish description
      def rescued_classes
        node_parts[0]
      end

      def local_variable_name
        node = assignment

        node && node.lvasgn_type? && node.asgn_rhs
      end

      # Returns the symbol for the variable the error is assigned to, if one
      # was specified.
      # FIXME: Verify and finish description
      def assignment
        node_parts[1]
      end
    end

    # node.children[2].children.first.children[1].node_parts
    # [nil, (lvasgn, :error), (send, nil?, :raise)]

    # def f
    #   rescue => x.y
    # end
    #
    # (def, :f,
    #   (args),
    #   (rescue, nil?,
    #     (resbody, nil?,
    #       (send,
    #         (send, nil?, :x), :y=), nil?), nil?))

    # def f
    #   rescue => y
    # end
    #
    # (def, :f,
    #   (args),
    #   (rescue, nil?,
    #     (resbody, nil?,
    #       (lvasgn, :y), nil?), nil?))

    # (resbody _ {(lvasgn $_) $nil?}
    #   _
    # )
  end
end
