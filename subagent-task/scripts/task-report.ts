import { Type } from "@earendil-works/pi-ai";
import { defineTool, type ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  pi.registerTool(defineTool({
    name: "task_report",
    label: "Task report",
    description: "Report the outcome of this delegated task. Call once, as your last tool action: question when you need an answer, blocked when you cannot proceed, or done after verification. Include the full report for done or blocked.",
    parameters: Type.Object({
      status: Type.Union([Type.Literal("question"), Type.Literal("blocked"), Type.Literal("done")]),
      message: Type.String({ description: "The question, blocking reason, or one-line completion summary" }),
      report: Type.Optional(Type.String({ description: "Work done, verification, files touched, and deviations" })),
    }),
    async execute(_id, params) {
      return {
        content: [{ type: "text", text: `Task ${params.status} recorded. End your turn now.` }],
        details: params,
      };
    },
  }));
}
