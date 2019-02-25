# frozen_string_literal: true

RSpec.shared_examples 'enforces group access modifier usage' do |options|
  access_modifier = options.fetch(:access_modifier)
  construct = options.fetch(:construct)
  receiver = options.fetch(:receiver, nil)
  method_definition = receiver ? "def #{receiver}.foo; end" : 'def foo; end'

  context "in a #{construct}" do
    it "offends when #{access_modifier} is inlined with a method" do
      expect_offense(<<-RUBY.strip_indent)
        #{construct} Test
          #{access_modifier} #{method_definition}
          #{'^' * access_modifier.length} `#{access_modifier}` should not be inlined in method definitions.
        end
      RUBY
    end

    it "offends when #{access_modifier} is inlined with a symbol" do
      expect_offense(<<-RUBY.strip_indent)
        #{construct} Test
          #{access_modifier} :foo
          #{'^' * access_modifier.length} `#{access_modifier}` should not be inlined in method definitions.

          #{method_definition}
        end
      RUBY
    end

    it "does not offend when #{access_modifier} is not inlined" do
      expect_no_offenses(<<-RUBY.strip_indent)
        #{construct} Test
          #{access_modifier}
        end
      RUBY
    end

    it "does not offend when #{access_modifier} is not inlined and " \
       'has a comment' do
      expect_no_offenses(<<-RUBY.strip_indent)
        #{construct} Test
          #{access_modifier} # hey
        end
      RUBY
    end
  end
end
