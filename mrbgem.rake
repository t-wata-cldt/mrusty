class MRuby::Build
  attr_accessor :libmrusty, :libmrusty_rlib

  debug_mod = Module.new do
    def enable_debug
      super
      @debug_enabled = true
    end

    def debug_enabled?; @debug_enabled end
  end
  prepend debug_mod
end

class MRuby::Gem::Specification
  cargo_mod = Module.new do
    def rust_source; "#{dir}/src/lib.rs" end
    def rust_project?; File.exists? rust_source end

    def add_cargo_dependency(name, version)
      @cargo_dependencies ||= {}
      @cargo_dependencies[name] = version
    end

    def cargo_lib_dep_file
      Dir.glob("#{build_dir}/#{cargo_build_type}/.fingerprint/#{name}-*/dep-lib-#{funcname}").first
    end

    def cargo_lib_dep_target
      "#{build_dir}/#{cargo_build_type}/deps/#{funcname}.d"
    end

    def set_cargo_library_dependencies lib
      file lib => File.read(cargo_lib_dep_file).gsub("\\\n ", "")
                    .scan(/^(\S+):\s+(.+)/).find{|t,_| t == cargo_lib_dep_target }[1].split(/\s+/) if
        File.exists? cargo_lib_dep_file || ''

      # build.linker.libraries << funcname
      # build.linker.library_paths << File.dirname(lib)

      # file libfile("#{build.build_dir}/lib/libmruby") => lib

      mod_self = self
      mod = Module.new do
        define_method :invoke do
          unless mod_self.instance_variable_get :@cargo_lib_added
            build = mod_self.build
            build.gems.each do |g|
              g.bins.each do |b|
                build.file build.exefile("#{build.build_dir}/bin/#{b}") => lib
              end
            end

            mrbtest = build.exefile("#{build.build_dir}/bin/mrbtest")
            build.file mrbtest => lib if MiniRake::Task::TASKS[mrbtest]
            mod_self.instance_variable_set :@cargo_lib_added, true
          end

          super()
        end
      end
      MiniRake::Task.prepend mod
    end

    def cargo_manifest_file; "#{dir}/Cargo.toml" end

    def generate_cargo_manifest
      <<EOS
[package]
name = "#{name}"
version = "#{version}"
authors = [#{[authors].flatten.map{|v| "\"#{v}\""}.join ', '}]
description = "#{summary}"
license = "#{licenses}"

[profile.dev]
panic = 'abort'

[lib]
name = "#{funcname}"
crate-type = ["staticlib"]

[dependencies]
#{@cargo_dependencies.map{|k,v| "#{k} = \"#{v}\"" }.join("\n")}
EOS
    end

    def cargo_build_type
      build.debug_enabled? ? 'debug' : 'release'
    end

    def setup
      return super if
        name == 'mrusty' ||
        !rust_project?

      prev_init = @build_config_initializer
      @build_config_initializer = Proc.new do
        add_dependency 'mrusty'

        next if @generate_functions

        @generate_functions = true
        @objs << objfile("#{build_dir}/gem_init")


        dummy = "#{build_dir}/_dummy"
        dummy_src = "#{dummy}.c"
        @objs << objfile(dummy)
        file objfile(dummy) => dummy_src
        file dummy_src do |t|
          FileUtils.mkdir_p File.dirname t.name
          File.write t.name, ''
        end

        instance_eval(&prev_init) if prev_init
      end

      super

      file objfile("#{build_dir}/gem_init") => [__FILE__]

      file cargo_manifest_file => [__FILE__, "#{dir}/mrbgem.rake"] do |t|
        FileUtils.mkdir_p File.dirname t.name
        File.write t.name, generate_cargo_manifest
      end

      out_lib = libfile "#{build_dir}/#{cargo_build_type}/lib#{funcname}"
      file out_lib => [rust_source, __FILE__, build.libmrusty, cargo_manifest_file] do |t|
        _pp 'CARGO', t.name
        cmd = %Q[RUSTFLAGS="--extern mrusty=#{build.libmrusty_rlib}"]
        cmd << " CARGO_TARGET_DIR='#{build_dir}' cargo build --lib"
        cmd << " --manifest-path='#{cargo_manifest_file}'"
        cmd << ' --release' unless build.debug_enabled?
        cmd << ' -v' if $trace
        sh cmd
      end
      set_cargo_library_dependencies out_lib
    end
  end
  prepend cargo_mod
end

MRuby::Gem::Specification.new 'mrusty' do |spec|
  spec.license = 'MPL'
  spec.author = 'mrusty developers'
  spec.summary = 'mruby binding library'

  out_lib = libfile "#{build_dir}/#{cargo_build_type}/lib#{funcname}"
  build.libmrusty = out_lib
  build.libmrusty_rlib = "#{build_dir}/#{cargo_build_type}/libmrusty.rlib"
  file out_lib => ["#{dir}/src/lib.rs", __FILE__, cargo_manifest_file] do |t|
    _pp 'CARGO', t.name
    cmd = "MRUBY_ROOT='#{MRUBY_ROOT}' CARGO_TARGET_DIR='#{build_dir}' cargo build --features set_mruby_path --lib"
    cmd << " --manifest-path='#{cargo_manifest_file}'"
    cmd << ' --release' unless build.debug_enabled?
    cmd << ' -v' if $trace
    sh cmd
  end
  set_cargo_library_dependencies out_lib

  add_dependency 'mruby-error', core: 'mruby-error'
end
