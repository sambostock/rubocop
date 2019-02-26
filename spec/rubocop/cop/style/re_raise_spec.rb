# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Style::ReRaise do
  subject(:cop) { described_class.new }

  it 'registers an offense' do
    expect_offense(<<-RUBY.strip_indent)
    def foo
    rescue => error
      puts error
      raise error
    end
    RUBY

    expect_correction(<<-RUBY.strip_indent)
    def foo
    rescue => error
      raise
    end
    RUBY
  end
end
