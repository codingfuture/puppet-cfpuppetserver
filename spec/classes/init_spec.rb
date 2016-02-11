require 'spec_helper'
describe 'cfpuppetserver' do

  context 'with defaults for all parameters' do
    it { should contain_class('cfpuppetserver') }
  end
end
