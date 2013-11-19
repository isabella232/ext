# encoding: utf-8

require 'madvertise/router'

class GeneralRequestHandler; end

describe Router do
  let(:regex) { %r(foo(.*)bar) }
  let(:block) { Proc.new { 1+1 } }
  let(:router) { Router.new(GeneralRequestHandler) }

  describe '.add' do
    context 'add route' do

      before { router.add(regex, &block) }

      context 'regex' do
        subject { router.routes.last[0] }
        it { should eql regex }
      end

      context 'block' do
        subject { router.routes.last[1] }
        its(:call) { should eql block.call }
      end
    end
  end

  describe '.route' do
    let(:regex) { %r(/bar/) }

    let(:parser) { double('CustomRequestParser') }
    let(:env)    { "env" }

    before { router.route(regex, parser, :foo, :bar) }

    subject { router.routes.last[0] }

    it { should be_a Regexp }
    it { should eql regex }
    it 'builds correct block' do
      GeneralRequestHandler.should_receive(:handle).with(parser, env, {foo: 1, bar: 2})

      _, block = router.routes.last
      block.call([0,1,2], env)
    end
  end

  describe '.handle' do
    let(:handler) { double('MockHandler') }
    let(:request) { double('request') }
    let(:url_re_1) { 'http://ad.madvertise.de/uchte/(.*?)' }
    let(:url_re_2) { 'http://ad.madvertise.de/muchte/(*?)' }
    let(:block) { Proc.new {|match, env| handler.handle(match, env) } }

    before do
      router.add url_re_1 { }
      router.add url_re_2, &block
      router.route %r(/new_adx_bidrequest/(\w+)), GeneralRequestHandler, :site_token
    end

    it 'is not matching' do
      router.handle("http://ad.madvertise.de/muchtel", request).should == false
    end

    it 'is matching' do
      handler.should_receive(:handle)
      router.handle("http://ad.madvertise.de/muchte/foo", request).should == true
    end
  end
end

