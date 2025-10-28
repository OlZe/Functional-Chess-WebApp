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
    state: chess.GameState,
    move_history: List(ArchivedMove),
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
  ArchivedHalfMove(san_description: String, move: chess.Move)
}

pub fn new() -> Model {
  Model(
    state: chess.new_game(),
    move_history: [],
    figure_selection_state: NothingSelected,
  )
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
            Ok(move) -> try_do_move(model.state, model.move_history, from, move)
            Error(_) -> try_select(model.state, model.move_history, square)
          }
        }
        // If nothing was selected, try selecting
        NothingSelected -> try_select(model.state, model.move_history, square)
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
            Ok(move) ->
              try_do_move(
                game: model.state,
                history: model.move_history,
                from: selected_figure,
                move:,
              )
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
  game game: chess.GameState,
  history history: List(ArchivedMove),
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

  // Execute move and return
  let new_state = chess.player_move(game:, move:)
  case new_state {
    Error(err) -> {
      echo err
      panic as "error executing move"
    }
    Ok(new_state) -> {
      let new_history = {
        let assert Ok(san) = chess_san.describe(game:, move:)
        let archived_move = ArchivedHalfMove(san, move)
        append_move_history(history:, new_move: archived_move)
      }
      Model(
        state: new_state,
        move_history: new_history,
        figure_selection_state: NothingSelected,
      )
    }
  }
}

fn append_move_history(
  history history: List(ArchivedMove),
  new_move new_move: ArchivedHalfMove,
) -> List(ArchivedMove) {
  case history {
    // If empty, create a new half move
    [] -> [HalfMove(white: new_move)]
    // If newest entry is full move, create a new half move
    [FullMove(..), ..] -> [HalfMove(white: new_move), ..history]
    // If newest entry is a half move, then make it full
    [HalfMove(white_move), ..rest] -> [
      FullMove(white: white_move, black: new_move),
      ..rest
    ]
  }
}

/// Tries to select a figure and return the new model including its moves.
/// 
/// Deselects if trying to select an empty square or a figure that belongs to the enemy.
/// 
/// Panics if the game is not ongoing.
fn try_select(
  game game: chess.GameState,
  history history: List(ArchivedMove),
  square square: chess.Coordinate,
) -> Model {
  let assert chess.GameOngoing(next_player: player) = chess.get_status(game:)

  case chess.get_figure(game, square) {
    // Clicked friendly figure, select
    Some(#(_, figure_owner)) if figure_owner == player -> {
      // Get moves and map to coordinate
      let moves =
        chess.get_moves(game:, from: square)
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
        state: game,
        move_history: history,
        figure_selection_state: FigureSelected(moves:, selected_figure: square),
      )
    }
    // Deselect
    _ ->
      Model(
        state: game,
        move_history: history,
        figure_selection_state: NothingSelected,
      )
  }
}
