import gleam/int
import gleam/list
import lustre/attribute.{class}
import lustre/element.{type Element}
import lustre/element/html
import web_chess/internal/game_logic as logic

pub fn render(history history: List(logic.ArchivedMove)) -> Element(a) {
  // Map to pairs of strings with move number
  let history =
    history
    |> list.reverse()
    |> list.index_map(fn(move, index) {
      let number = index + 1
      case move {
        logic.FullMove(white:, black:) -> #(
          number,
          white.san_description,
          black.san_description,
        )
        logic.HalfMove(white:) -> #(number, white.san_description, "")
      }
    })

  html.div(
    [
      class(
        "grid [grid-template-columns:1.5rem_4.5rem_4.5rem] justify-center gap-y-1 gap-x-1.5 pt-2 pb-1",
      ),
    ],
    history
      |> list.flat_map(fn(full_move) {
        let #(number, white_move, black_move) = full_move
        [
          html.p([], [html.text(int.to_string(number) <> ".")]),
          html.p([class("font-bold")], [html.text(white_move)]),
          html.p([class("font-bold")], [html.text(black_move)]),
        ]
      }),
  )
}
