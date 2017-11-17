Gem::Specification.new do |s|
    s.name        = 'singularity-cli'
    s.version     = '1.1.0'
    s.licenses    = ['MIT']
    s.summary     = "singularity deploy and delete command line tools"
    s.description = "Usage: [singularity delete <uri> <file>] or [singularity deploy <uri> <file> <release>]"
    s.authors     = ["Travis Webb", "Chris Kite"]
    s.files       = %w[
                     LICENSE
                     README.md
                    ] + Dir['lib/*.rb'] + Dir['lib/singularity/*.rb']
    s.homepage    = 'https://github.com/offers/singularity-cli'
    s.executables = %w[singularity]
    s.add_runtime_dependency 'rest-client', '~> 1.8', '>= 1.8.0'
    s.add_runtime_dependency 'colorize', '~> 0.7.7', '>= 0.7.7'
end
