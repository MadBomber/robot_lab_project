# RobotLab project workspace — multi-repo management
# Run `just` or `just check` for the full health dashboard.

import '~/.justfile'

set no-exit-message # suppress just's "error: recipe failed" — recipes print their own errors
set no-cd           # run recipes relative to the justfile location, not the caller's cwd

repos := "robot_lab robot_lab-a2a robot_lab-document_store robot_lab-durable robot_lab-ractor robot_lab-rails"
github := "git@github.com:MadBomber"

[private]
default: list

[group('setup')]
[doc('Clone all repos into the current directory (safe to run on an existing workspace)')]
clone:
    #!/usr/bin/env bash
    for repo in {{repos}}; do
      if [ -d "$repo" ]; then
        printf '\033[1;33m%-30s\033[0m already exists — skipping\n' "$repo"
      else
        printf '\033[1;32m%-30s\033[0m cloning...\n' "$repo"
        git clone "{{github}}/$repo.git"
      fi
    done

# Full health dashboard: dirty working trees + unpushed commits + active path: overrides + version lockstep
[group('overview')]
[doc('Run all workspace health checks')]
check: status unpushed paths versions

[group('overview')]
[doc('Show uncommitted changes across all repos')]
status:
    #!/usr/bin/env bash
    found=0
    for repo in {{repos}}; do
      output=$(git -C "$repo" status --short 2>/dev/null)
      if [ -n "$output" ]; then
        found=1
        printf '\n\033[1;33m── %s\033[0m\n' "$repo"
        echo "$output"
      fi
    done
    if [ "$found" -eq 0 ]; then echo "All repos clean — nothing uncommitted."; fi

[group('overview')]
[doc('Show commits not yet pushed to the remote')]
unpushed:
    #!/usr/bin/env bash
    found=0
    for repo in {{repos}}; do
      output=$(git -C "$repo" log --oneline @{u}.. 2>/dev/null)
      if [ -n "$output" ]; then
        found=1
        printf '\n\033[1;36m── %s\033[0m\n' "$repo"
        echo "$output"
      fi
    done
    if [ "$found" -eq 0 ]; then echo "Nothing unpushed across all repos."; fi

[group('overview')]
[doc('Show active Gemfile path: overrides (local sibling wiring)')]
paths:
    #!/usr/bin/env bash
    found=0
    for repo in {{repos}}; do
      output=$(grep -n 'path:' "$repo/Gemfile" 2>/dev/null || true)
      if [ -n "$output" ]; then
        found=1
        printf '\n\033[1;35m── %s/Gemfile\033[0m\n' "$repo"
        echo "$output"
      fi
    done
    if [ "$found" -eq 0 ]; then echo "No local path: overrides active — all repos use released gems."; fi

[group('overview')]
[doc('Check extension version lockstep against RobotLab::VERSION')]
versions:
    #!/usr/bin/env ruby
    def extract_version(repo)
      file = Dir.glob("#{repo}/lib/**/version.rb").first
      return "(version.rb not found)" unless file
      File.read(file)[/VERSION\s*=\s*['"]([^'"]+)['"]/, 1] || "(VERSION not found)"
    end

    def branch_for(repo)
      branch = `git -C #{repo} rev-parse --abbrev-ref HEAD 2>/dev/null`.strip
      branch.empty? ? "?" : branch
    end

    core_version  = extract_version("robot_lab")
    core_branch   = branch_for("robot_lab")
    core_segments = core_version.split(".").first(3).join(".")

    extensions = %w[robot_lab-a2a robot_lab-document_store robot_lab-durable robot_lab-ractor robot_lab-rails]

    puts "\nCore: robot_lab #{core_version}  (#{core_branch})\n"

    failures = []
    extensions.each do |repo|
      version     = extract_version(repo)
      branch      = branch_for(repo)
      ext_base    = version.split(".").first(3).join(".")
      ok          = ext_base == core_segments
      failures   << repo unless ok
      badge       = ok ? "\e[32m OK \e[0m" : "\e[31mFAIL\e[0m"
      suffix      = version.split(".").length > 3 ? "  (extension patch)" : ""
      puts "  [#{badge}]  #{repo.ljust(28)} #{version}  (#{branch})#{suffix}"
    end

    puts ""
    if failures.empty?
      puts "All extensions are in lockstep with core (#{core_version})."
    else
      abort "Lockstep violation — first 3 segments must be #{core_segments}: #{failures.join(', ')}"
    end

[group('utility')]
[doc('Run a shell command in every repo')]
each cmd:
    #!/usr/bin/env bash
    for repo in {{repos}}; do
      printf '\n\033[1;32m── %s\033[0m\n' "$repo"
      (cd "$repo" && {{cmd}})
    done

[group('utility')]
[doc('Fetch from origin in all repos')]
fetch:
    #!/usr/bin/env bash
    for repo in {{repos}}; do
      printf '\033[1;32m%-30s\033[0m' "$repo"
      git -C "$repo" fetch --quiet 2>&1 && echo "fetched" || echo "FAILED"
    done

[group('utility')]
[doc('Update version.rb files to maintain lockstep')]
[confirm("Modify version.rb files across repos — are you sure?")]
bump-versions version="":
    #!/usr/bin/env ruby
    def version_file(repo)
      Dir.glob("#{repo}/lib/**/version.rb").first
    end

    def read_version(repo)
      file = version_file(repo)
      return nil unless file
      File.read(file)[/VERSION\s*=\s*['"]([^'"]+)['"]/, 1]
    end

    def write_version(repo, new_version)
      file = version_file(repo)
      return unless file
      content = File.read(file)
      updated = content.sub(/VERSION\s*=\s*(['"])([^'"]+)\1/, "VERSION = \\1#{new_version}\\1")
      File.write(file, updated)
    end

    extensions = %w[robot_lab-a2a robot_lab-document_store robot_lab-durable robot_lab-ractor robot_lab-rails]

    target = "{{version}}"
    if target.empty?
      target = read_version("robot_lab")
      puts "Syncing extensions to core version #{target}...\n\n"
      repos = extensions
    else
      abort "Invalid version '#{target}' — expected N.N.N or N.N.N.N" unless target.match?(/\A\d+\.\d+\.\d+(\.\d+)?\z/)
      puts "Bumping all repos to #{target}...\n\n"
      repos = ["robot_lab"] + extensions
    end

    repos.each do |repo|
      old   = read_version(repo)
      write_version(repo, target)
      arrow = old == target ? "\e[33m==\e[0m" : "\e[32m->\e[0m"
      printf "  %-30s %s %s %s\n", repo, old, arrow, target
    end

    puts "\nDone. Run `just versions` to verify."

[group('utility')]
[doc('Propagate Rakefile.common to all extension repos')]
sync-rakefiles:
    #!/usr/bin/env bash
    for repo in robot_lab-a2a robot_lab-document_store robot_lab-durable robot_lab-ractor robot_lab-rails; do
      cp Rakefile.common "$repo/Rakefile"
      printf '\033[1;32m%-30s\033[0m updated\n' "$repo"
    done

[group('utility')]
[doc('Propagate .rubocop.yml.common to all repos')]
sync-rubocop:
    #!/usr/bin/env bash
    for repo in {{repos}}; do
      cp .rubocop.yml.common "$repo/.rubocop.yml"
      printf '\033[1;32m%-30s\033[0m updated\n' "$repo"
    done
