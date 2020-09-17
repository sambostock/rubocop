# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Style::MutableConstant, :config do
  let(:prefix) { nil }

  shared_examples 'mutable objects' do |o|
    context 'when assigning with =' do
      it "registers an offense for #{o} assigned to a constant " \
         'and corrects by adding .freeze' do
        expect_offense([prefix, <<~RUBY].compact.join("\n"), o: o)
          CONST = %{o}
                  ^{o} Freeze mutable objects assigned to constants.
        RUBY
        expect_correction([prefix, <<~RUBY].compact.join("\n"))
          CONST = #{o}.freeze
        RUBY
      end
    end

    context 'when assigning with ||=' do
      it "registers an offense for #{o} assigned to a constant " \
         'and corrects by adding .freeze' do
        expect_offense([prefix, <<~RUBY].compact.join("\n"), o: o)
          CONST ||= %{o}
                    ^{o} Freeze mutable objects assigned to constants.
        RUBY
        expect_correction([prefix, <<~RUBY].compact.join("\n"))
          CONST ||= #{o}.freeze
        RUBY
      end
    end
  end

  shared_examples 'immutable objects' do |o|
    it "allows #{o} to be assigned to a constant" do
      source = [prefix, "CONST = #{o}"].compact.join("\n")
      expect_no_offenses(source)
    end

    it "allows #{o} to be ||= to a constant" do
      source = [prefix, "CONST ||= #{o}"].compact.join("\n")
      expect_no_offenses(source)
    end
  end

  context 'Strict: false' do
    let(:cop_config) { { 'EnforcedStyle' => 'literals' } }

    it_behaves_like 'mutable objects', '[1, 2, 3]'
    it_behaves_like 'mutable objects', '%w(a b c)'
    it_behaves_like 'mutable objects', '{ a: 1, b: 2 }'
    it_behaves_like 'mutable objects', "'str'"
    it_behaves_like 'mutable objects', '"top#{1 + 2}"'

    it_behaves_like 'immutable objects', '1'
    it_behaves_like 'immutable objects', '1.5'
    it_behaves_like 'immutable objects', ':sym'
    it_behaves_like 'immutable objects', 'FOO + BAR'
    it_behaves_like 'immutable objects', 'FOO - BAR'
    it_behaves_like 'immutable objects', "'foo' + 'bar'"
    it_behaves_like 'immutable objects', "ENV['foo']"
    it_behaves_like 'immutable objects', "::ENV['foo']"

    it 'allows method call assignments' do
      expect_no_offenses('TOP_TEST = Something.new')
    end

    context 'splat expansion' do
      context 'expansion of a range' do
        it 'registers an offense and corrects to use to_a.freeze' do
          expect_offense(<<~RUBY)
            FOO = *1..10
                  ^^^^^^ Freeze mutable objects assigned to constants.
          RUBY
          expect_correction(<<~RUBY)
            FOO = (1..10).to_a.freeze
          RUBY
        end

        context 'with parentheses' do
          it 'registers an offense and corrects to use to_a.freeze' do
            expect_offense(<<~RUBY)
              FOO = *(1..10)
                    ^^^^^^^^ Freeze mutable objects assigned to constants.
            RUBY
            expect_correction(<<~RUBY)
              FOO = (1..10).to_a.freeze
            RUBY
          end
        end
      end
    end

    context 'when assigning an array without brackets' do
      it 'adds brackets when auto-correcting' do
        expect_offense(<<~RUBY)
          XXX = YYY, ZZZ
                ^^^^^^^^ Freeze mutable objects assigned to constants.
        RUBY
        expect_correction(<<~RUBY)
          XXX = [YYY, ZZZ].freeze
        RUBY
      end

      it 'does not add brackets to %w() arrays' do
        expect_offense(<<~RUBY)
          XXX = %w(YYY ZZZ)
                ^^^^^^^^^^^ Freeze mutable objects assigned to constants.
        RUBY
        expect_correction(<<~RUBY)
          XXX = %w(YYY ZZZ).freeze
        RUBY
      end
    end

    context 'when assigning a range (irange) without parenthesis' do
      it 'adds parenthesis when auto-correcting' do
        expect_offense(<<~RUBY)
          XXX = 1..99
                ^^^^^ Freeze mutable objects assigned to constants.
        RUBY
        expect_correction(<<~RUBY)
          XXX = (1..99).freeze
        RUBY
      end

      it 'does not add parenthesis to range enclosed in parentheses' do
        expect_offense(<<~RUBY)
          XXX = (1..99)
                ^^^^^^^ Freeze mutable objects assigned to constants.
        RUBY
        expect_correction(<<~RUBY)
          XXX = (1..99).freeze
        RUBY
      end
    end

    context 'when assigning a range (erange) without parenthesis' do
      it 'adds parenthesis when auto-correcting' do
        expect_offense(<<~RUBY)
          XXX = 1...99
                ^^^^^^ Freeze mutable objects assigned to constants.
        RUBY
        expect_correction(<<~RUBY)
          XXX = (1...99).freeze
        RUBY
      end

      it 'does not add parenthesis to range enclosed in parentheses' do
        expect_offense(<<~RUBY)
          XXX = (1...99)
                ^^^^^^^^ Freeze mutable objects assigned to constants.
        RUBY
        expect_correction(<<~RUBY)
          XXX = (1...99).freeze
        RUBY
      end
    end

    context 'when the constant is a string literal' do
      # TODO : It is not yet decided when frozen string will be the default.
      # It has been abandoned in the Ruby 3.0 period, but may default in
      # the long run. So these tests are left with a provisional value of 4.0.
      if RuboCop::TargetRuby.supported_versions.include?(4.0)
        context 'when the target ruby version >= 4.0' do
          let(:ruby_version) { 4.0 }

          context 'when the frozen string literal comment is missing' do
            it_behaves_like 'mutable objects', '"#{interpolated}"'
            it_behaves_like 'immutable objects', '"static"'
          end

          context 'when the frozen string literal comment is true' do
            let(:prefix) { '# frozen_string_literal: true' }

            it_behaves_like 'mutable objects', '"#{interpolated}"'
            it_behaves_like 'immutable objects', '"static"'
          end

          context 'when the frozen string literal comment is false' do
            let(:prefix) { '# frozen_string_literal: false' }

            it_behaves_like 'mutable objects', '"#{interpolated}"'
            it_behaves_like 'immutable objects', '"static"'
          end
        end
      end

      context 'when the frozen string literal comment is missing' do
        it_behaves_like 'mutable objects', '"#{interpolated}"'
        it_behaves_like 'mutable objects', '"static"'
      end

      context 'when the frozen string literal comment is true' do
        let(:prefix) { '# frozen_string_literal: true' }

        it_behaves_like 'mutable objects', '"#{interpolated}"'
        it_behaves_like 'immutable objects', '"static"'
      end

      context 'when the frozen string literal comment is false' do
        let(:prefix) { '# frozen_string_literal: false' }

        it_behaves_like 'mutable objects', '"#{interpolated}"'
        it_behaves_like 'mutable objects', '"static"'
      end
    end
  end

  context 'Strict: true' do
    let(:cop_config) { { 'EnforcedStyle' => 'strict' } }

    it_behaves_like 'mutable objects', '[1, 2, 3]'
    it_behaves_like 'mutable objects', '%w(a b c)'
    it_behaves_like 'mutable objects', '{ a: 1, b: 2 }'
    it_behaves_like 'mutable objects', "'str'"
    it_behaves_like 'mutable objects', '"top#{1 + 2}"'
    it_behaves_like 'mutable objects', 'Something.new'

    it_behaves_like 'immutable objects', '1'
    it_behaves_like 'immutable objects', '1.5'
    it_behaves_like 'immutable objects', ':sym'
    it_behaves_like 'immutable objects', "ENV['foo']"
    it_behaves_like 'immutable objects', "::ENV['foo']"
    it_behaves_like 'immutable objects', 'OTHER_CONST'
    it_behaves_like 'immutable objects', '::OTHER_CONST'
    it_behaves_like 'immutable objects', 'Namespace::OTHER_CONST'
    it_behaves_like 'immutable objects', '::Namespace::OTHER_CONST'
    it_behaves_like 'immutable objects', 'Struct.new'
    it_behaves_like 'immutable objects', '::Struct.new'
    it_behaves_like 'immutable objects', 'Struct.new(:a, :b)'
    it_behaves_like 'immutable objects', <<~RUBY
      Struct.new(:node) do
        def assignment?
          true
        end
      end
    RUBY

    it 'allows calls to freeze' do
      expect_no_offenses(<<~RUBY)
        CONST = [1].freeze
      RUBY
    end

    context 'splat expansion' do
      context 'expansion of a range' do
        it 'registers an offense and corrects to use to_a.freeze' do
          expect_offense(<<~RUBY)
            FOO = *1..10
                  ^^^^^^ Freeze mutable objects assigned to constants.
          RUBY
          expect_correction(<<~RUBY)
            FOO = (1..10).to_a.freeze
          RUBY
        end

        context 'with parentheses' do
          it 'registers an offense and corrects to use to_a.freeze' do
            expect_offense(<<~RUBY)
              FOO = *(1..10)
                    ^^^^^^^^ Freeze mutable objects assigned to constants.
            RUBY
            expect_correction(<<~RUBY)
              FOO = (1..10).to_a.freeze
            RUBY
          end
        end
      end
    end

    context 'when assigning with an operator' do
      shared_examples 'operator methods' do |o|
        it 'registers an offense and corrects with parens and freeze' do
          expect_offense(<<~RUBY, o: o)
            CONST = FOO %{o} BAR
                    ^^^^^{o}^^^^ Freeze mutable objects assigned to constants.
          RUBY
          expect_correction(<<~RUBY)
            CONST = (FOO #{o} BAR).freeze
          RUBY
        end
      end

      it_behaves_like 'operator methods', '+'
      it_behaves_like 'operator methods', '-'
      it_behaves_like 'operator methods', '*'
      it_behaves_like 'operator methods', '/'
      it_behaves_like 'operator methods', '%'
      it_behaves_like 'operator methods', '**'
    end

    context 'when assigning with multiple operator calls' do
      it 'registers an offense and corrects with parens and freeze' do
        expect_offense(<<~RUBY)
          FOO = [1].freeze
          BAR = [2].freeze
          BAZ = [3].freeze
          CONST = FOO + BAR + BAZ
                  ^^^^^^^^^^^^^^^ Freeze mutable objects assigned to constants.
        RUBY
        expect_correction(<<~RUBY)
          FOO = [1].freeze
          BAR = [2].freeze
          BAZ = [3].freeze
          CONST = (FOO + BAR + BAZ).freeze
        RUBY
      end
    end

    context 'methods and operators that produce frozen objects' do
      it 'accepts assigning to an environment variable with a fallback' do
        expect_no_offenses(<<~RUBY)
          CONST = ENV['foo'] || 'foo'
        RUBY
        expect_no_offenses(<<~RUBY)
          CONST = ::ENV['foo'] || 'foo'
        RUBY
      end

      it 'accepts operating on a constant and an interger' do
        expect_no_offenses(<<~RUBY)
          CONST = FOO + 2
        RUBY
      end

      it 'accepts operating on multiple integers' do
        expect_no_offenses(<<~RUBY)
          CONST = 1 + 2
        RUBY
      end

      it 'accepts operating on a constant and a float' do
        expect_no_offenses(<<~RUBY)
          CONST = FOO + 2.1
        RUBY
      end

      it 'accepts operating on multiple floats' do
        expect_no_offenses(<<~RUBY)
          CONST = 1.2 + 2.1
        RUBY
      end

      it 'accepts comparison operators' do
        expect_no_offenses(<<~RUBY)
          CONST = FOO == BAR
        RUBY
      end

      it 'accepts checking fixed size' do
        expect_no_offenses(<<~RUBY)
          CONST = 'foo'.count
          CONST = 'foo'.count('f')
          CONST = [1, 2, 3].count { |n| n > 2 }
          CONST = [1, 2, 3].count(2) { |n| n > 2 }
          CONST = 'foo'.length
          CONST = 'foo'.size
        RUBY
      end
    end

    context 'operators that produce unfrozen objects' do
      it 'registers an offense when operating on a constant and a string' do
        expect_offense(<<~RUBY)
          CONST = FOO + 'bar'
                  ^^^^^^^^^^^ Freeze mutable objects assigned to constants.
        RUBY
        expect_correction(<<~RUBY)
          CONST = (FOO + 'bar').freeze
        RUBY
      end

      it 'registers an offense when operating on multiple strings' do
        expect_offense(<<~RUBY)
          CONST = 'foo' + 'bar' + 'baz'
                  ^^^^^^^^^^^^^^^^^^^^^ Freeze mutable objects assigned to constants.
        RUBY
        expect_correction(<<~RUBY)
          CONST = ('foo' + 'bar' + 'baz').freeze
        RUBY
      end
    end

    context 'when assigning an array without brackets' do
      it 'adds brackets when auto-correcting' do
        expect_offense(<<~RUBY)
          XXX = YYY, ZZZ
                ^^^^^^^^ Freeze mutable objects assigned to constants.
        RUBY
        expect_correction(<<~RUBY)
          XXX = [YYY, ZZZ].freeze
        RUBY
      end

      it 'does not add brackets to %w() arrays' do
        expect_offense(<<~RUBY)
          XXX = %w(YYY ZZZ)
                ^^^^^^^^^^^ Freeze mutable objects assigned to constants.
        RUBY
        expect_correction(<<~RUBY)
          XXX = %w(YYY ZZZ).freeze
        RUBY
      end
    end

    it 'freezes a heredoc' do
      expect_offense(<<~RUBY)
        FOO = <<-HERE
              ^^^^^^^ Freeze mutable objects assigned to constants.
          SOMETHING
        HERE
      RUBY
      expect_correction(<<~RUBY)
        FOO = <<-HERE.freeze
          SOMETHING
        HERE
      RUBY
    end

    context 'when the frozen string literal comment is missing' do
      it_behaves_like 'mutable objects', '"#{interpolated}"'
      it_behaves_like 'mutable objects', '"static"'
    end

    context 'when the frozen string literal comment is true' do
      let(:prefix) { '# frozen_string_literal: true' }

      it_behaves_like 'mutable objects', '"#{interpolated}"'
      it_behaves_like 'immutable objects', '"static"'
    end

    context 'when the frozen string literal comment is false' do
      let(:prefix) { '# frozen_string_literal: false' }

      it_behaves_like 'mutable objects', '"#{interpolated}"'
      it_behaves_like 'mutable objects', '"static"'
    end
  end
end
