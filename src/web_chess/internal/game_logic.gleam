import chess
import chess/algebraic_notation as chess_san
import chess/coordinates as coords
import gleam/bool
import gleam/dict
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/set

pub type Model {
  Model(
    /// The latest game state
    root_state: chess.GameState,
    /// The currently selected game state as according to `selected_move_history_index`
    state: chess.GameState,
    /// The index of the selected board position in the `move_history`
    selected_move_history_index: Int,
    /// The entire move history from the beginning of the game up until `root_state`
    move_history: List(ArchivedMove),
    /// Whether the user selected a figure
    figure_selection_state: FigureSelectionState,
  )
}

pub type FigureSelectionState {
  NothingSelected
  FigureSelected(
    selected_figure: chess.Coordinate,
    moves: dict.Dict(chess.Coordinate, chess.AvailableMove),
  )
  DraggingFigure(
    selected_figure: chess.Coordinate,
    moves: dict.Dict(chess.Coordinate, chess.AvailableMove),
    dragging_over: Option(chess.Coordinate),
  )
}

pub type ArchivedMove {
  FullMove(white: ArchivedHalfMove, black: ArchivedHalfMove)
  HalfMove(white: ArchivedHalfMove)
}

pub type ArchivedHalfMove {
  ArchivedHalfMove(san_description: String, move: chess.Move, index: Int)
}

pub fn new() -> Model {
  let state = chess.new_game()
  Model(
    root_state: state,
    state: state,
    selected_move_history_index: 0,
    move_history: [],
    figure_selection_state: NothingSelected,
  )
}

pub fn handle_select_past_position(
  model model: Model,
  index index: Int,
) -> Model {
  let assert Ok(selected_state) =
    model.root_state |> chess.get_past_position(index)
  Model(..model, state: selected_state, selected_move_history_index: index)
}

pub fn handle_clicked_square(
  model model: Model,
  square square: chess.Coordinate,
) -> Model {
  case model.state |> chess.get_status {
    chess.GameEnded(_) -> model
    chess.GameOngoing(_) -> {
      case model.figure_selection_state {
        // If a figure was already selected, do a move, switch focus, or deselect
        FigureSelected(selected_figure: from, moves:) -> {
          let clicked_move = dict.get(moves, square)
          case clicked_move {
            Ok(move) -> try_do_move(model, from, move)
            Error(_) -> try_select(model, square)
          }
        }
        // If nothing was selected, try selecting
        NothingSelected -> try_select(model, square)
        // Shouldn't happen, but if it does, then just deselect
        DraggingFigure(..) ->
          Model(..model, figure_selection_state: NothingSelected)
      }
    }
  }
}

/// Tries to drag a figure and return the new model including its moves.
/// 
/// Panics if the game is not ongoing.
pub fn handle_drag_start(
  model model: Model,
  square square: chess.Coordinate,
) -> Model {
  let assert chess.GameOngoing(next_player: player) =
    chess.get_status(model.state)

  case chess.get_figure(model.state, square) {
    // Dragging friendly figure, select
    Some(#(_, figure_owner)) if figure_owner == player -> {
      // Get moves and map to coordinate
      let moves =
        chess.get_moves(model.state, square)
        |> result.lazy_unwrap(fn() { set.new() })
        |> set.to_list()
        |> list.map(fn(move) {
          case move {
            chess.EnPassantAvailable(to:) -> #(to, move)
            chess.PawnPromotionAvailable(to:) -> #(to, move)
            chess.StdMoveAvailable(to:) -> #(to, move)
            chess.LongCastleAvailable ->
              case player {
                chess.White -> #(coords.c1, move)
                chess.Black -> #(coords.c8, move)
              }
            chess.ShortCastleAvailable ->
              case player {
                chess.White -> #(coords.g1, move)
                chess.Black -> #(coords.g8, move)
              }
          }
        })
        |> dict.from_list()

      Model(
        ..model,
        figure_selection_state: DraggingFigure(
          selected_figure: square,
          moves:,
          dragging_over: None,
        ),
      )
    }
    // Deselect
    _ -> {
      Model(..model, figure_selection_state: NothingSelected)
    }
  }
}

pub fn handle_drag_enter_square(
  model model: Model,
  over over: chess.Coordinate,
) -> Model {
  case model.figure_selection_state {
    DraggingFigure(moves:, dragging_over: _, selected_figure:) ->
      Model(
        ..model,
        figure_selection_state: DraggingFigure(
          selected_figure:,
          moves:,
          dragging_over: Some(over),
        ),
      )
    // If not in valid dragging state, do nothing
    _ -> model
  }
}

pub fn handle_drag_drop_on_square(model model: Model) -> Model {
  case model.figure_selection_state {
    DraggingFigure(moves:, dragging_over:, selected_figure:) ->
      case dragging_over {
        // If the drop location is outside the board, then deselect
        None -> Model(..model, figure_selection_state: NothingSelected)
        Some(dragging_over) -> {
          // If dropping on selected figure, then stop dragging but keep it selected
          use <- bool.lazy_guard(
            when: dragging_over == selected_figure,
            return: fn() {
              Model(
                ..model,
                figure_selection_state: FigureSelected(selected_figure:, moves:),
              )
            },
          )

          let move = dict.get(moves, dragging_over)
          case move {
            // If drop location is not a move, then deselect
            Error(_) -> Model(..model, figure_selection_state: NothingSelected)
            // If drop location is a move, then do the move
            Ok(move) -> try_do_move(model:, from: selected_figure, move:)
          }
        }
      }
    // If not in a valid dragging state, do nothing
    _ -> model
  }
}

