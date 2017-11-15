require 'spec_helper'
describe 'website' do
  context 'with default values for all parameters' do
    it { should contain_class('website') }
  end
end
