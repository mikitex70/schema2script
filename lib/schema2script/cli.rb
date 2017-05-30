# encoding: UTF-8
require 'thor'
require 'chunky_png'
require 'base64'
require 'schema2script/schema_reader'
require 'schema2script/h2_generator'
require 'schema2script/oracle_generator'

module Schema2Script
    
    class CLI < Thor
        include Thor::Actions
        
        desc "sboot [options] schema.[xml|svg]", "Generate sboot commands from www.draw.io ER schemas"
        long_desc <<-LONGDESC
          Generates sources based on the entities defined in the specified schema diagram.\n
          Diagrams can be in XML format (compressed or not) or in SVG format with embedded XML source.
        LONGDESC
        method_option :env,    :enum    => [ "fullstack", "api", "backend", "conversion", "persistence" ],
                               :default => "fullstack",
                               :desc    => "kind of stack to generate"
        method_option :file,   :default => "sboot_generate.sh",
                               :desc    => "file for the generated sboot commands script"
        method_option :stdout, :type    => :boolean,
                               :default => false,
                               :desc    => "generate code to standard output"
        def sboot(file)
            tables = Schema2Script::SchemaReader.new(file).get_tables
            
            emit generate_sboot_commands(tables, options[:env])
        end
        
        desc "ddl [options] schema.[xml|svg]", "Generate sboot commands from www.draw.io ER schemas"
        long_desc <<-LONGDESC
          Generates am SQL DDL script from the entities defined in the specified schema diagram.\n
          Diagrams can be in XML format (compressed or not) or in SVG format with embedded XML source.
        LONGDESC
        method_option :dialect, :enum    => [ "h2", "oracle" ],
                                :default => "h2",
                                :desc    => "SQL dialect when generating DDL"
        method_option :file,    :default => "src/main/resources/database/db_create.sql",
                                :desc    => "file for the generated DDL script"
        method_option :stdout,  :type    => :boolean,
                                :default => false,
                                :desc    => "generate code to standard output"
        def ddl(file)
            tables    = Schema2Script::SchemaReader.new(file).get_tables
            generator = sql_generator options[:dialect]
            
            tables.each { |table| generator.validate table }
            
            emit generate_ddl(tables, generator)
        end
        
        desc "validate [options] schema.[xml|svg]", "Validate an www.draw.io ER schema"
        long_desc <<-LONGDESC
          Validates the entities defined in the specified schema diagram.\n
          Diagrams can be in XML format (compressed or not) or in SVG format with embedded XML source.
        LONGDESC
        method_option :dialect, :enum    => [ "h2", "oracle" ],
                                :default => "h2",
                                :desc    => "SQL dialect when generating DDL"
        def validate(file)
            tables    = (Schema2Script::SchemaReader.new file).get_tables
            generator = sql_generator options[:dialect]
            tables.each { |table| generator.validate table }
        end
        
        private
        
        def emit(text)
            if options[:stdout]
                puts text
            else
                FileUtils.mkdir_p File.dirname(options[:file])
                File.write options[:file], text
            end
        end
        
        def generate_sboot_commands(tables, env)
            return tables.map { |table| "sboot generate --env=#{env} #{table.name}#{plural table} #{sbootFields table}" }.join("\n")
        end
        
        def plural table
            return ":#{table.plural}" unless table.plural.empty?
            ""
        end
        
        def sbootFields(table)
            table.fields.map { |field| "#{field.name}#{sbootType(field)}#{sbootConstraint(field)}"}.join(" ")
        end
        
        def sbootType(field)
            sbtype = if field.type =~ /^(\w+)/ then $1 else field.type end
            return ''      if sbtype.empty?
            return ':text' if sbtype.casecmp('char') == 0 # char type isn't recognized by sboot
            
            return ":#{sbtype}" if ['string','text','varchar','varchar2','number','long','int','integer','double','numeric','date','uuid'].include? sbtype.downcase
            
            STDERR.puts "WARNING: type #{sbtype} is not supported by sboot (field #{field.table.name}.#{field.name})"
            '' # fallthrough for an unrecognized type
        end
        
        def sbootConstraint(field)
            return "" if field.constraints.empty?
            ":#{field.constraints.join()}"
        end
        
        def sql_generator(dialect)
            case options[:dialect]
            when 'h2'     then H2Generator.new
            when 'oracle' then OracleGenerator.new
            else abort "Unsupporto SQL dialect '#{options[:dialect]}'"
            end
        end
    
        def generate_ddl(tables, generator)
            generator.multiline_comment("Create script for #{generator.name} database")+
                    "\n"+
                    tables.map { |table| generator.generate_table(table) }.join()
        end

    end
end
