import { App, Flow, PageDefinition } from "../../engine/src/core";
import {
  V,
  AnimateForward,
  AnimateReverse,
  ShowSnackbar,
} from "../../engine/src/types";
import {
  Scaffold,
  AppBar,
  Column,
  Row,
  Text,
  Icon,
  ElevatedButton,
  Center,
  SizedBox,
  Container,
  Positioned,
  AnimatedBuilder,
} from "../../engine/src/components";
import { Curves } from "../../engine/src/components/helpers/curves";

// ── Auto-Play Animation Page ────────────────────────────────

const autoPlayPage = PageDefinition.create({
  id: "auto-play",
  title: "Auto-Play Animations",
  render: (_ctx, _info) =>
    Scaffold.new({
      appBar: AppBar.new({
        title: Text.new({ data: "Auto-Play Animations" }),
        centerTitle: true,
      }),
      body: Center.new({
        child: Column.new({
          mainAxisAlignment: "center",
          children: [
            // Simple text size + color animation
            AnimatedBuilder.new({
              duration: 1000,
              curve: Curves.EaseInOut,
              repeat: true,
              reverse: true,
              children: [
                Text.new({
                  data: "Hello Animations!",
                  style: {
                    fontSize: V.Tween(16, 32),
                    fontWeight: "bold",
                    color: V.Tween("#333333", "#FF4081"),
                  },
                }),
              ],
            }),
            SizedBox.new({ height: 48 }),
            // Star icon bouncing with TweenSequence
            Container.new({
              width: 200,
              height: 60,
              child: AnimatedBuilder.new({
                duration: 1200,
                curve: Curves.Linear,
                repeat: true,
                children: [
                  Positioned.new({
                    left: V.TweenSequence([
                      { value: 0, duration: 0 },
                      { value: 160, duration: 600 },
                      { value: 0, duration: 600 },
                    ]),
                    top: 16,
                    child: Icon.new({ name: "star", size: 24, color: "#FFD700" }),
                  }),
                ],
              }),
            }),
            SizedBox.new({ height: 48 }),
            // Opacity + size animation
            AnimatedBuilder.new({
              duration: 800,
              curve: Curves.EaseInOutCirc,
              repeat: true,
              reverse: true,
              children: [
                Container.new({
                  width: V.Tween(40, 120),
                  height: V.Tween(40, 120),
                  decoration: {
                    color: V.Tween("#2196F3", "#E91E63"),
                    borderRadius: V.Tween(4, 60),
                  },
                }),
              ],
            }),
          ],
        }),
      }),
    }),
});

// ── Button-Controlled Animation Page ────────────────────────

const controlledPage = PageDefinition.create({
  id: "controlled",
  title: "Controlled Animations",
  render: (_ctx, _info) =>
    Scaffold.new({
      appBar: AppBar.new({
        title: Text.new({ data: "Controlled Animations" }),
        centerTitle: true,
      }),
      body: Center.new({
        child: Column.new({
          mainAxisAlignment: "center",
          children: [
            // Animated panel controlled by buttons
            AnimatedBuilder.new({
              animationId: "expandPanel",
              autoStart: false,
              duration: 500,
              curve: Curves.FastOutSlowIn,
              children: [
                Container.new({
                  width: V.Tween(100, 300),
                  height: V.Tween(50, 150),
                  decoration: {
                    color: V.Tween("#E3F2FD", "#1565C0"),
                    borderRadius: V.Tween(8, 24),
                  },
                  child: Center.new({
                    child: Text.new({
                      data: "Panel",
                      style: {
                        fontSize: V.Tween(14, 28),
                        color: V.Tween("#1565C0", "#FFFFFF"),
                        fontWeight: "bold",
                      },
                    }),
                  }),
                }),
              ],
              actions: {
                onComplete: ShowSnackbar("Animation finished!"),
              },
            }),
            SizedBox.new({ height: 32 }),
            Row.new({
              mainAxisAlignment: "center",
              children: [
                ElevatedButton.new({
                  child: Text.new({ data: "Expand" }),
                  actions: {
                    onTap: AnimateForward("expandPanel"),
                  },
                }),
                SizedBox.new({ width: 16 }),
                ElevatedButton.new({
                  child: Text.new({ data: "Collapse" }),
                  actions: {
                    onTap: AnimateReverse("expandPanel"),
                  },
                }),
              ],
            }),
            SizedBox.new({ height: 48 }),
            // Second controlled animation — sliding icon
            Container.new({
              width: 200,
              height: 48,
              child: AnimatedBuilder.new({
                animationId: "slideIcon",
                autoStart: false,
                duration: 600,
                curve: Curves.EaseInOutExpo,
                children: [
                  Positioned.new({
                    left: V.Tween(0, 160),
                    top: 8,
                    child: Icon.new({
                      name: "favorite",
                      size: 32,
                      color: "#E91E63",
                    }),
                  }),
                ],
              }),
            }),
            SizedBox.new({ height: 16 }),
            Row.new({
              mainAxisAlignment: "center",
              children: [
                ElevatedButton.new({
                  child: Text.new({ data: "Slide Right" }),
                  actions: {
                    onTap: AnimateForward("slideIcon"),
                  },
                }),
                SizedBox.new({ width: 16 }),
                ElevatedButton.new({
                  child: Text.new({ data: "Slide Left" }),
                  actions: {
                    onTap: AnimateReverse("slideIcon"),
                  },
                }),
              ],
            }),
          ],
        }),
      }),
    }),
});

// ── App ──────────────────────────────────────────────────────

const animationsFlow = Flow.create({
  name: "animations",
  routes: [
    { path: "auto-play", page: autoPlayPage },
    { path: "controlled", page: controlledPage },
  ],
});

export const animationsApp = App.create({
  id: "animations",
  name: "Animations",
  flows: [animationsFlow],
  navigation: {
    initialRoute: "/auto-play",
  },
});
