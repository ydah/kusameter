# frozen_string_literal: true

require_relative "lib/kusameter/version"

Gem::Specification.new do |spec|
  spec.name = "kusameter"
  spec.version = Kusameter::VERSION
  spec.authors = ["Yudai Takada"]
  spec.email = ["t.yudai92@gmail.com"]

  spec.summary = "Measure GitHub open source contributions by user and date range"
  spec.description = "Count public pull requests, commits, issues, and reviews with a Ruby API and CLI."
  spec.homepage = "https://github.com/ydah/kusameter"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3.0"
  spec.metadata["rubygems_mfa_required"] = "true"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

end
