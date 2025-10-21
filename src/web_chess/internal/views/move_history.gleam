import chess
import chess/algebraic_notation
import gleam/int
import gleam/list
import lustre/attribute.{class} as attr
import lustre/element.{type Element}
import lustre/element/html
import web_chess/internal/views/board

pub fn render(history history: List(board.ArchivedMove)) -> Element(a) {
  // Map to pairs of strings with move number
  let history =
    history
    |> list.reverse()
    |> list.index_map(fn(move, index) {
      let number = index + 1
      case move {
        board.FullMove(white:, black:) -> #(number, white, black)
        board.HalfMove(white:) -> #(number, white, "")
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
