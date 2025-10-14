export function registerCallbackOnWindowResize(cb) {
  window.addEventListener('resize', () => cb())
}

export function getWindowSize() {
  return [
    window.innerWidth,
    window.innerHeight
  ]
}

/**
 * Calculates the min-width of the sidebar, based on the css variable --layout-sidebar-min-width
 * @returns The min-width of the sidebar in pixels
 */
export function getSidebarMinWidth() {
  const pxInOneRem = parseFloat(
    getComputedStyle(document.documentElement).fontSize,
  );
  // "15rem"
  const sidebarWidthString = getComputedStyle(
    document.documentElement,
  ).getPropertyValue("--layout-sidebar-min-width");

  if (!sidebarWidthString || sidebarWidthString.indexOf("rem") === -1) {
    throw new Error(
      "CSS variable --layout-sidebar-min-width missing or invalid format.",
    );
  }

  // "15rem" => 15
  const sidebarWidthRem = parseFloat(
    sidebarWidthString.slice(0, sidebarWidthString.indexOf("rem")),
  );
  const sideBarWidthPx = sidebarWidthRem * pxInOneRem;
  return sideBarWidthPx;
}