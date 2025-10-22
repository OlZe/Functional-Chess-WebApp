import chess
import chess/algebraic_notation as chess_san
import chess/coordinates as coords
import gleam/dict
import gleam/list
import gleam/option.{Some}
import gleam/result
import gleam/set

pub type Model {
  NothingSelected(state: chess.GameState, move_history: List(ArchivedMove))
  FigureSelected(
    state: chess.GameState,
    move_history: List(ArchivedMove),
    selected_figure: chess.Coordinate,
    moves: dict.Dict(chess.Coordinate, chess.AvailableMove),
  )
}

pub type ArchivedMove {
  FullMove(white: String, black: String)
  HalfMove(white: String)
}

pub fn handle_clicked_square(
  model model: Model,
  square square: chess.Coordinate,
) -> Model {
  case model.state |> chess.get_status {
    chess.GameEnded(_) -> model
    chess.GameOngoing(_) -> {
      case model {
        FigureSelected(state:, selected_figure: from, moves:, move_history:) -> {
          let clicked_move = dict.get(moves, square)
          case clicked_move {
            Ok(move) -> try_do_move(model.state, move_history, from, move)
            Error(_) -> try_select(state, move_history, square)
          }
        }
        NothingSelected(state:, move_history:) ->
          try_select(state, move_history, square)
      }
    }
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
      // Update move history
      let assert Ok(move_description) = chess_san.describe(game:, move:)
      let new_history = case history {
        [] -> [HalfMove(move_description)]
        [FullMove(..), ..] -> [HalfMove(move_description), ..history]
        [HalfMove(white_move), ..rest] -> [
          FullMove(white_move, move_description),
          ..rest
        ]
      }

      NothingSelected(state: new_state, move_history: new_history)
    }
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

      FigureSelected(
        state: game,
        selected_figure: square,
        moves:,
        move_history: history,
      )
    }
    // Deselect
    _ -> NothingSelected(state: game, move_history: history)
  }
}
