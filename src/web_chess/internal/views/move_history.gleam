import chess
import chess/algebraic_notation
import gleam/int
import gleam/list
import lustre/attribute.{class} as attr
import lustre/element.{type Element}
import lustre/element/html

pub fn render(game game: chess.GameState) -> Element(a) {
  let history = chess.get_history(game:)

  // Map moves to text descriptions
  let history =
    history
    |> list.index_map(fn(move_and_player, index) {
      let #(move, player) = move_and_player
      let assert Ok(game) = chess.get_past_position(game:, move_number: index)
      let assert Ok(description) = algebraic_notation.describe(game:, move:)
      #(description, player)
    })

  // We need the history list to always be a pair of a white + black move
  // If the first move is a black move, prepend an empty move for white
  let history = case history {
    [] -> []
    [#(_, chess.White), ..] -> history
    [#(_, chess.Black), ..] -> [#("", chess.White), ..history]
  }

  // Now the history is properly padded and ready to go through in pairs
  // such that history contains tuples of (white_move, black_move)
  let history =
    history
    |> list.sized_chunk(2)
    |> list.map(fn(full_move) {
      case full_move {
        [#(white_move, chess.White), #(black_move, chess.Black)] -> #(
          white_move,
          black_move,
        )
        [#(white_move, chess.White)] -> #(white_move, "")
        _ -> panic as "unreachable"
      }
    })

  // Add move numbers
  let history =
    history
    |> list.index_map(fn(full_move, index) {
      let #(white_move, black_move) = full_move
      let move_number = index + 1
      #(move_number, white_move, black_move)
    })

  // Render
  html.div(
    [
      class(
        "grid [grid-template-columns:1.5rem_4.5rem_4.5rem] justify-center gap-y-1 gap-x-0.5 pt-1 pb-0",
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
