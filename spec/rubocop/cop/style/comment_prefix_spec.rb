# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Style::CommentPrefix, :config do
  shared_examples 'enforces prefix' do |prefix|
    context "with configured `#{prefix}` as the comment prefix" do
      it 'registers an offense when the prefix is longer' do
        expect_offense(<<~RUBY, prefix: prefix)
          #%{prefix}too many octothorpes
          ^^{prefix} Comment lines must begin with `%{prefix}`.
        RUBY
      end

      if prefix[/^#+/].length > 1
        it 'registers an offense when the prefix is shorter' do
          incorrect_prefix = prefix.sub(/^#/, '')

          expect_offense(<<~RUBY, prefix: prefix, incorrect_prefix)
            %{incorrect_prefix}too few octothorpes
            ^{incorrect_prefix} Comment lines must begin with `%{prefix}`.
          RUBY
        end
      end

      it 'does not register an offense when a comment starts with the correct prefix' do
        expect_no_offenses(<<~RUBY, prefix: prefix)
          %{prefix}correct number of octothorpes
        RUBY
      end

      it 'does not register an offense when a comment has subsequent `#` separate from the initial prefix' do
        expect_no_offenses(<<~RUBY, prefix: prefix)
          %{prefix}## subsequent octothorpes
        RUBY
      end

      it 'does not register an offense when a comment has extra spaces after the inital prefix' do
        expect_no_offenses(<<~RUBY, prefix: prefix)
          %{prefix} extra space
        RUBY
      end

      it 'does not register an offense on lines that start like comments, but are not comments' do
        expect_no_offenses(<<~RUBY, prefix: prefix)
          <<~HEREDOC
            # not a comment
            ## still not a comment
          HEREDOC
          '
            # not a comment
            ## still not a comment
          '
        RUBY
      end
    end
  end

  include_examples 'enforces prefix', '# ' # default
  include_examples 'enforces prefix', '#' # no space
  include_examples 'enforces prefix', '##' # two octothorpes
end

# TODO: What about comments like this?

#######
# box #
#######

#### Title ###
# titled box #
##############
