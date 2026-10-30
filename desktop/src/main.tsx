import React from "react";
import ReactDOM from "react-dom/client";
import { getCurrentWindow } from "@tauri-apps/api/window";
import App from "./App";
import Feedback from "./Feedback";
import "./App.css";

// One page serves two windows: the settings window and the transparent move highlight.
const isFeedback = getCurrentWindow().label === "feedback";
document.documentElement.dataset.window = isFeedback ? "feedback" : "settings";

ReactDOM.createRoot(document.getElementById("root") as HTMLElement).render(
  <React.StrictMode>{isFeedback ? <Feedback /> : <App />}</React.StrictMode>,
);
