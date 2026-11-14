import { App, Flow, PageDefinition, ServerActionDefinition } from "../../engine/src/core";
import type { ResponseAction } from "../../engine/src/core/server-action";
import { V, SetState, ServerAction } from "../../engine/src/types";
import {
  Scaffold,
  AppBar,
  Column,
  Row,
  Text,
  ElevatedButton,
  SizedBox,
  Padding,
  SingleChildScrollView,
  Expanded,
  Icon,
  TextField,
  GestureDetector,
  EdgeInsets,
} from "../../engine/src/components";

// Todo example. The list lives in this module's memory: add, tick and delete
// go through server actions that answer with a fresh "todo-list" subtree,
// built by the same function the page uses. A restart empties it.

interface Todo {
  id: string;
  text: string;
  done: boolean;
}

const todos: Todo[] = [];

/** Empties the list (tests). */
export function resetTodos(): void {
  todos.length = 0;
}

const LIST = "todo-list";
const green = "#43A047";
const lightGrey = "#BDBDBD";
const grey = "#9E9E9E";

function todoRow(todo: Todo) {
  return Row.new({
    crossAxisAlignment: "start",
    gap: 12,
    children: [
      GestureDetector.new({
        child: Icon.new({
          name: todo.done ? "check_circle" : "circle",
          color: todo.done ? green : lightGrey,
        }),
        actions: { onTap: ServerAction("toggleTodo", { id: V.static(todo.id) }) },
      }),
      Expanded.new({
        child: Text.new({
          data: V.static(todo.text),
          style: todo.done ? { fontSize: 16, color: grey, decoration: "lineThrough" } : { fontSize: 16 },
        }),
      }),
      GestureDetector.new({
        child: Icon.new({ name: "close", color: grey }),
        actions: { onTap: ServerAction("deleteTodo", { id: V.static(todo.id) }) },
      }),
    ],
  });
}

function todoList() {
  return Column.new({
    crossAxisAlignment: "stretch",
    gap: 12,
    children:
      todos.length === 0
        ? [Text.new({ data: "Nothing to do yet. Add one above.", style: { color: grey } })]
        : todos.map(todoRow),
  }).withKey(LIST);
}

function replaceList(): ResponseAction {
  return { type: "replaceComponent", targetId: LIST, keyPrefix: "todo", widget: todoList() };
}

// ── Server Actions ──────────────────────────────────────

const addTodo = ServerActionDefinition.create({
  id: "addTodo",
  schema: { text: { type: "string", required: true } },
  execute: (ctx) => {
    const text = (ctx.actionParams.text as string).trim();
    if (text === "") return [];
    todos.push({ id: crypto.randomUUID(), text, done: false });
    return [replaceList(), { type: "setState", scope: "page", key: "draft", value: "" }];
  },
});

const toggleTodo = ServerActionDefinition.create({
  id: "toggleTodo",
  schema: { id: { type: "string", required: true } },
  execute: (ctx) => {
    const todo = todos.find((t) => t.id === ctx.actionParams.id);
    if (todo) todo.done = !todo.done;
    return [replaceList()];
  },
});

const deleteTodo = ServerActionDefinition.create({
  id: "deleteTodo",
  schema: { id: { type: "string", required: true } },
  execute: (ctx) => {
    const index = todos.findIndex((t) => t.id === ctx.actionParams.id);
    if (index >= 0) todos.splice(index, 1);
    return [replaceList()];
  },
});

// ── Page ────────────────────────────────────────────────

const homePage = PageDefinition.create({
  id: "home",
  title: "Todo",
  cachePolicy: "none",
  state: [{ key: "draft", scope: "page", initial: "" }],
  render: () =>
    Scaffold.new({
      appBar: AppBar.new({ title: Text.new({ data: "Todo" }), centerTitle: true }),
      body: SingleChildScrollView.new({
        child: Padding.new({
          padding: EdgeInsets.all(16),
          child: Column.new({
            crossAxisAlignment: "stretch",
            children: [
              Row.new({
                gap: 8,
                children: [
                  Expanded.new({
                    child: TextField.new({
                      placeholder: "New todo",
                      value: V.pageState("draft"),
                      actions: { onChange: SetState("draft", V.event("value")) },
                    }),
                  }),
                  ElevatedButton.new({
                    child: Text.new({ data: "Add" }),
                    actions: { onTap: ServerAction("addTodo", { text: V.pageState("draft") }) },
                  }),
                ],
              }),
              SizedBox.new({ height: 24 }),
              todoList(),
              SizedBox.new({ height: 24 }),
              Text.new({ data: "Kept on the server until it stops.", style: { fontSize: 12, color: grey } }),
            ],
          }),
        }),
      }),
    }),
});

// ── App ──────────────────────────────────────────────────

const homeFlow = Flow.create({
  name: "home",
  routes: [{ path: "home", page: homePage }],
});

export const todoApp = App.create({
  id: "todo",
  name: "Todo",
  flows: [homeFlow],
  actions: [addTodo, toggleTodo, deleteTodo],
});
