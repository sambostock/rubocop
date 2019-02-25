# frozen_string_literal: true

RSpec.shared_examples 'enforces inline access modifier usage' do |options|
  access_modifier = options.fetch(:access_modifier)
  construct = options.fetch(:construct)

  context "in a #{construct}" do
    it "offends when #{access_modifier} is not inlined" do
      expect_offense(<<-RUBY.strip_indent)
        #{construct} Test
          #{access_modifier}
          #{'^' * access_modifier.length} `#{access_modifier}` should be inlined in method definitions.
        end
      RUBY
    end

    it "offends when #{access_modifier} is not inlined and has a comment" do
      expect_offense(<<-RUBY.strip_indent)
        #{construct} Test
          #{access_modifier} # hey
          #{'^' * access_modifier.length} `#{access_modifier}` should be inlined in method definitions.
        end
      RUBY
    end

    it "does not offend when #{access_modifier} is inlined with a method" do
      expect_no_offenses(<<-RUBY.strip_indent)
        #{construct} Test
          #{access_modifier} def foo; end
        end
      RUBY
    end

    it "does not offend when #{access_modifier} is inlined with a symbol" do
      expect_no_offenses(<<-RUBY.strip_indent)
        #{construct} Test
          #{access_modifier} :foo

          def foo; end
        end
      RUBY
    end
  end
end
