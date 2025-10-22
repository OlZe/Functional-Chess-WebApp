import chess
import lustre
import lustre/attribute.{class, classes}
import lustre/effect
import lustre/element.{type Element}
import lustre/element/html
import web_chess/internal/game_logic
import web_chess/internal/layout
import web_chess/internal/views/board
import web_chess/internal/views/license
import web_chess/internal/views/move_history

pub fn main() -> Nil {
  let app = lustre.application(init:, update:, view:)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

type Model {
  Model(is_layout_sideways: Bool, game: game_logic.Model)
}

fn init(_flags) {
  let model =
    Model(
      is_layout_sideways: layout.determine_is_layout_sideways(),
      game: game_logic.NothingSelected(
        state: chess.new_game(),
        move_history: [],
      ),
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
    UserClickedSquare(square:) ->
      Model(
        ..model,
        game: game_logic.handle_clicked_square(model: model.game, square:),
      )
  }

  #(model, effect.none())
}

fn handle_user_resized_window(model model: Model) -> Model {
  Model(..model, is_layout_sideways: layout.determine_is_layout_sideways())
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
          move_history.render(model.game.move_history),
          html.div([class("text-center")], [license.render()]),
        ],
      ),
    ],
  )
}
