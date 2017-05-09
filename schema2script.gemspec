# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'schema2script/version'

Gem::Specification.new do |spec|
    spec.name          = "schema2script"
    spec.version       = Schema2Script::VERSION
    spec.authors       = ["Michele Tessaro"]
    spec.email         = ["michele.tessaro@email.it"]
    
    spec.summary       = %q{Tools for generation of DDL scripts from www.draw.io ER schemas}
    spec.description   = %q{Tools for generation of DDL scripts from www.draw.io ER schemas}
    spec.homepage      = "https://github.com/mikitex70/schema2script"
    spec.license       = "MIT"
    
    spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
    spec.bindir        = "exe"
    spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
    spec.require_paths = ["lib"]
    
    if spec.respond_to?(:metadata)
        spec.metadata['allowed_push_host'] = "'http://mygemserver.com'"
    end
    
    spec.add_dependency 'thor'
    spec.add_dependency 'chunky_png'
    spec.add_development_dependency 'rspec'
    spec.add_development_dependency 'rake'
end
