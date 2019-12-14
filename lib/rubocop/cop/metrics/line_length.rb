# frozen_string_literal: true

require 'uri'

# rubocop:disable Metrics/ClassLength
module RuboCop
  module Cop
    module Metrics
      # This cop checks the length of lines in the source code.
      # The maximum length is configurable.
      # The tab size is configured in the `IndentationWidth`
      # of the `Layout/Tab` cop.
      # It also ignores a shebang line by default.
      #
      # This cop has some autocorrection capabilities.
      # It can programmatically shorten certain long lines by
      # inserting line breaks into expressions that can be safely
      # split across lines. These include arrays, hashes, and
      # method calls with argument lists.
      #
      # If autocorrection is enabled, the following Layout cops
      # are recommended to further format the broken lines.
      #
      #   - ParameterAlignment
      #   - ArgumentAlignment
      #   - ClosingParenthesisIndentation
      #   - FirstArgumentIndentation
      #   - FirstArrayElementIndentation
      #   - FirstHashElementIndentation
      #   - FirstParameterIndentation
      #   - HashAlignment
      #   - MultilineArrayLineBreaks
      #   - MultilineHashBraceLayout
      #   - MultilineHashKeyLineBreaks
      #   - MultilineMethodArgumentLineBreaks
      #
      # Together, these cops will pretty print hashes, arrays,
      # method calls, etc. For example, let's say the max columns
      # is 25:
      #
      # @example
      #
      #   # bad
      #   {foo: "0000000000", bar: "0000000000", baz: "0000000000"}
      #
      #   # good
      #   {foo: "0000000000",
      #   bar: "0000000000", baz: "0000000000"}
      #
      #   # good (with recommended cops enabled)
      #   {
      #     foo: "0000000000",
      #     bar: "0000000000",
      #     baz: "0000000000",
      #   }
      class LineLength < Cop
        include CheckLineBreakable
        include ConfigurableMax
        include IgnoredPattern
        include RangeHelp

        MSG = 'Line is too long. [%<length>d/%<max>d]'

        def on_potential_breakable_node(node)
          check_for_breakable_node(node)
        end
        alias on_array on_potential_breakable_node
        alias on_hash on_potential_breakable_node
        alias on_send on_potential_breakable_node

        def investigate(processed_source)
          check_for_breakable_semicolons(processed_source)
        end

        def investigate_post_walk(processed_source)
          processed_source.lines.each_with_index do |line, line_index|
            check_line(line, line_index)
          end
        end

        def autocorrect(range)
          return if range.nil?

          lambda do |corrector|
            corrector.insert_before(range, "\n")
          end
        end

        private

        def check_for_breakable_node(node)
          breakable_node = extract_breakable_node(node, max)
          return if breakable_node.nil?

          line_index = breakable_node.first_line - 1
          range = breakable_node.source_range

          existing = breakable_range_by_line_index[line_index]
          return if existing

          breakable_range_by_line_index[line_index] = range
        end

        def check_for_breakable_semicolons(processed_source)
          tokens = processed_source.tokens.select { |t| t.type == :tSEMI }
          tokens.reverse_each do |token|
            range = breakable_range_after_semicolon(token)
            breakable_range_by_line_index[range.line - 1] = range if range
          end
        end

        def breakable_range_after_semicolon(semicolon_token)
          range = semicolon_token.pos
          end_pos = range.end_pos
          next_range = range_between(end_pos, end_pos + 1)
          return nil unless next_range.line == range.line

          next_char = next_range.source
          return nil if /[\r\n]/ =~ next_char
          return nil if next_char == ';'

          next_range
        end

        def breakable_range_by_line_index
          @breakable_range_by_line_index ||= {}
        end

        def heredocs
          @heredocs ||= extract_heredocs(processed_source.ast)
        end

        def tab_indentation_width
          config.for_cop('Layout/Tab')['IndentationWidth']
        end

        def indentation_difference(line)
          return 0 unless tab_indentation_width

          line.match(/^\t*/)[0].size * (tab_indentation_width - 1)
        end

        def line_length(line)
          line.length + indentation_difference(line)
        end

        def highlight_start(line)
          max - indentation_difference(line)
        end

        def check_line(line, line_index)
          return if line_length(line) <= max
          return if ignored_line?(line, line_index)

          if ignore_cop_directives? && directive_on_source_line?(line_index)
            return check_directive_line(line, line_index)
          end
          return check_uri_line(line, line_index) if allow_uri?

          register_offense(
            excess_range(nil, line, line_index),
            line,
            line_index
          )
        end

        def ignored_line?(line, line_index)
          matches_ignored_pattern?(line) ||
            shebang?(line, line_index) ||
            heredocs && line_in_permitted_heredoc?(line_index.succ) ||
            allow_string_literals? && string_literal?(line, line_index)
        end

        def shebang?(line, line_index)
          line_index.zero? && line.start_with?('#!')
        end

        def string_literal?(line, line_index)
          # Not sure if there's a better way to identify tokens by line
          line_number = line_index + 1
          line_tokens = processed_source.tokens.select { |token| token.line == line_number }
          newline_column = line.length
          last_column = line.length - 1
          nesting = 0

          false && puts("\n#{line}\n#{line_tokens.reject{|t|t.type==:tNL}.map {|t| [t.text, t.type] }.to_h}\n") if line_tokens.any? { |t| %i(tSTRING_BEG tXSTRING_BEG tSYMBEG tREGEXP_BEG).include?(t.type) }

          line_tokens.all? do |token|
            next true if token.column == newline_column && token.type == :tNL
            next true if token.column == last_column && token.type == :tCOMMA

            case token.type
            when
              :tSTRING, # Simple string literals consist of only this token
              :tSTRING_BEG, :tSTRING_END,
              :tSTRING_CONTENT, # This is string content inside a string containing interpolation
              :tXSTRING_BEG, # This is the beginning of a shell command literal.
              :tREGEXP_BEG, :tREGEXP_OPT, # These delimit RegExp literals
              :tSYMBOL, # This is a simple symbol literal
              :tSYMBEG, # This is a symbol literal enclosed within quotes
              # These identify symbol literals, with and without interpolation, respectively. There is no special end token.
              :tINTEGER, :tFLOAT # This is a REALLY long number. Seriously, what are you doing?
              true
            when :tSTRING_DBEG # This starts interpolation
              if allow_interpolation?
                nesting += 1
                true
              else
                false
              end
            when :tSTRING_DEND # This ends interpolation
              nesting -= 1
              true
            else # Arbitrary tokens are allowed inside interpolation
              nesting > 0
            end
          end.tap { |legal| false && puts("\n", line, line_tokens, last_column, "\n") unless legal }
        end

        def register_offense(loc, line, line_index)
          message = format(MSG, length: line_length(line), max: max)

          breakable_range = breakable_range_by_line_index[line_index]
          add_offense(breakable_range, location: loc, message: message) do
            self.max = line_length(line)
          end
        end

        def excess_range(uri_range, line, line_index)
          excessive_position = if uri_range && uri_range.begin < max
                                 uri_range.end
                               else
                                 highlight_start(line)
                               end

          source_range(processed_source.buffer, line_index + 1,
                       excessive_position...(line_length(line)))
        end

        def max
          cop_config['Max']
        end

        def allow_string_literals?
          cop_config['AllowLiterals']
        end

        def allow_interpolation?
          literals_config = cop_config['AllowLiterals']

          literals_config == true ||
            (literals_config.respond_to?(:[]) && literals_config['AllowInterpolation'])
        end

        def allow_heredoc?
          allowed_heredoc
        end

        def allowed_heredoc
          cop_config['AllowHeredoc']
        end

        def extract_heredocs(ast)
          return [] unless ast

          ast.each_node(:str, :dstr, :xstr).select(&:heredoc?).map do |node|
            body = node.location.heredoc_body
            delimiter = node.location.heredoc_end.source.strip
            [body.first_line...body.last_line, delimiter]
          end
        end

        def line_in_permitted_heredoc?(line_number)
          return false unless allowed_heredoc

          heredocs.any? do |range, delimiter|
            range.cover?(line_number) &&
              (allowed_heredoc == true || allowed_heredoc.include?(delimiter))
          end
        end

        def allow_uri?
          cop_config['AllowURI']
        end

        def ignore_cop_directives?
          cop_config['IgnoreCopDirectives']
        end

        def allowed_uri_position?(line, uri_range)
          uri_range.begin < max &&
            (uri_range.end == line_length(line) ||
             uri_range.end == line_length(line) - 1)
        end

        def find_excessive_uri_range(line)
          last_uri_match = match_uris(line).last
          return nil unless last_uri_match

          begin_position, end_position =
            last_uri_match.offset(0).map do |pos|
              pos + indentation_difference(line)
            end
          return nil if begin_position < max && end_position < max

          begin_position...end_position
        end

        def match_uris(string)
          matches = []
          string.scan(uri_regexp) do
            matches << $LAST_MATCH_INFO if valid_uri?($LAST_MATCH_INFO[0])
          end
          matches
        end

        def valid_uri?(uri_ish_string)
          URI.parse(uri_ish_string)
          true
        rescue URI::InvalidURIError, NoMethodError
          false
        end

        def uri_regexp
          @uri_regexp ||=
            URI::DEFAULT_PARSER.make_regexp(cop_config['URISchemes'])
        end

        def check_directive_line(line, line_index)
          return if line_length_without_directive(line) <= max

          range = max..(line_length_without_directive(line) - 1)
          register_offense(
            source_range(
              processed_source.buffer,
              line_index + 1,
              range
            ),
            line,
            line_index
          )
        end

        def directive_on_source_line?(line_index)
          source_line_number = line_index + processed_source.buffer.first_line
          comment =
            processed_source
            .comments
            .detect { |e| e.location.line == source_line_number }

          return false unless comment

          comment.text.match(CommentConfig::COMMENT_DIRECTIVE_REGEXP)
        end

        def line_length_without_directive(line)
          before_comment, = line.split(CommentConfig::COMMENT_DIRECTIVE_REGEXP)
          before_comment.rstrip.length
        end

        def check_uri_line(line, line_index)
          uri_range = find_excessive_uri_range(line)
          return if uri_range && allowed_uri_position?(line, uri_range)

          register_offense(
            excess_range(uri_range, line, line_index),
            line,
            line_index
          )
        end
      end
    end
  end
end
# rubocop:enable Metrics/ClassLength
