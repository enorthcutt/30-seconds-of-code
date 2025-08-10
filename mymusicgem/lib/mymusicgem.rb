# frozen_string_literal: true

require_relative 'mymusicgem/configuration'
require_relative 'mymusicgem/client'
require_relative 'mymusicgem/version'

module Mymusicgem
  class << self
    def client(options = {})
      Client.new(options)
    end
  end
end
