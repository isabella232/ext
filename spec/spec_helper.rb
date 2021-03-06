ROOT = File.expand_path('../..', __FILE__)

require 'bundler/setup'
require 'liquid/boot'

require 'rspec'

RSpec.configure do |config|
  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = 'random'
end

# load helper classes & functions from files in spec/support/
Dir[File.join(ROOT, "spec/support/**/*.rb")].each { |f| require f }

# be silent
$log.mute!
