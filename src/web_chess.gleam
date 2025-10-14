import chess
import gleam/dict
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre
import lustre/attribute.{class} as attr
import lustre/element.{type Element}
import lustre/element/html

pub fn main() -> Nil {
  let app = lustre.simple(init:, update:, view:)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

type Model {
  Model(game: chess.GameState)
}

fn init(_flags) {
  Model(game: chess.new_game())
}

type Msg

fn update(model model: Model, msg _msg: Msg) -> Model {
  model
}

fn view(model model: Model) -> Element(Msg) {
  html.body(
    [
      class("bg-background text-text font-sans min-w-screen min-h-screen"),
    ],
    [
      html.div([class("flex flex-row flex-wrap")], [
        // todo: vertical spacer
        // Board
        render_board(model:),

        // Sidebar
        html.aside([class("w-[var(--layout-sidebar-min-width)]")], [
          html.div([], [
            html.p([], [html.text("Move1")]),
            html.p([], [html.text("Move2")]),
            html.p([], [html.text("Move3")]),
            html.p([], [html.text("Move4")]),
            html.p([], [html.text("Move5")]),
          ]),
        ]),
      ]),
    ],
  )
}

fn render_board(model model: Model) -> Element(Msg) {
  html.div(
    [
      class("grid h-[100vmin] w-[100vmin] grid-cols-8 grid-rows-8 select-none"),
    ],
    list.map(coordinates(), fn(coord) {
      render_square(
        colour: coordinate_colour(coord:),
        figure: model.game |> chess.get_board |> board_get(coord:),
      )
    }),
  )
}

fn render_square(
  colour colour: CoordinateColour,
  figure figure: Option(#(chess.Figure, chess.Player)),
) -> Element(Msg) {
  html.div(
    [
      attr.classes([
        #("bg-[var(--color-square-dark)]", colour == Dark),
        #("bg-[var(--color-square-light)]", colour == Light),
      ]),
    ],
    case figure {
      None -> []
      Some(figure) -> [figure_to_img(figure)]
    },
  )
}

fn figure_to_img(figure figure: #(chess.Figure, chess.Player)) -> Element(Msg) {
  let #(href, alt) = case figure {
    #(chess.Pawn, chess.White) -> #("/figures/pawn_white.svg", "White Bishop")
    #(chess.Knight, chess.White) -> #(
      "/figures/knight_white.svg",
      "White Knight",
    )
    #(chess.Bishop, chess.White) -> #(
      "/figures/bishop_white.svg",
      "White Bishop",
    )
    #(chess.Rook, chess.White) -> #("/figures/rook_white.svg", "White Rook")
    #(chess.Queen, chess.White) -> #("/figures/queen_white.svg", "White Queen")
    #(chess.King, chess.White) -> #("/figures/king_white.svg", "White King")
    #(chess.Pawn, chess.Black) -> #("/figures/pawn_black.svg", "Black Pawn")
    #(chess.Knight, chess.Black) -> #(
      "/figures/knight_black.svg",
      "Black Knight",
    )
    #(chess.Bishop, chess.Black) -> #(
      "/figures/bishop_black.svg",
      "Black Bishop",
    )
    #(chess.Rook, chess.Black) -> #("/figures/rook_black.svg", "Black Rook")
    #(chess.Queen, chess.Black) -> #("/figures/queen_black.svg", "Black Queen")
    #(chess.King, chess.Black) -> #("/figures/king_black.svg", "Black King")
  }

  html.img([class("h-full w-full"), attr.src(href), attr.alt(alt)])
}

fn board_get(
  board board: chess.Board,
  coord coord: chess.Coordinate,
) -> Option(#(chess.Figure, chess.Player)) {
  case board {
    chess.Board(white_king:, ..) if white_king == coord ->
      Some(#(chess.King, chess.White))
    chess.Board(black_king:, ..) if black_king == coord ->
      Some(#(chess.King, chess.Black))
    chess.Board(other_figures:, ..) ->
      other_figures |> dict.get(coord) |> option.from_result
  }
}

type CoordinateColour {
  Light
  Dark
}

fn coordinate_colour(coord coord: chess.Coordinate) -> CoordinateColour {
  let file_index = case coord.file {
    chess.FileA -> 0
    chess.FileB -> 1
    chess.FileC -> 2
    chess.FileD -> 3
    chess.FileE -> 4
    chess.FileF -> 5
    chess.FileG -> 6
    chess.FileH -> 7
  }
  let row_index = case coord.row {
    chess.Row1 -> 0
    chess.Row2 -> 1
    chess.Row3 -> 2
    chess.Row4 -> 3
    chess.Row5 -> 4
    chess.Row6 -> 5
    chess.Row7 -> 6
    chess.Row8 -> 7
  }
  case { file_index + row_index } % 2 {
    0 -> Dark
    1 -> Light
    _ -> panic
  }
}

/// Returns a list of all coordinates in the html grid rendering order:
/// 
/// Coordinates on board are:
/// ```
/// A8 B8 C8 ...
/// A7 B7 C7 ...
/// ...
/// ```
///
/// Returned order from top-left to bottom-right, row-wise:
/// 
/// `[A8, B8, C8, ..., A7, B7, C7, ...]`
fn coordinates() -> List(chess.Coordinate) {
  let files = [
    chess.FileA,
    chess.FileB,
    chess.FileC,
    chess.FileD,
    chess.FileE,
    chess.FileF,
    chess.FileG,
    chess.FileH,
  ]

  let rows = [
    chess.Row8,
    chess.Row7,
    chess.Row6,
    chess.Row5,
    chess.Row4,
    chess.Row3,
    chess.Row2,
    chess.Row1,
  ]

  rows
  |> list.flat_map(fn(row) {
    files
    |> list.map(fn(file) { chess.Coordinate(file, row) })
  })
}
