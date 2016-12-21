// mrusty. mruby safe bindings for Rust
// Copyright (C) 2016  Dragoș Tiselice
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

//! # mrusty. mruby safe bindings for Rust
//!
//! mrusty lets you:
//!
//! * run Ruby 1.9 files with a very restricted API (without having to install Ruby)
//! * reflect Rust `struct`s and `enum`s in mruby and run them
//!
//! It does all this in a safely neat way, while also bringing spec testing and a
//! REPL to the table.

#[cfg(feature = "gnu-readline")]
extern crate rl_sys;

mod macros;
mod mruby;
mod mruby_ffi;
mod read_line;
mod repl;
mod spec;

/// Not meant to be called directly.
#[doc(hidden)]
pub use mruby_ffi::MrValue;
/// Not meant to be called directly.
#[doc(hidden)]
pub use mruby_ffi::mrb_get_args;

pub use mruby::Class;
pub use mruby::ClassLike;
pub use mruby::Module;
pub use mruby::Mruby;
pub use mruby::MrubyError;
pub use mruby::MrubyFile;
pub use mruby::MrubyImpl;
pub use mruby::MrubyType;
pub use mruby::Value;
pub use read_line::ReadLine;
pub use repl::Repl;
pub use spec::Spec;

#[cfg(feature = "gnu-readline")]
pub use read_line::GnuReadLine;

#[allow(dead_code)]
#[no_mangle]
pub unsafe extern fn mrb_mrusty_gem_init(mrb: *const mruby_ffi::MrState) {
  // initialize mrusty for current mrb_state
  std::mem::forget(Mruby::new_with_state(mrb, false));
}

#[allow(dead_code)]
#[no_mangle]
pub unsafe extern fn mrb_mrusty_gem_final(mrb: *const mruby_ffi::MrState) {
  // release mrusty resources
  std::mem::transmute::<_, MrubyType>(mruby_ffi::mrb_ext_get_ud(mrb));
}

#[macro_export]
macro_rules! mrbgem_init_func {
  ($name:ident, $( $rest:tt )* ) => {
    fn concat_idents!(mrb_, $name, _gem_init)(mrb: *const $crate::mruby_ffi:MrState) {
      let mruby: $crate::MrubyType = unsafe { std::mem::transmute($crate::mruby_ffi::mrb_ext_get_ud(mrb)) };
      fn init_fn(mruby) {
        $( $rest )*
      }
      std::mem::forget(mruby);
    }
  }
}

#[macro_export]
macro_rules! mrbgem_final_func {
  ($name:ident, $( $rest:tt )* ) => {
    fn concat_idents!(mrb_, $name, _gem_init)(mrb: *const $crate::mruby_ffi:MrState) {
      let mruby: $crate::MrubyType = unsafe { std::mem::transmute($crate::mruby_ffi::mrb_ext_get_ud(mrb)) };
      fn init_fn(mruby) {
        $( $rest )*
      }
      init_fn(mruby);
      std::mem::forget(mruby);
    }
  }
}
