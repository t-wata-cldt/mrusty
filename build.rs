// mrusty. mruby safe bindings for Rust
// Copyright (C) 2016  Dragoș Tiselice
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

extern crate git2;
extern crate gcc;

use std::env;
use std::io::Read;
use std::fs::File;
use std::path::Path;
use std::process::Command;

use git2::{Repository, Oid};

fn main() {
  let lib_search_path = "build/host/lib";
  let lib_name = "libmruby.a";
  let mruby_root = if cfg!(feature = "set_mruby_path") {
    env::var("MRUBY_ROOT").unwrap()
  } else {
    let repo_url = "https://github.com/mruby/mruby.git";
    let current_dir = env::current_dir().unwrap();
    let out_path = format!("{}/mruby", env::var("OUT_DIR").unwrap());
    let root = out_path.clone();

    let mut commit_id = String::new();
    File::open(".mruby_version").unwrap().read_to_string(&mut commit_id).unwrap();
    let commit_id = Oid::from_str(commit_id.trim()).unwrap();

    let repo = if Path::new(&out_path).exists() {
      let r = Repository::open(&out_path).unwrap();
      r.find_remote("origin").unwrap().fetch(&["master"], None, None).unwrap();
      r
    } else {
      Repository::clone(repo_url, &out_path).unwrap()
    };
    repo.checkout_tree(&repo.find_commit(commit_id).unwrap().into_object(), None).unwrap();

    Command::new("./minirake")
      .current_dir(&out_path)
      .arg(&format!("{}/{}/{}", root, lib_search_path, lib_name))
      .env("MRUBY_CONFIG", format!("{}/.mruby_config.rb", current_dir.to_str().unwrap()))
      .status().unwrap();
    root
  };

  println!("cargo:rustc-link-lib=static={}", "mruby");
  println!("cargo:rustc-link-search=native={}/{}", mruby_root, lib_search_path);
  gcc::Config::new().file("src/mrb_ext.c").include(format!("{}/include", mruby_root)).compile("libmrbe.a");
}
