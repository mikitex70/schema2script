# encoding: UTF-8
 
module Schema2Script
    class FK_Constraint
        attr_accessor :kind, :name, :child, :master
        
        def initialize(kind, name, child, master)
            @kind   = kind
            @child  = child
            @master = master
            @name   = name || master.table.name
        end
    end
end
