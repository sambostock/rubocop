# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Style::AccessModifierDeclarations, :config do
  subject(:cop) { described_class.new(config) }

  context 'when `group` is configured' do
    let(:cop_config) do
      {
        'EnforcedStyle' => 'group'
      }
    end

    %w[private protected public].each do |access_modifier|
      it_behaves_like(
        'enforces group access modifier usage',
        access_modifier: access_modifier,
        construct: :class
      )
      it_behaves_like(
        'enforces group access modifier usage',
        access_modifier: access_modifier,
        construct: :module
      )
    end

    it_behaves_like(
      'enforces group access modifier usage',
      access_modifier: :module_function,
      construct: :module
    )
  end

  context 'when `inline` is configured' do
    let(:cop_config) do
      {
        'EnforcedStyle' => 'inline'
      }
    end

    %w[private protected public].each do |access_modifier|
      it_behaves_like(
        'enforces inline access modifier usage',
        access_modifier: access_modifier,
        construct: :class
      )
      it_behaves_like(
        'enforces inline access modifier usage',
        access_modifier: access_modifier,
        construct: :module
      )
    end

    it_behaves_like(
      'enforces inline access modifier usage',
      access_modifier: :module_function,
      construct: :module
    )
  end
end
