#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "yaml"

action_path, output_dir = ARGV
abort "usage: #{$PROGRAM_NAME} ACTION_YML OUTPUT_DIR" unless action_path && output_dir

FileUtils.rm_rf(output_dir)
FileUtils.mkdir_p(output_dir)

steps = YAML.load_file(action_path).dig("runs", "steps") || []
steps.each_with_index do |step, index|
  run = step["run"]
  next unless run

  File.write(File.join(output_dir, "step-#{index + 1}.sh"), "#!/usr/bin/env bash\n#{run}\n")
end
