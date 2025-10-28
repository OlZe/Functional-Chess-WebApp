import gleam/int
import gleam/list
import lustre/attribute.{class, classes}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import web_chess/internal/game_logic as logic

pub fn render(
  history history: List(logic.ArchivedMove),
  selected_index selected_index: Int,
  on_click_move on_click_move: fn(Int) -> msg,
) -> Element(msg) {
  // Bring history into correct order and include move numbers
  let history =
    history
    |> list.reverse()
    |> list.index_map(fn(move, index) {
      let number = index + 1
      #(number, move)
    })

  html.div(
    [
      class(
        "grid [grid-template-columns:1.5rem_4.5rem_4.5rem] justify-center place-items-center gap-y-1 gap-x-1.5 pt-2 pb-1",
      ),
    ],
    history
      |> list.flat_map(fn(number_and_move) {
        let #(number, full_move) = number_and_move
        case full_move {
          logic.FullMove(white: white_move, black: black_move) -> [
            html.p([], [html.text(int.to_string(number) <> ".")]),
            render_half_move(
              san: white_move.san_description,
              is_selected: white_move.index == selected_index,
              on_click: fn() { on_click_move(white_move.index) },
            ),
            render_half_move(
              san: black_move.san_description,
              is_selected: black_move.index == selected_index,
              on_click: fn() { on_click_move(black_move.index) },
            ),
          ]
          logic.HalfMove(white: white_move) -> [
            html.p([], [html.text(int.to_string(number) <> ".")]),
            render_half_move(
              san: white_move.san_description,
              is_selected: white_move.index == selected_index,
              on_click: fn() { on_click_move(white_move.index) },
            ),
          ]
        }
      }),
  )
}

fn render_half_move(
  san san: String,
  is_selected is_selected: Bool,
  on_click on_click: fn() -> msg,
) -> Element(msg) {
  html.button(
    [
      class(
        "font-bold cursor-pointer hover:bg-white/8 rounded pt-0.5 pb-0.5 pl-1.5 pr-1.5",
      ),
      classes([#("underline bg-white/8", is_selected)]),
      event.on_click(on_click()),
    ],
    [
      html.text(san),
    ],
  )
}
