# encoding: UTF-8
 
module Schema2Script
    class FK_Constraint
        attr_accessor :name, :child, :master
        
        def initialize(name, child, master)
            @child  = child
            @master = master
            @name   = name || master.table.name
        end
    end
end
