import * as vscode from "vscode";
import { execFile } from "child_process";
import { promisify } from "util";

const execFileAsync = promisify(execFile);

export function activate(context: vscode.ExtensionContext) {
  const status = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 90);
  status.text = "$(key) Vibe Vault";
  status.tooltip = "Local secrets · MCP audited per agent";
  status.command = "vibevault.openDocs";
  status.show();

  context.subscriptions.push(
    status,
    vscode.commands.registerCommand("vibevault.openDocs", () => {
      vscode.env.openExternal(vscode.Uri.parse("https://lunaos.ai/download/vibevault"));
      vscode.window.showInformationMessage(
        "Install Vibe Vault on macOS, then run: vibevault mcp install --client vscode && vibevault skill install"
      );
    }),
    vscode.commands.registerCommand("vibevault.installMCP", async () => {
      const cfg = vscode.workspace.getConfiguration("vibevault");
      const binary = cfg.get<string>("mcpBinary") || "vibevault";
      try {
        await execFileAsync(binary, ["mcp", "install", "--client", "vscode"]);
        await execFileAsync(binary, ["skill", "install"]);
        vscode.window.showInformationMessage("Vibe Vault MCP and skill installed.");
      } catch (e) {
        vscode.window.showErrorMessage(`Vibe Vault setup failed: ${e}`);
      }
    })
  );
}

export function deactivate() {}
