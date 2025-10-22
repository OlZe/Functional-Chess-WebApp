import chess
import gleam/dict
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/set
import lustre/attribute.{class} as attr
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import web_chess/internal/game_logic as logic

pub fn render(
  model model: logic.Model,
  on_square_click on_click: fn(chess.Coordinate) -> msg,
  on_square_drag_start on_drag_start: fn(chess.Coordinate) -> msg,
  on_square_drag_enter on_drag_enter: fn(chess.Coordinate) -> msg,
  on_square_drag_drop on_drag_drop: fn() -> msg,
  on_drag_over on_drag_over: fn() -> msg,
) -> Element(msg) {
  let #(highlighted_squares, move_squares) = case model {
    logic.NothingSelected(..) -> #(set.new(), set.new())
    logic.FigureSelected(selected_figure:, moves:, ..) -> {
      #(
        [selected_figure] |> set.from_list(),
        moves |> dict.keys() |> set.from_list(),
      )
    }
    logic.DraggingFigure(selected_figure:, moves:, dragging_over:, ..) -> {
      #(
        [Some(selected_figure), dragging_over]
          |> option.values()
          |> set.from_list(),
        moves |> dict.keys() |> set.from_list(),
      )
    }
  }

  let moving_player = case model.state |> chess.get_status() {
    chess.GameOngoing(next_player:) -> Some(next_player)
    chess.GameEnded(_) -> None
  }

  html.div(
    [
      class("grid h-[100vmin] w-[100vmin] grid-cols-8 grid-rows-8 select-none"),
    ],
    list.map(coordinates(), fn(coord) {
      render_square(
        colour: coordinate_colour(coord:),
        figure: chess.get_figure(game: model.state, coord:),
        is_highlighted: highlighted_squares |> set.contains(coord),
        is_move: move_squares |> set.contains(coord),
        on_click: fn() { on_click(coord) },
        on_drag_start: fn() { on_drag_start(coord) },
        on_drag_enter: fn() { on_drag_enter(coord) },
        on_drag_drop: on_drag_drop,
        on_drag_over: on_drag_over,
        moving_player:,
      )
    }),
  )
}

fn render_square(
  colour colour: CoordinateColour,
  figure figure: Option(#(chess.Figure, chess.Player)),
  moving_player moving_player: Option(chess.Player),
  is_highlighted is_highlighted: Bool,
  is_move is_move: Bool,
  on_click on_click: fn() -> msg,
  on_drag_start on_drag_start: fn() -> msg,
  on_drag_enter on_drag_enter: fn() -> msg,
  on_drag_drop on_drag_drop: fn() -> msg,
  on_drag_over on_drag_over: fn() -> msg,
) -> Element(msg) {
  let figure = case figure {
    None -> None
    Some(figure) -> Some(render_figure(figure:, on_drag_start:, moving_player:))
  }
  let move_indicator = case is_move {
    False -> None
    True -> Some(render_move_indicator(is_figure: figure != None))
  }

  html.div(
    [
      attr.classes([
        #("relative", True),
        #("bg-[var(--color-square-dark)]", colour == Dark && !is_highlighted),
        #("bg-[var(--color-square-light)]", colour == Light && !is_highlighted),
        #(
          "bg-[var(--color-square-dark-highlighted)]",
          colour == Dark && is_highlighted,
        ),
        #(
          "bg-[var(--color-square-light-highlighted)]",
          colour == Light && is_highlighted,
        ),
      ]),
      event.on_mouse_down(on_click()),
      event.on("dragover", decode.success(on_drag_over()))
        |> event.prevent_default(),
      event.on("drop", decode.success(on_drag_drop()))
        |> event.prevent_default(),
      event.on("dragenter", decode.success(on_drag_enter())),
    ],
    [figure, move_indicator] |> option.values(),
  )
}

fn render_move_indicator(is_figure is_figure: Bool) -> Element(a) {
  case is_figure {
    True ->
      html.img([
        class("absolute inset-0 h-full w-full"),
        attr.src("./indicators/capture.svg"),
        attr.alt("This figure can be captured"),
        attr.draggable(False),
      ])
    False ->
      html.img([
        class("absolute inset-0 h-full w-full"),
        attr.src("./indicators/move.svg"),
        attr.alt("Can move to here"),
        attr.draggable(False),
      ])
  }
}

fn render_figure(
  figure figure: #(chess.Figure, chess.Player),
  moving_player moving_player: Option(chess.Player),
  on_drag_start on_drag_start: fn() -> msg,
) -> Element(msg) {
  let #(href, alt) = case figure {
    #(chess.Pawn, chess.White) -> #("./figures/pawn_white.svg", "White Bishop")
    #(chess.Knight, chess.White) -> #(
      "./figures/knight_white.svg",
      "White Knight",
    )
    #(chess.Bishop, chess.White) -> #(
      "./figures/bishop_white.svg",
      "White Bishop",
    )
    #(chess.Rook, chess.White) -> #("./figures/rook_white.svg", "White Rook")
    #(chess.Queen, chess.White) -> #("./figures/queen_white.svg", "White Queen")
    #(chess.King, chess.White) -> #("./figures/king_white.svg", "White King")
    #(chess.Pawn, chess.Black) -> #("./figures/pawn_black.svg", "Black Pawn")
    #(chess.Knight, chess.Black) -> #(
      "./figures/knight_black.svg",
      "Black Knight",
    )
    #(chess.Bishop, chess.Black) -> #(
      "./figures/bishop_black.svg",
      "Black Bishop",
    )
    #(chess.Rook, chess.Black) -> #("./figures/rook_black.svg", "Black Rook")
    #(chess.Queen, chess.Black) -> #("./figures/queen_black.svg", "Black Queen")
    #(chess.King, chess.Black) -> #("./figures/king_black.svg", "Black King")
  }

  let figure_owner = figure.1
  html.img([
    class("absolute inset-0 h-full w-full"),
    attr.src(href),
    attr.alt(alt),
    attr.draggable(Some(figure_owner) == moving_player),
    event.on("dragstart", decode.success(on_drag_start())),
  ])
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