pub fn handle_drag_end(model model: Model) {
  case model.figure_selection_state {
    DraggingFigure(selected_figure:, moves:, dragging_over: _) ->
      Model(
        ..model,
        figure_selection_state: FigureSelected(selected_figure:, moves:),
      )
    _ -> model
  }
}

fn try_do_move(
  model model: Model,
  from from: chess.Coordinate,
  move move: chess.AvailableMove,
) -> Model {
  // Map from chess.AvailableMove to chess.Move
  let move = case move {
    chess.EnPassantAvailable(to:) -> chess.EnPassant(from:, to:)
    chess.LongCastleAvailable -> chess.LongCastle
    chess.PawnPromotionAvailable(to:) ->
      chess.PawnPromotion(from:, to:, new_figure: chess.Queen)
    chess.ShortCastleAvailable -> chess.ShortCastle
    chess.StdMoveAvailable(to:) -> chess.StdMove(from:, to:)
  }

  // Execute move
  let assert Ok(new_state) = chess.player_move(game: model.state, move:)

  let #(new_history, new_history_index) = {
    let assert Ok(san) =
      chess_san.describe(
        move:,
        before_state: model.state,
        after_state: new_state,
      )
    model.move_history
    |> take_until_move_history(model.selected_move_history_index)
    |> append_move_history(san:, move:)
  }

  Model(
    root_state: new_state,
    state: new_state,
    selected_move_history_index: new_history_index,
    move_history: new_history,
    figure_selection_state: NothingSelected,
  )
}

/// Append to the move history.
/// 
/// Returns the new move history and the newly inserted index.
fn append_move_history(
  history history: List(ArchivedMove),
  san san: String,
  move move: chess.Move,
) -> #(List(ArchivedMove), Int) {
  case history {
    // If empty, create a new half move
    [] -> #([HalfMove(white: ArchivedHalfMove(san, move, 1))], 1)
    // If newest entry is full move, create a new half move
    [FullMove(..) as prev_move, ..] -> #(
      [
        HalfMove(white: ArchivedHalfMove(
          san_description: san,
          move:,
          index: prev_move.black.index + 1,
        )),
        ..history
      ],
      prev_move.black.index + 1,
    )
    // If newest entry is a half move, then make it full
    [HalfMove(white_move), ..rest] -> #(
      [
        FullMove(
          white: white_move,
          black: ArchivedHalfMove(
            san_description: san,
            move:,
            index: white_move.index + 1,
          ),
        ),
        ..rest
      ],
      white_move.index + 1,
    )
  }
}

/// Returns the part from the move history which goes from 0 to index (inclusive)
fn take_until_move_history(
  history history: List(ArchivedMove),
  index index: Int,
) -> List(ArchivedMove) {
  // Move History is organized like this:
  // [
  //    (white: 5)
  //    (white: 3, black: 4)
  //    (white: 1, black: 2)
  // ]

  use <- bool.guard(when: index == 0, return: [])

  case history {
    [] -> panic as "index too large"
    [HalfMove(move), ..rest] if move.index == index -> [HalfMove(move), ..rest]
    [HalfMove(..), ..rest] -> take_until_move_history(rest, index)
    [FullMove(white:, black:), ..rest] if black.index == index -> [
      FullMove(white:, black:),
      ..rest
    ]
    [FullMove(white:, black: _), ..rest] if white.index == index -> [
      HalfMove(white),
      ..rest
    ]
    [FullMove(..), ..rest] -> take_until_move_history(rest, index)
  }
}

/// Tries to select a figure and return the new model including its moves.
/// 
/// Deselects if trying to select an empty square or a figure that belongs to the enemy.
/// 
/// Panics if the game is not ongoing.
fn try_select(model model: Model, square square: chess.Coordinate) -> Model {
  let assert chess.GameOngoing(next_player: player) =
    chess.get_status(game: model.state)

  case chess.get_figure(model.state, square) {
    // Clicked friendly figure, select
    Some(#(_, figure_owner)) if figure_owner == player -> {
      // Get moves and map to coordinate
      let moves =
        chess.get_moves(game: model.state, from: square)
        |> result.lazy_unwrap(fn() { set.new() })
        |> set.to_list()
        |> list.map(fn(move) {
          case move {
            chess.EnPassantAvailable(to:) -> #(to, move)
            chess.PawnPromotionAvailable(to:) -> #(to, move)
            chess.StdMoveAvailable(to:) -> #(to, move)
            chess.LongCastleAvailable ->
              case player {
                chess.White -> #(coords.c1, move)
                chess.Black -> #(coords.c8, move)
              }
            chess.ShortCastleAvailable ->
              case player {
                chess.White -> #(coords.g1, move)
                chess.Black -> #(coords.g8, move)
              }
          }
        })
        |> dict.from_list()

      Model(
        ..model,
        figure_selection_state: FigureSelected(moves:, selected_figure: square),
      )
    }
    // Deselect
    _ -> Model(..model, figure_selection_state: NothingSelected)
  }
}
