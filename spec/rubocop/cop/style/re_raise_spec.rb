# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Style::ReRaise, :config do
  subject(:cop) { described_class.new(config) }

  # FIXME: Ensure test names mention keyword
  %w[raise fail].each do |keyword|
    {
      'rescuing default' => '',
      'rescuing a specific error' => ' SomeError',
      'rescuing specific errors' => ' SomeError, SomeOtherError'
    }.each do |context_label, error_classes|
      context context_label do
        context 'when EnforcedStyle is implicit' do
          let(:cop_config) { { 'EnforcedStyle' => 'implicit' } }

          it 'registers an offense' do # FIXME: test name
            expect_offense(<<-RUBY.strip_indent)
              def foo
                whoops!
              rescue#{error_classes} => error
                report(error)
                #{keyword} error
                #{'^' * keyword.length}^^^^^^ BAD_PLACEHOLDER
              end
            RUBY

            expect_correction(<<-RUBY.strip_indent)
              def foo
                whoops!
              rescue#{error_classes} => error
                report(error)
              end
            RUBY
          end

          it 'registers an offense' do # FIXME: test name
            expect_offense(<<-RUBY.strip_indent)
              def foo
                whoops!
              rescue#{error_classes} => error
                report('something')
                #{keyword} error
                #{'^' * keyword.length}^^^^^^ BAD_PLACEHOLDER
              end
            RUBY

            expect_correction(<<-RUBY.strip_indent)
              def foo
                whoops!
              rescue#{error_classes}
                report('something')
                #{keyword}
              end
            RUBY
          end

          context 'nested rescue' do # FIXME: context name
            it 'does not register an offense' do # FIXME: test name
              expect_no_offenses(<<-RUBY.strip_indent)
                def foo
                  whoops!
                rescue#{error_classes} => error
                  begin
                    try_other_thing!
                  rescue
                    #{keyword} error
                  end
                end
              RUBY
            end
          end
        end

        context 'when EnforcedStyle is explicit' do
          let(:cop_config) { { 'EnforcedStyle' => 'explicit' } }

          it 'registers an offense' do # FIXME: test name
            expect_offense(<<-RUBY.strip_indent)
              def foo
                whoops!
              rescue#{error_classes} => error
                report(error)
                #{keyword}
                #{'^' * keyword.length} BAD_PLACEHOLDER
              end
            RUBY

            expect_correction(<<-RUBY.strip_indent)
              def foo
                whoops!
              rescue#{error_classes} => error
                report(error)
                #{keyword} error
              end
            RUBY
          end

          it 'registers an offense' do # FIXME: test name
            expect_offense(<<-RUBY.strip_indent)
              def foo
                whoops!
              rescue#{error_classes}
                report('something')
                #{keyword}
                #{'^' * keyword.length} BAD_PLACEHOLDER
              end
            RUBY

            # Can't correct, since we don't can't safely invent a variable name
            expect_no_corrections
          end

          context 'nested rescue' do # FIXME: context name
            it 'does not register an offense' do # FIXME: test name
              expect_no_offenses(<<-RUBY.strip_indent)
                def foo
                  whoops!
                rescue#{error_classes} => error
                  begin
                    try_other_thing!
                  rescue
                    #{keyword} error
                  end
                end
              RUBY
            end
          end
        end
      end
    end
  end
end

# FIXME: Add cases where the error is of a certain type
# rescue FooError, OtherError => error
