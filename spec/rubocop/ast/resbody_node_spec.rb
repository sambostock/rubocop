# frozen_string_literal: true

require 'pry'

RSpec.describe RuboCop::AST::ResbodyNode do
  let(:resbody_node) do
    begin_node = parse_source(source).ast
    rescue_node, = *begin_node
    rescue_node.children[1]
  end

  describe '.new' do
    let(:source) { 'begin; beginbody; rescue; rescuebody; end' }

    it { expect(resbody_node.is_a?(described_class)).to be(true) }
  end

  describe '#body' do
    let(:source) { 'begin; beginbody; rescue Error => ex; :rescuebody; end' }

    it { expect(resbody_node.body.sym_type?).to be(true) }
  end

  describe '#rescued_classes' do
    context 'with none specified' do
      let(:source) { 'begin; rescue; end' }

      it { expect(resbody_node.rescued_classes).to be_nil }
    end

    context 'with one specified' do
      let(:source) { 'begin; rescue SomeError; end' }

      it { expect(resbody_node.rescued_classes.source).to eq('SomeError') }
    end

    context 'with many specified' do
      let(:source) { 'begin; rescue SomeError, AnotherError; end' }

      it { expect(resbody_node.rescued_classes.source).to eq('SomeError, AnotherError') }
    end
  end

  context 'with variable assignment' do
    let(:source) { 'begin; rescue => error; end' }

    describe '#assignment' do
      it { expect(resbody_node.assignment.source).to eq('error') }
    end

    describe '#local_variable_name' do
      it { expect(resbody_node.local_variable_name).to eq(:error) }
    end
  end

  context 'with complex assignment' do
    let(:source) { 'begin; rescue => X.error; end' }

    describe '#assignment' do
      it { expect(resbody_node.assignment.source).to eq('X.error') }
    end

    describe '#local_variable_name' do
      it { expect(resbody_node.local_variable_name).to be_falsey }
    end
  end

  context 'without assignment' do
    let(:source) { 'begin; rescue; end' }

    describe '#assignment' do
      it { expect(resbody_node.assignment).to be_nil }
    end

    describe '#local_variable_name' do
      it { expect(resbody_node.local_variable_name).to be_falsey }
    end
  end
end
