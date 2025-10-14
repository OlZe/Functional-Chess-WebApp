import chess
import chess/coordinates as coords
import gleam/dict
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/set
import lustre
import lustre/attribute.{class, classes} as attr
import lustre/effect
import lustre/element.{type Element}
import lustre/element/html
import web_chess/internal/layout
import web_chess/internal/views/board
import web_chess/internal/views/license

pub fn main() -> Nil {
  let app = lustre.application(init:, update:, view:)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

type Model {
  Model(is_layout_sideways: Bool, game: board.Model)
}

fn init(_flags) {
  let model =
    Model(
      is_layout_sideways: layout.determine_is_layout_sideways(),
      game: board.NothingSelected(state: chess.new_game()),
    )

  let update_layout_on_resize =
    effect.from(fn(dispatch) {
      layout.register_callback_on_window_resize(fn() {
        dispatch(UserResizedWindow)
      })
    })

  #(model, update_layout_on_resize)
}

type Msg {
  UserResizedWindow
  UserClickedSquare(square: chess.Coordinate)
}

fn update(model model: Model, msg msg: Msg) -> #(Model, effect.Effect(Msg)) {
  let model = case msg {
    UserResizedWindow -> handle_user_resized_window(model:)
    UserClickedSquare(square:) -> handle_user_clicked_square(model:, square:)
  }

  #(model, effect.none())
}

fn handle_user_resized_window(model model: Model) -> Model {
  Model(..model, is_layout_sideways: layout.determine_is_layout_sideways())
}

fn handle_user_clicked_square(
  model model: Model,
  square square: chess.Coordinate,
) -> Model {
  case model.game.state |> chess.get_status {
    chess.GameEnded(_) -> model
    chess.GameOngoing(next_player: player) -> {
      case chess.get_figure(game: model.game.state, coord: square) {
        // Clicked friendly figure, select
        Some(#(_, figure_owner)) if figure_owner == player -> {
          let moves =
            chess.get_moves(model.game.state, square)
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
            game: board.FigureSelected(
              state: model.game.state,
              selected_figure: square,
              moves: moves,
            ),
          )
        }
        // Deselect
        _ ->
          Model(..model, game: board.NothingSelected(state: model.game.state))
      }
    }
  }
}

fn view(model model: Model) -> Element(Msg) {
  html.body(
    [
      class(
        "flex bg-background text-text font-sans h-screen w-screen overflow-x-hidden",
      ),
      classes([
        #("flex-row items-stretch", model.is_layout_sideways),
        #("flex-col items-stretch", !model.is_layout_sideways),
      ]),
    ],
    [
      // vertical spacer
      html.div([class("h-[calc(50vh-50vmin)] flex-none")], []),

      // Board container
      html.main(
        [
          classes([
            #("flex justify-center", True),
            #("flex-1", model.is_layout_sideways),
            #("h-[100vmin] min-h-[100vmin]", !model.is_layout_sideways),
          ]),
        ],
        [
          board.render(model: model.game, on_click: UserClickedSquare),
        ],
      ),

      // Sidebar
      html.aside(
        [
          classes([
            #("flex flex-col justify-between", True),
            #(
              "h-full w-[var(--layout-sidebar-min-width)] overflow-y-scroll",
              model.is_layout_sideways,
            ),
            #("w-full flex-1", !model.is_layout_sideways),
          ]),
        ],
        [
          html.div([], [
            html.p([], [html.text("Move1")]),
            html.p([], [html.text("Move2")]),
            html.p([], [html.text("Move3")]),
            html.p([], [html.text("Move4")]),
            html.p([], [html.text("Move5")]),
          ]),

          html.div([class("text-center")], [license.render()]),
        ],
      ),
    ],
  )
}
