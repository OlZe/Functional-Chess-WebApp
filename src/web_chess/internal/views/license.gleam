import lustre/attribute.{class} as attr
import lustre/element.{type Element}
import lustre/element/html

pub fn render() -> Element(a) {
  html.p([class("m-1 text-xs")], [
    html.a(
      [
        class("whitespace-nowrap"),
        attr.href(
          "https://commons.wikimedia.org/wiki/Category:SVG_chess_pieces",
        ),
        attr.target("_blank"),
      ],
      [html.text("Chess icons")],
    ),
    html.text(" by "),
    html.a(
      [
        attr.href("https://commons.wikimedia.org/wiki/User:Cburnett"),
        attr.target("_blank"),
      ],
      [html.text("Cburnett")],
    ),
    html.text(" "),
    html.a(
      [
        class("whitespace-nowrap"),
        attr.href("https://creativecommons.org/licenses/by-sa/3.0/deed.en"),
        attr.target("_blank"),
      ],
      [html.text("CC BY-SA 3.0")],
    ),
  ])
}
