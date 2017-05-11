# encoding: UTF-8
require 'schema2script/sql_generator'

module Schema2Script
    class H2Generator < SqlGenerator
        def initialize
            super 'H2'
        end
    end
end
