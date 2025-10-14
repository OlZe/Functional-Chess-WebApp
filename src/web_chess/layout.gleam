pub fn determine_is_layout_sideways() -> Bool {
  let #(width, height) = get_window_size()
  let sidebar_width = get_sidebar_min_width()

  echo width - sidebar_width >= height
}

/// Registers a callback function on the window resize event.
@external(javascript, "./layout_ffi.mjs", "registerCallbackOnWindowResize")
pub fn register_callback_on_window_resize(cb: fn() -> Nil) -> Nil

/// Returns the `#(width, height)` of the window in pixels.
@external(javascript, "./layout_ffi.mjs", "getWindowSize")
fn get_window_size() -> #(Int, Int)

/// Returns the min-width of the sidebar in pixels.
/// 
/// Uses the css variable --layout-sidebar-min-width
@external(javascript, "./layout_ffi.mjs", "getSidebarMinWidth")
fn get_sidebar_min_width() -> Int
