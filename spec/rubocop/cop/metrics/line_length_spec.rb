# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Metrics::LineLength, :config do
  subject(:cop) { described_class.new(config) }

  let(:cop_config) { { 'Max' => 80, 'IgnoredPatterns' => nil } }

  context 'ignore literals (string, numbers, etc)!!!' do
    let(:cop_config) do
      { 'Max' => 8, 'AllowLiterals' => true, }
    end

    it "accepts lines consisting only of literals" do
      expect_no_offenses(<<~RUBY)
        '2345678'
        "2345678"

        %(345678)
        %q(45678)
        %Q(45678)

        %x(clear)

        /2345678/
        %r(45678)

        :__456789
        :"_45678"

        123456789

        1234567.9

        123456e-9
        1.23456E9

        0d3456789
        0D3456789

        0xaa56789
        0xAa56789
        0xAA56789
        0Xaa56789
        0XAa56789
        0XaA56789

        023456701
        0o3456701
        0O3456701

        0b0000001
        0B0000001
      RUBY
    end

    it "accepts a line consisting only of a literal with interpolation" do
      expect_no_offenses(<<~'RUBY') # FIXME: Why is this tSTRING_END
        "23#{6}8"

        %(3#{6}8)
        %Q(#{6}8)

        %x(#{6}8)

        /2#{56}8/
        %r(#{6}8)

        :"_#{7}8"
      RUBY
    end

    it "accepts a line containing adjacent string literals" do
      expect_no_offenses("'abc' '123'")
    end

    it "accepts a line containing just a literal with trailing comma" do
      expect_no_offenses(<<~RUBY)
        foo(
          "4567",
        )
      RUBY
    end
  end

  it "registers an offense for a line that's 81 characters wide" do
    inspect_source('#' * 81)
    expect(cop.offenses.size).to eq(1)
    expect(cop.offenses.first.message).to eq('Line is too long. [81/80]')
    expect(cop.config_to_allow_offenses).to eq(exclude_limit: { 'Max' => 81 })
  end

  it 'highlights excessive characters' do
    inspect_source('#' * 80 + 'abc')
    expect(cop.highlights).to eq(['abc'])
  end

  it "accepts a line that's 80 characters wide" do
    expect_no_offenses('#' * 80)
  end

  it 'accepts the first line if it is a shebang line' do
    expect_no_offenses(<<~RUBY)
      #!/System/Library/Frameworks/Ruby.framework/Versions/2.3/usr/bin/ruby --disable-gems

      do_something
    RUBY
  end

  it 'registers an offense for long line before __END__ but not after' do
    inspect_source(['#' * 150,
                    '__END__',
                    '#' * 200].join("\n"))
    expect(cop.messages).to eq(['Line is too long. [150/80]'])
  end

  context 'when AllowURI option is enabled' do
    let(:cop_config) { { 'Max' => 80, 'AllowURI' => true } }

    context 'and all the excessive characters are part of an URL' do
      it 'accepts the line' do
        expect_no_offenses(<<-RUBY)
          # Some documentation comment...
          # See: https://github.com/rubocop-hq/rubocop/commit/3b48d8bdf5b1c2e05e35061837309890f04ab08c
        RUBY
      end

      context 'and the URL is wrapped in single quotes' do
        it 'accepts the line' do
          expect_no_offenses(<<-RUBY)
            # See: 'https://github.com/rubocop-hq/rubocop/commit/3b48d8bdf5b1c2e05e35061837309890f04ab08c'
          RUBY
        end
      end

      context 'and the URL is wrapped in double quotes' do
        it 'accepts the line' do
          expect_no_offenses(<<-RUBY)
            # See: "https://github.com/rubocop-hq/rubocop/commit/3b48d8bdf5b1c2e05e35061837309890f04ab08c"
          RUBY
        end
      end
    end

    context 'and the excessive characters include a complete URL' do
      it 'registers an offense for the line' do
        expect_offense(<<-RUBY)
          # See: http://google.com/, http://gmail.com/, https://maps.google.com/, http://plus.google.com/
                                                                                ^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [105/80]
        RUBY
      end
    end

    context 'and the excessive characters include part of an URL ' \
            'and another word' do
      it 'registers an offense for the line' do
        expect_offense(<<-RUBY)
          # See: https://github.com/rubocop-hq/rubocop/commit/3b48d8bdf5b1c2e05e35061837309890f04ab08c and
                                                                                                      ^^^^ Line is too long. [106/80]
          #   http://google.com/
        RUBY
      end
    end

    context 'and an error other than URI::InvalidURIError is raised ' \
            'while validating an URI-ish string' do
      let(:cop_config) do
        { 'Max' => 80, 'AllowURI' => true, 'URISchemes' => %w[LDAP] }
      end

      let(:source) { <<-RUBY }
        xxxxxxxxxxxxxxxxxxxxxxxxxxxxzxxxxxxxxxxx = LDAP::DEFAULT_GROUP_UNIQUE_MEMBER_LIST_KEY
      RUBY

      it 'does not crash' do
        expect { inspect_source(source) }.not_to raise_error
      end
    end

    context 'and the URL does not have a http(s) scheme' do
      let(:source) { <<-RUBY }
        xxxxxxxxxxxxxxxxxxxxxxxxxxxxzxxxxxxxxxxx = 'otherprotocol://a.very.long.line.which.violates.LineLength/sadf'
      RUBY

      it 'rejects the line' do
        inspect_source(source)
        expect(cop.offenses.size).to eq(1)
      end

      context 'and the scheme has been configured' do
        let(:cop_config) do
          { 'Max' => 80, 'AllowURI' => true, 'URISchemes' => %w[otherprotocol] }
        end

        it 'does not register an offense' do
          expect_no_offenses(source)
        end
      end
    end
  end

  context 'when IgnoredPatterns option is set' do
    let(:cop_config) do
      {
        'Max' => 18,
        'IgnoredPatterns' => ['^\s*test\s', /^\s*def\s+test_/]
      }
    end

    let(:source) do
      <<~RUBY
        class ExampleTest < TestCase
          test 'some really long test description which exceeds length' do
          end
          def test_some_other_long_test_description_which_exceeds_length
          end
        end
      RUBY
    end

    it 'accepts long lines matching a pattern but not other long lines' do
      inspect_source(source)
      expect(cop.highlights).to eq(['< TestCase'])
    end
  end

  context 'when AllowHeredoc option is enabled' do
    let(:cop_config) { { 'Max' => 80, 'AllowHeredoc' => true } }

    let(:source) { <<-RUBY }
      <<-SQL
        SELECT posts.id, posts.title, users.name FROM posts LEFT JOIN users ON posts.user_id = users.id;
      SQL
    RUBY

    it 'accepts long lines in heredocs' do
      expect_no_offenses(source)
    end

    context 'when the source has no AST' do
      let(:source) { '# this results in AST being nil' }

      it 'does not crash' do
        expect { inspect_source(source) }.not_to raise_error
      end
    end

    context 'and only certain heredoc delimiters are permitted' do
      let(:cop_config) do
        { 'Max' => 80, 'AllowHeredoc' => %w[SQL OK], 'IgnoredPatterns' => [] }
      end

      let(:source) { <<-RUBY }
        foo(<<-DOC, <<-SQL, <<-FOO)
          1st offense: Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
          \#{<<-OK}
            no offense (permitted): Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
          OK
          2nd offense: Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
        DOC
          no offense (permitted): Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
          \#{<<-XXX}
            no offense (nested inside permitted): Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
          XXX
          no offense (permitted): Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
        SQL
          3rd offense: Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
          \#{<<-SQL}
            no offense (permitted): Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
          SQL
          4th offense: Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
        FOO
      RUBY

      it 'rejects long lines in heredocs with not permitted delimiters' do
        inspect_source(source)
        expect(cop.offenses.size).to eq(4)
      end
    end
  end

  context 'when AllowURI option is disabled' do
    let(:cop_config) { { 'Max' => 80, 'AllowURI' => false } }

    context 'and all the excessive characters are part of an URL' do
      it 'registers an offense for the line' do
        expect_offense(<<-RUBY)
          # Lorem ipsum dolar sit amet.
          # See: https://github.com/rubocop-hq/rubocop/commit/3b48d8bdf5b1c2e05e35061837309890f04ab08c
                                                                                ^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [102/80]
        RUBY
      end
    end
  end

  context 'when IgnoreCopDirectives is disabled' do
    let(:cop_config) { { 'Max' => 80, 'IgnoreCopDirectives' => false } }

    context 'and the source is acceptable length' do
      let(:acceptable_source) { 'a' * 80 }

      context 'with a trailing Rubocop directive' do
        let(:cop_directive) { ' # rubcop:disable Metrics/SomeCop' }
        let(:source) { acceptable_source + cop_directive }

        it 'registers an offense for the line' do
          inspect_source(source)
          expect(cop.offenses.size).to eq(1)
        end

        it 'highlights the excess directive' do
          inspect_source(source)
          expect(cop.highlights).to eq([cop_directive])
        end
      end

      context 'with an inline comment' do
        let(:excess_comment) { ' ###' }
        let(:source) { acceptable_source + excess_comment }

        it 'highlights the excess comment' do
          inspect_source(source)
          expect(cop.highlights).to eq([excess_comment])
        end
      end
    end

    context 'and the source is too long and has a trailing cop directive' do
      let(:excess_with_directive) { 'b # rubocop:disable Metrics/AbcSize' }
      let(:source) { 'a' * 80 + excess_with_directive }

      it 'highlights the excess source and cop directive' do
        inspect_source(source)
        expect(cop.highlights).to eq([excess_with_directive])
      end
    end
  end

  context 'when IgnoreCopDirectives is enabled' do
    let(:cop_config) { { 'Max' => 80, 'IgnoreCopDirectives' => true } }

    context 'and the Rubocop directive is excessively long' do
      let(:source) { <<-RUBY }
        # rubocop:disable Metrics/SomeReallyLongMetricNameThatShouldBeMuchShorterAndNeedsANameChange
      RUBY

      it 'accepts the line' do
        expect_no_offenses(source)
      end
    end

    context 'and the Rubocop directive causes an excessive line length' do
      let(:source) { <<-RUBY }
        def method_definition_that_is_just_under_the_line_length_limit(foo, bar) # rubocop:disable Metrics/AbcSize
          # complex method
        end
      RUBY

      it 'accepts the line' do
        expect_no_offenses(source)
      end

      context 'and has explanatory text' do
        let(:source) { <<-RUBY }
          def method_definition_that_is_just_under_the_line_length_limit(foo) # rubocop:disable Metrics/AbcSize inherently complex!
            # complex
          end
        RUBY

        it 'does not register an offense' do
          expect_no_offenses(source)
        end
      end
    end

    context 'and the source is too long' do
      let(:source) { 'a' * 80 + 'bcd' + ' # rubocop:enable Style/ClassVars' }

      it 'registers an offense for the line' do
        inspect_source(source)
        expect(cop.offenses.size).to eq(1)
      end

      it 'highlights only the non-directive part' do
        inspect_source(source)
        expect(cop.highlights).to eq(['bcd'])
      end

      context 'and the source contains non-directive # as comment' do
        let(:source) { <<-RUBY }
          aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa # bbbbbbbbbbbbbb # rubocop:enable Style/ClassVars'
        RUBY

        it 'registers an offense for the line' do
          inspect_source(source)
          expect(cop.offenses.size).to eq(1)
        end

        it 'highlights only the non-directive part' do
          inspect_source(source)
          expect(cop.highlights).to eq(['bbbbbbb'])
        end
      end

      context 'and the source contains non-directive #s as non-comment' do
        let(:source) { <<-RUBY }
          LARGE_DATA_STRING_PATTERN = %r{\A([A-Za-z0-9\+\/#]*\={0,2})#([A-Za-z0-9\+\/#]*\={0,2})#([A-Za-z0-9\+\/#]*\={0,2})\z} # rubocop:disable Metrics/LineLength
        RUBY

        it 'registers an offense for the line' do
          inspect_source(source)
          expect(cop.offenses.size).to eq(1)
        end

        it 'highlights only the non-directive part' do
          inspect_source(source)
          expect(cop.highlights).to eq([']*={0,2})#([A-Za-z0-9+/#]*={0,2})z}'])
        end
      end
    end
  end

  context 'affecting by IndentationWidth from Layout\Tab' do
    shared_examples 'with tabs indentation' do
      it "registers an offense for a line that's including 2 tab with size 2" \
         ' and 28 other characters' do
        inspect_source("\t\t" + '#' * 28)
        expect(cop.offenses.size).to eq(1)
        expect(cop.offenses.first.message).to eq('Line is too long. [32/30]')
        expect(cop.config_to_allow_offenses)
          .to eq(exclude_limit: { 'Max' => 32 })
      end

      it 'highlights excessive characters' do
        inspect_source("\t" + '#' * 28 + 'a')
        expect(cop.highlights).to eq(['a'])
      end

      it "accepts a line that's including 1 tab with size 2" \
         ' and 28 other characters' do
        expect_no_offenses("\t" + '#' * 28)
      end
    end

    context 'without AllowURI option' do
      let(:config) do
        RuboCop::Config.new(
          'Layout/IndentationWidth' => {
            'Width' => 1
          },
          'Layout/Tab' => {
            'Enabled' => false,
            'IndentationWidth' => 2
          },
          'Metrics/LineLength' => {
            'Max' => 30
          }
        )
      end

      it_behaves_like 'with tabs indentation'
    end

    context 'with AllowURI option' do
      let(:config) do
        RuboCop::Config.new(
          'Layout/IndentationWidth' => {
            'Width' => 1
          },
          'Layout/Tab' => {
            'Enabled' => false,
            'IndentationWidth' => 2
          },
          'Metrics/LineLength' => {
            'Max' => 30,
            'AllowURI' => true
          }
        )
      end

      it_behaves_like 'with tabs indentation'

      it "accepts a line that's including URI" do
        expect_no_offenses("\t\t# https://github.com/rubocop-hq/rubocop")
      end

      it "accepts a line that's including URI and exceeds by 1 char" do
        expect_no_offenses("\t\t# https://github.com/ruboco")
      end

      it "accepts a line that's including URI with text" do
        expect_no_offenses("\t\t# See https://github.com/rubocop-hq/rubocop")
      end

      it "accepts a line that's including URI in quotes with text" do
        expect_no_offenses("\t\t# See 'https://github.com/rubocop-hq/rubocop'")
      end
    end
  end

  context 'autocorrection' do
    let(:cop_config) do
      { 'Max' => 40, 'IgnoredPatterns' => nil, 'AutoCorrect' => true }
    end

    context 'hash' do
      context 'when under limit' do
        it 'does not add any offenses' do
          expect_no_offenses(<<~RUBY)
            {foo: 1, bar: "2"}
          RUBY
        end
      end

      context 'when over limit because of a comment' do
        it 'adds an offense and does not autocorrect' do
          expect_offense(<<~RUBY)
            { # supersupersupersupersupersupersupersupersupersupersupersuperlongcomment
                                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [75/40]
              baz: "10000",
              bar: "10000"}
          RUBY

          expect_correction(<<~RUBY)
            { # supersupersupersupersupersupersupersupersupersupersupersuperlongcomment
              baz: "10000",
              bar: "10000"}
          RUBY
        end
      end

      context 'when over limit and already on multiple lines long key' do
        it 'adds an offense and does not autocorrect' do
          expect_offense(<<~RUBY)
            {supersupersupersupersupersupersupersupersupersupersupersuperfirstarg: 10,
                                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [74/40]
              baz: "10000",
              bar: "10000"}
          RUBY

          expect_correction(<<~RUBY)
            {supersupersupersupersupersupersupersupersupersupersupersuperfirstarg: 10,
              baz: "10000",
              bar: "10000"}
          RUBY
        end
      end

      context 'when over limit and keys already on multiple lines' do
        it 'adds an offense and does not autocorrect' do
          expect_offense(<<~RUBY)
            {
              baz0: "10000",
              baz1: "10000",
              baz2: "10000", baz2: "10000", baz3: "10000", baz4: "10000",
                                                    ^^^^^^^^^^^^^^^^^^^^^ Line is too long. [61/40]
              bar: "10000"}
          RUBY

          expect_correction(<<~RUBY)
            {
              baz0: "10000",
              baz1: "10000",
              baz2: "10000", baz2: "10000", baz3: "10000", baz4: "10000",
              bar: "10000"}
          RUBY
        end
      end

      context 'when over limit' do
        it 'adds an offense and autocorrects it' do
          expect_offense(<<~RUBY)
            {abc: "100000", def: "100000", ghi: "100000", jkl: "100000", mno: "100000"}
                                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [75/40]
          RUBY

          expect_correction(<<~RUBY)
            {abc: "100000", def: "100000",\s
            ghi: "100000", jkl: "100000", mno: "100000"}
          RUBY
        end
      end

      context 'when over limit rocket' do
        it 'adds an offense and autocorrects it' do
          expect_offense(<<~RUBY)
            {"abc" => "100000", "def" => "100000", "casd" => "100000", "asdf" => "100000"}
                                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [78/40]
          RUBY

          expect_correction(<<~RUBY)
            {"abc" => "100000", "def" => "100000",\s
            "casd" => "100000", "asdf" => "100000"}
          RUBY
        end
      end

      context 'when over limit rocket symbol' do
        it 'adds an offense and autocorrects it' do
          expect_offense(<<~RUBY)
            {:abc => "100000", :asd => "100000", :asd => "100000", :fds => "100000"}
                                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [72/40]
          RUBY

          expect_correction(<<~RUBY)
            {:abc => "100000", :asd => "100000",\s
            :asd => "100000", :fds => "100000"}
          RUBY
        end
      end

      context 'when nested hashes on same line' do
        it 'adds an offense only to outer and autocorrects it' do
          expect_offense(<<~RUBY)
            {abc: "100000", def: "100000", ghi: {abc: "100000"}, jkl: "100000", mno: "100000"}
                                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [82/40]
          RUBY

          expect_correction(<<~RUBY)
            {abc: "100000", def: "100000",\s
            ghi: {abc: "100000"}, jkl: "100000", mno: "100000"}
          RUBY
        end
      end

      context 'when hash in method call' do
        it 'adds an offense only to outer and autocorrects it' do
          expect_offense(<<~RUBY)
            get(
              :index,
              params: {driver_id: driver.id, from_date: "2017-08-18T15:09:04.000Z", to_date: "2017-09-19T15:09:04.000Z"},
                                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [109/40]
              xhr: true)
          RUBY

          expect_correction(<<~RUBY)
            get(
              :index,
              params: {driver_id: driver.id,\s
            from_date: "2017-08-18T15:09:04.000Z", to_date: "2017-09-19T15:09:04.000Z"},
              xhr: true)
          RUBY
        end
      end
    end

    context 'method call' do
      context 'when under limit' do
        it 'does not add any offenses' do
          expect_no_offenses(<<~RUBY)
            foo(foo: 1, bar: "2")
          RUBY
        end
      end

      context 'when two together' do
        it 'does not add any offenses' do
          expect_no_offenses(<<~RUBY)
            def baz(bar)
              foo(shipment, actionable_delivery) &&
                bar(shipment, actionable_delivery)
            end
          RUBY
        end
      end

      context 'when over limit' do
        it 'adds an offense and autocorrects it' do
          expect_offense(<<~RUBY)
            foo(abc: "100000", def: "100000", ghi: "100000", jkl: "100000", mno: "100000")
                                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [78/40]
          RUBY

          expect_correction(<<~RUBY)
            foo(abc: "100000", def: "100000",\s
            ghi: "100000", jkl: "100000", mno: "100000")
          RUBY
        end
      end

      context 'when call with hash on same line' do
        it 'adds an offense only to outer and autocorrects it' do
          expect_offense(<<~RUBY)
            foo(abc: "100000", def: "100000", ghi: {abc: "100000"}, jkl: "100000", mno: "100000")
                                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [85/40]
          RUBY

          expect_correction(<<~RUBY)
            foo(abc: "100000", def: "100000",\s
            ghi: {abc: "100000"}, jkl: "100000", mno: "100000")
          RUBY
        end
      end

      context 'when two method calls' do
        it 'adds an offense only to outer and autocorrects it' do
          expect_offense(<<~RUBY)
            get(1000000, 30000, foo(44440000, 30000, 39999, 19929120312093))
                                                    ^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [64/40]
          RUBY

          expect_correction(<<~RUBY)
            get(1000000, 30000,\s
            foo(44440000, 30000, 39999, 19929120312093))
          RUBY
        end
      end

      context 'when nested method calls allows outer to get broken up first' do
        it 'adds offense and does not autocorrect' do
          expect_offense(<<~RUBY)
            get(1000000,
            foo(44440000, 30000, 39999, 1992), foo(44440000, 30000, 39999, 12093))
                                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [70/40]
          RUBY

          expect_correction(<<~RUBY)
            get(1000000,
            foo(44440000, 30000, 39999, 1992), foo(44440000, 30000, 39999, 12093))
          RUBY
        end
      end
    end

    context 'array' do
      context 'when under limit' do
        it 'does not add any offenses' do
          expect_no_offenses(<<~RUBY)
            [1, "2"]
          RUBY
        end
      end

      context 'when already on two lines' do
        it 'does not add any offenses' do
          expect_no_offenses(<<~RUBY)
            [1, "2",
             "3"]
          RUBY
        end
      end

      context 'when over limit' do
        it 'adds an offense and autocorrects it' do
          expect_offense(<<~RUBY)
            ["1111", "100000", "100000", "100000", "100000", "100000"]
                                                    ^^^^^^^^^^^^^^^^^^ Line is too long. [58/40]
          RUBY

          expect_correction(<<~RUBY)
            ["1111", "100000", "100000", "100000",\s
            "100000", "100000"]
          RUBY
        end
      end

      context 'when has inside array' do
        it 'adds an offense only to outer and autocorrects it' do
          expect_offense(<<~RUBY)
            ["1111", "100000", "100000", "100000", {abc: "100000", b: "2"}, "100000", "100000"]
                                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [83/40]
          RUBY

          expect_correction(<<~RUBY)
            ["1111", "100000", "100000", "100000",\s
            {abc: "100000", b: "2"}, "100000", "100000"]
          RUBY
        end
      end

      context 'when two arrays on two lines allows outer to get broken first' do
        it 'adds an offense only to inner and does not autocorrect it' do
          expect_offense(<<~RUBY)
            [1000000, 3912312312999,
              [44440000, 3912312312999, 3912312312999, 1992912031231232131312093],
                                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [70/40]
            100, 100]
          RUBY

          expect_correction(<<~RUBY)
            [1000000, 3912312312999,
              [44440000, 3912312312999, 3912312312999, 1992912031231232131312093],
            100, 100]
          RUBY
        end
      end
    end

    context 'no breakable collections' do
      it 'adds an offense and does not autocorrect it' do
        expect_offense(<<~RUBY)
          10000003912312312999
            # 444400003912312312999391231231299919929120312312321313120933333333
                                                  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [70/40]
          456
        RUBY

        expect_correction(<<~RUBY)
          10000003912312312999
            # 444400003912312312999391231231299919929120312312321313120933333333
          456
        RUBY
      end
    end

    context 'semicolon' do
      context 'when under limit' do
        it 'does not add any offenses' do
          expect_no_offenses(<<~RUBY)
            {foo: 1, bar: "2"}; a = 4 + 5
          RUBY
        end
      end

      context 'when over limit' do
        it 'adds offense and autocorrects it by breaking the semicolon' \
          'before the hash' do
          expect_offense(<<~RUBY)
            {foo: 1, bar: "2"}; a = 400000000000 + 500000000000000
                                                    ^^^^^^^^^^^^^^ Line is too long. [54/40]
          RUBY

          expect_correction(<<~RUBY)
            {foo: 1, bar: "2"};
             a = 400000000000 + 500000000000000
          RUBY
        end
      end

      context 'when over limit and semicolon at end of line' do
        it 'adds offense and autocorrects it by breaking the first semicolon' \
          'before the hash' do
          expect_offense(<<~RUBY)
            {foo: 1, bar: "2"}; a = 400000000000 + 500000000000000;
                                                    ^^^^^^^^^^^^^^^ Line is too long. [55/40]
          RUBY

          expect_correction(<<~RUBY)
            {foo: 1, bar: "2"};
             a = 400000000000 + 500000000000000;
          RUBY
        end
      end

      context 'when over limit and many spaces around semicolon' do
        it 'adds offense and autocorrects it by breaking the semicolon' \
          'before the hash' do
          expect_offense(<<~RUBY)
            {foo: 1, bar: "2"}  ;   a = 400000000000 + 500000000000000
                                                    ^^^^^^^^^^^^^^^^^^ Line is too long. [58/40]
          RUBY

          expect_correction(<<~RUBY)
            {foo: 1, bar: "2"}  ;
               a = 400000000000 + 500000000000000
          RUBY
        end
      end

      context 'when over limit and many semicolons' do
        it 'adds offense and autocorrects it by breaking the semicolon' \
          'before the hash' do
          expect_offense(<<~RUBY)
            {foo: 1, bar: "2"}  ;;; a = 400000000000 + 500000000000000
                                                    ^^^^^^^^^^^^^^^^^^ Line is too long. [58/40]
          RUBY

          expect_correction(<<~RUBY)
            {foo: 1, bar: "2"}  ;;;
             a = 400000000000 + 500000000000000
          RUBY
        end
      end

      context 'when over limit and one semicolon at the end' do
        it 'adds offense and does not autocorrect' \
          'before the hash' do
          expect_offense(<<~RUBY)
            a = 400000000000 + 500000000000000000000;
                                                    ^ Line is too long. [41/40]
          RUBY

          expect_correction(<<~RUBY)
            a = 400000000000 + 500000000000000000000;
          RUBY
        end
      end

      context 'when over limit and many semicolons at the end' do
        it 'adds offense and does not autocorrect' \
          'before the hash' do
          expect_offense(<<~RUBY)
            a = 400000000000 + 500000000000000000000;;;;;;;
                                                    ^^^^^^^ Line is too long. [47/40]
          RUBY

          expect_correction(<<~RUBY)
            a = 400000000000 + 500000000000000000000;;;;;;;
          RUBY
        end
      end

      context 'semicolon inside string literal' do
        it 'adds offense and autocorrects elsewhere' do
          expect_offense(<<~RUBY)
            FooBar.new(baz: 30, bat: 'publisher_group:123;publisher:456;s:123')
                                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [67/40]
          RUBY

          expect_correction(<<~RUBY)
            FooBar.new(baz: 30,\s
            bat: 'publisher_group:123;publisher:456;s:123')
          RUBY
        end
      end

      context 'semicolons inside string literal' do
        it 'adds offense and autocorrects elsewhere' do
          expect_offense(<<~RUBY)
            "00000000000000000;0000000000000000000'000000;00000'0000;0000;000"
                                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^ Line is too long. [66/40]
          RUBY

          expect_correction(<<~RUBY)
            "00000000000000000;0000000000000000000'000000;00000'0000;0000;000"
          RUBY
        end
      end
    end

    context 'HEREDOC' do
      let(:cop_config) do
        { 'Max' => 40, 'AllowURI' => false, 'AllowHeredoc' => false }
      end

      context 'when over limit with semicolon' do
        it 'adds offense and does not autocorrect' do
          expect_offense(<<~RUBY)
            foo = <<-SQL
              SELECT a b c d a b FROM c d a b c d ; COUNT(*) a b
                                                    ^^^^^^^^^^^^ Line is too long. [52/40]
            SQL
          RUBY

          expect_correction(<<~RUBY)
            foo = <<-SQL
              SELECT a b c d a b FROM c d a b c d ; COUNT(*) a b
            SQL
          RUBY
        end
      end
    end

    context 'comments' do
      context 'when over limit with semicolon' do
        it 'adds offense and does not autocorrect' do
          expect_offense(<<~RUBY)
            # a b c d a b c d a b c d ; a b c d a b c d a b c d a
                                                    ^^^^^^^^^^^^^ Line is too long. [53/40]
          RUBY

          expect_correction(<<~RUBY)
            # a b c d a b c d a b c d ; a b c d a b c d a b c d a
          RUBY
        end
      end
    end
  end
end
