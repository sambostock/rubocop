# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Style::PrivateAttributes, :config do
  ACCESS_MODIFIERS = %i(
    private
    protected
    public
  ).freeze

  ATTRIBUTE_METHODS = %i(
    attr_accessor
    attr_reader
    attr_writer
  ).freeze

  subject(:cop) { described_class.new(config) }

  context 'with implicit style' do
    let(:cop_config) do
      {
        'EnforcedStyle' => 'implicit',
      }
    end

    context 'default accessibility' do
      ATTRIBUTE_METHODS.each do |attribute_method|
        context attribute_method.to_s do
          it 'registers no offenses' do
            expect_no_offenses "#{attribute_method} :foo"
          end
        end
      end
    end

    ACCESS_MODIFIERS.each do |access_modifier|
      context access_modifier.to_s do
        let(:access_modifier_indent) { ' ' * access_modifier.to_s.length }

        it 'registers no offenses when attr_accessor access set implicitly' do
          expect_no_offenses <<~RUBY
            #{access_modifier}
            attr_accessor :foo
          RUBY
        end

        context 'getter' do
          it 'registers no offenses when access set explicitly but no definition found' do
            expect_no_offenses "#{access_modifier} :foo"
          end

          context 'defined using attr_accessor' do
            message_template = "Make `%{attribute_name}` #{access_modifier} by defining " \
              "`attr_accessor :%{attribute_name}` in a `#{access_modifier}` section, or by extracting " \
              "`attr_reader :%{attribute_name}` defined in a `#{access_modifier}` section"

            it 'registers an offense when access set explicitly' do
              expect_offense <<~RUBY
                attr_accessor :foo
                #{access_modifier} :foo
                #{access_modifier_indent} ^^^^ #{message_template % { attribute_name: :foo }}
              RUBY
            end

            it 'registers an offense when access set explicitly as part of list' do
              expect_offense <<~RUBY
                attr_accessor :foo
                #{access_modifier} :foo, :bar
                #{access_modifier_indent} ^^^^ #{message_template % { attribute_name: :foo }}
              RUBY
            end

            it 'registers an offense when access set explicitly as part of list' do
              # TODO: File bug about multiple offenses for same range not working
              expect_offense <<~RUBY
                attr_accessor :foo
                attr_accessor :bar
                #{access_modifier} :foo, :bar
                #{access_modifier_indent} ^^^^ #{message_template % { attribute_name: :foo }}
                #{access_modifier_indent}       ^^^^ #{message_template % { attribute_name: :bar }}
              RUBY
            end

            it 'registers an offense when access set explicitly as part of list' do
              expect_offense <<~RUBY
                attr_accessor :foo, :bar
                #{access_modifier} :foo, :bar
                #{access_modifier_indent} ^^^^ #{message_template % { attribute_name: :foo }}
                #{access_modifier_indent}       ^^^^ #{message_template % { attribute_name: :bar }}
              RUBY
            end

            it 'registers an offense when access set explicitly and attribute defined as subset of list' do
              expect_offense <<~RUBY
                attr_accessor :foo, :bar
                #{access_modifier} :foo
                #{access_modifier_indent} ^^^^ #{message_template % { attribute_name: :foo }}
              RUBY
            end
          end

          context 'defined using attr_reader' do
            message_template = "Make `%{attribute_name}` #{access_modifier} by defining " \
              "`attr_reader :%{attribute_name}` in a `#{access_modifier}` section"

            it 'registers an offense when access set explicitly' do
              expect_offense <<~RUBY
                attr_reader :foo
                #{access_modifier} :foo
                #{access_modifier_indent} ^^^^ #{message_template % { attribute_name: :foo }}
              RUBY
            end

            it 'registers an offense when access set explicitly as part of list' do
              expect_offense <<~RUBY
                attr_reader :foo
                #{access_modifier} :foo, :bar
                #{access_modifier_indent} ^^^^ #{message_template % { attribute_name: :foo }}
              RUBY
            end

            it 'registers an offense when access set explicitly as part of list' do
              expect_offense <<~RUBY
                attr_reader :foo
                attr_reader :bar
                #{access_modifier} :foo, :bar
                #{access_modifier_indent} ^^^^ #{message_template % { attribute_name: :foo }}
                #{access_modifier_indent}       ^^^^ #{message_template % { attribute_name: :bar }}
              RUBY
            end

            it 'registers an offense when access set explicitly as part of list' do
              expect_offense <<~RUBY
                attr_reader :foo, :bar
                #{access_modifier} :foo, :bar
                #{access_modifier_indent} ^^^^ #{message_template % { attribute_name: :foo }}
                #{access_modifier_indent}       ^^^^ #{message_template % { attribute_name: :bar }}
              RUBY
            end

            it 'registers an offense when access set explicitly and attribute defined as subset of list' do
              expect_offense <<~RUBY
                attr_reader :foo, :bar
                #{access_modifier} :foo
                #{access_modifier_indent} ^^^^ #{message_template % { attribute_name: :foo }}
              RUBY
            end

            it 'registers no offenses when access set implicitly' do
              expect_no_offenses <<~RUBY
                #{access_modifier}
                attr_reader :foo
              RUBY
            end
          end
        end

        context 'setter' do
          it 'registers no offenses when access set explicitly but no definition found' do
            expect_no_offenses "#{access_modifier} :foo="
          end

          context 'defined using attr_accessor' do
            message_template = "Make `%{attribute_name}=` #{access_modifier} by defining " \
              "`attr_accessor :%{attribute_name}` in a `#{access_modifier}` section, or by extracting " \
              "`attr_writer :%{attribute_name}` defined in a `#{access_modifier}` section"

            it 'registers an offense when access set explicitly' do
              expect_offense <<~RUBY
                attr_accessor :foo
                #{access_modifier} :foo=
                #{access_modifier_indent} ^^^^^ #{message_template % { attribute_name: :foo }}
              RUBY
            end

            it 'registers an offense when access set explicitly as part of list' do
              expect_offense <<~RUBY
                attr_accessor :foo
                #{access_modifier} :foo=, :bar=
                #{access_modifier_indent} ^^^^^ #{message_template % { attribute_name: :foo }}
              RUBY
            end

            it 'registers an offense when access set explicitly as part of list' do
              expect_offense <<~RUBY
                attr_accessor :foo
                attr_accessor :bar
                #{access_modifier} :foo=, :bar=
                #{access_modifier_indent} ^^^^^ #{message_template % { attribute_name: :foo }}
                #{access_modifier_indent}        ^^^^^ #{message_template % { attribute_name: :bar }}
              RUBY
            end

            it 'registers an offense when access set explicitly as part of list' do
              expect_offense <<~RUBY
                attr_accessor :foo, :bar
                #{access_modifier} :foo=, :bar=
                #{access_modifier_indent} ^^^^^ #{message_template % { attribute_name: :foo }}
                #{access_modifier_indent}        ^^^^^ #{message_template % { attribute_name: :bar }}
              RUBY
            end

            it 'registers an offense when access set explicitly and attribute defined as subset of list' do
              expect_offense <<~RUBY
                attr_accessor :foo, :bar
                #{access_modifier} :foo=
                #{access_modifier_indent} ^^^^^ #{message_template % { attribute_name: :foo }}
              RUBY
            end
          end

          context 'defined using attr_writer' do
            message_template = "Make `%{attribute_name}=` #{access_modifier} by defining " \
              "`attr_writer :%{attribute_name}` in a `#{access_modifier}` section"

            it 'registers an offense when access set explicitly' do
              expect_offense <<~RUBY
                attr_writer :foo
                #{access_modifier} :foo=
                #{access_modifier_indent} ^^^^^ #{message_template % { attribute_name: :foo }}
              RUBY
            end

            it 'registers an offense when access set explicitly as part of list' do
              expect_offense <<~RUBY
                attr_writer :foo
                #{access_modifier} :foo=, :bar=
                #{access_modifier_indent} ^^^^^ #{message_template % { attribute_name: :foo }}
              RUBY
            end

            it 'registers an offense when access set explicitly as part of list' do
              expect_offense <<~RUBY
                attr_writer :foo
                attr_writer :bar
                #{access_modifier} :foo=, :bar=
                #{access_modifier_indent} ^^^^^ #{message_template % { attribute_name: :foo }}
                #{access_modifier_indent}        ^^^^^ #{message_template % { attribute_name: :bar }}
              RUBY
            end

            it 'registers an offense when access set explicitly as part of list' do
              expect_offense <<~RUBY
                attr_writer :foo, :bar
                #{access_modifier} :foo=, :bar=
                #{access_modifier_indent} ^^^^^ #{message_template % { attribute_name: :foo }}
                #{access_modifier_indent}        ^^^^^ #{message_template % { attribute_name: :bar }}
              RUBY
            end

            it 'registers an offense when access set explicitly and attribute defined as subset of list' do
              expect_offense <<~RUBY
                attr_writer :foo, :bar
                #{access_modifier} :foo=
                #{access_modifier_indent} ^^^^^ #{message_template % { attribute_name: :foo }}
              RUBY
            end

            it 'registers no offenses when access set implicitly' do
              expect_no_offenses <<~RUBY
                #{access_modifier}
                attr_writer :foo
              RUBY
            end
          end
        end
      end
    end
  end

  context 'with explicit style' do
    let(:cop_config) do
      {
        'EnforcedStyle' => 'explicit',
      }
    end

    ACCESS_MODIFIERS.each do |access_modifier|
      context access_modifier.to_s do
        context 'attr_accessor' do
          message_template = "Make `%{attribute_name}` and `%{attribute_name}=` #{access_modifier} by defining " \
              "`attr_accessor :%{attribute_name}` outside the #{access_modifier} section, and explicitly calling " \
              "`#{access_modifier} :%{attribute_name}, :%{attribute_name}=`"

          it 'registers offense when defined implicitly' do
            expect_offense <<~RUBY
              #{access_modifier}
              attr_accessor :foo
                            ^^^^ #{message_template % { attribute_name: :foo }}
            RUBY
          end

          it 'registers offense when defined implicitly as part of list' do
            expect_offense <<~RUBY
              #{access_modifier}
              attr_accessor :foo, :bar
                            ^^^^ #{message_template % { attribute_name: :foo }}
                                  ^^^^ #{message_template % { attribute_name: :bar }}
            RUBY
          end

          it 'registers offense when defined implicitly separately' do
            expect_offense <<~RUBY
              #{access_modifier}
              attr_accessor :foo
                            ^^^^ #{message_template % { attribute_name: :foo }}
              attr_accessor :bar
                            ^^^^ #{message_template % { attribute_name: :bar }}
            RUBY
          end

          it 'registers offense when explicit attributes around' do
            expect_offense <<~RUBY
              attr_accessor :bar
              #{access_modifier} :bar

              #{access_modifier}
              attr_accessor :foo
                            ^^^^ #{message_template % { attribute_name: :foo }}
            RUBY
          end

          it 'registers offense when explicitly overridden, but implicit definition not in default section' do
            expect_offense <<~RUBY
              #{access_modifier}
              attr_accessor :foo
                            ^^^^ #{message_template % { attribute_name: :foo }}
              #{access_modifier} :foo
            RUBY
          end
        end

        context 'attr_reader' do
          message_template = "Make `%{attribute_name}` #{access_modifier} by defining " \
            "`attr_reader :%{attribute_name}` outside the #{access_modifier} section, and explicitly calling " \
            "`#{access_modifier} :%{attribute_name}`"

          it 'registers offense when defined implicitly' do
            expect_offense <<~RUBY
              #{access_modifier}
              attr_reader :foo
                          ^^^^ #{message_template % { attribute_name: :foo }}
            RUBY
          end

          it 'registers offense when defined implicitly as part of list' do
            expect_offense <<~RUBY
              #{access_modifier}
              attr_reader :foo, :bar
                          ^^^^ #{message_template % { attribute_name: :foo }}
                                ^^^^ #{message_template % { attribute_name: :bar }}
            RUBY
          end

          it 'registers offense when defined implicitly separately' do
            expect_offense <<~RUBY
              #{access_modifier}
              attr_reader :foo
                          ^^^^ #{message_template % { attribute_name: :foo }}
              attr_reader :bar
                          ^^^^ #{message_template % { attribute_name: :bar }}
            RUBY
          end

          it 'registers offense when explicit attributes around' do
            expect_offense <<~RUBY
              attr_reader :bar
              #{access_modifier} :bar

              #{access_modifier}
              attr_reader :foo
                          ^^^^ #{message_template % { attribute_name: :foo }}
            RUBY
          end

          it 'registers offense when explicitly overridden, but implicit definition not in default section' do
            expect_offense <<~RUBY
              #{access_modifier}
              attr_reader :foo
                          ^^^^ #{message_template % { attribute_name: :foo }}
              #{access_modifier} :foo
            RUBY
          end
        end

        context 'attr_writer' do
          message_template = "Make `%{attribute_name}=` #{access_modifier} by defining " \
            "`attr_writer :%{attribute_name}` outside the #{access_modifier} section, and explicitly calling " \
            "`#{access_modifier} :%{attribute_name}=`"

          it 'registers offense when defined implicitly' do
            expect_offense <<~RUBY
              #{access_modifier}
              attr_writer :foo
                          ^^^^ #{message_template % { attribute_name: :foo }}
            RUBY
          end

          it 'registers offense when defined implicitly as part of list' do
            expect_offense <<~RUBY
              #{access_modifier}
              attr_writer :foo, :bar
                          ^^^^ #{message_template % { attribute_name: :foo }}
                                ^^^^ #{message_template % { attribute_name: :bar }}
            RUBY
          end

          it 'registers offense when defined implicitly separately' do
            expect_offense <<~RUBY
              #{access_modifier}
              attr_writer :foo
                          ^^^^ #{message_template % { attribute_name: :foo }}
              attr_writer :bar
                          ^^^^ #{message_template % { attribute_name: :bar }}
            RUBY
          end

          it 'registers offense when explicit attributes around' do
            expect_offense <<~RUBY
              attr_writer :bar
              #{access_modifier} :bar

              #{access_modifier}
              attr_writer :foo
                          ^^^^ #{message_template % { attribute_name: :foo }}
            RUBY
          end

          it 'registers offense when explicitly overridden, but implicit definition not in default section' do
            expect_offense <<~RUBY
              #{access_modifier}
              attr_writer :foo
                          ^^^^ #{message_template % { attribute_name: :foo }}
              #{access_modifier} :foo
            RUBY
          end
        end
      end
    end
  end
end
