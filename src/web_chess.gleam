import chess
import lustre
import lustre/attribute
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
  html.p([attribute.class("text-center")], [html.text("hello world")])
}
