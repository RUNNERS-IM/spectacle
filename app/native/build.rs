fn main() {
    napi_build::setup();
    // The macOS tray menu (mac/menu.m), drawn with AppKit views that objc2 would make long-winded.
    if std::env::var("CARGO_CFG_TARGET_OS").as_deref() == Ok("macos") {
        println!("cargo:rerun-if-changed=mac/menu.m");
        cc::Build::new().file("mac/menu.m").flag("-fobjc-arc").flag("-fmodules").compile("split_menu");
        println!("cargo:rustc-link-lib=framework=AppKit");
    }
}
