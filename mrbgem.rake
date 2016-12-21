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
    def setup
      super

      return if name == 'mrusty'

      rust_source = "#{dir}/src/lib.rs"
      return unless File.exists? rust_source

      out_lib = libfile "#{build_dir}/#{cargo_build_type}/lib#{funcname}"
      file out_lib => [rust_source, __FILE__, build.libmrusty] do |t|
        cmd = %Q[RUSTFLAGS="-L crate='#{File.dirname build.libmrusty}' -lstatic=mrusty"]
        cmd << " CARGO_TARGET_DIR='#{build_dir}' cargo build --lib"
        cmd << " --manifest-path='#{dir}/Cargo.toml'"
        cmd << ' --release' unless build.debug_enabled?
        cmd << ' -v'
        sh cmd
      end

      add_dependency 'mrusty'

      build.linker.libraries << funcname
      build.linker.library_paths << File.dirname(out_lib)

      file libfile("#{build.build_dir}/lib/libmruby") => out_lib
    end

    def cargo_build_type
      build.debug_enabled? ? 'debug' : 'release'
    end
  end
  prepend cargo_mod
end

MRuby::Gem::Specification.new 'mrusty' do |spec|
  spec.license = 'MPL'
  spec.author = 'mrusty developers'
  spec.summary = 'mruby binding library'

  out_lib = libfile "#{build_dir}/#{cargo_build_type}/libmrusty"
  build.libmrusty = out_lib
  build.libmrusty_rlib = "#{build_dir}/#{cargo_build_type}/libmrusty.rlib"
  file out_lib => ["#{dir}/src/lib.rs", __FILE__] do |t|
    _pp 'CARGO', t.name
    cmd = "MRUBY_ROOT='#{MRUBY_ROOT}' CARGO_TARGET_DIR='#{build_dir}' cargo build --features set_mruby_path --lib"
    cmd << " --manifest-path='#{dir}/Cargo.toml'"
    cmd << ' --release' unless build.debug_enabled?
    cmd << ' -v'
    sh cmd
  end

  build.linker.libraries << 'mrusty'
  build.linker.library_paths << File.dirname(out_lib)

  file libfile("#{build.build_dir}/lib/libmruby") => out_lib

  add_dependency 'mruby-error', core: 'mruby-error'
end
