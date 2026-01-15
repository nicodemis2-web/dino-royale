#!/usr/bin/env node

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { exec } from "child_process";
import { promisify } from "util";

const execAsync = promisify(exec);

const server = new Server(
  {
    name: "desktop-control",
    version: "1.0.0",
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

// Tool definitions
server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: [
      {
        name: "mouse_move",
        description: "Move the mouse cursor to a specific position on screen",
        inputSchema: {
          type: "object",
          properties: {
            x: { type: "number", description: "X coordinate" },
            y: { type: "number", description: "Y coordinate" },
          },
          required: ["x", "y"],
        },
      },
      {
        name: "mouse_click",
        description: "Click the mouse at the current position or specified coordinates",
        inputSchema: {
          type: "object",
          properties: {
            x: { type: "number", description: "X coordinate (optional)" },
            y: { type: "number", description: "Y coordinate (optional)" },
            button: { type: "string", enum: ["left", "right"], description: "Mouse button" },
            clicks: { type: "number", description: "Number of clicks (1 or 2)" },
          },
          required: [],
        },
      },
      {
        name: "keyboard_type",
        description: "Type text using the keyboard",
        inputSchema: {
          type: "object",
          properties: {
            text: { type: "string", description: "Text to type" },
          },
          required: ["text"],
        },
      },
      {
        name: "keyboard_key",
        description: "Press a keyboard key or key combination",
        inputSchema: {
          type: "object",
          properties: {
            key: { type: "string", description: "Key to press (e.g., 'return', 'escape', 'tab', 'space')" },
            modifiers: {
              type: "array",
              items: { type: "string", enum: ["command", "control", "option", "shift"] },
              description: "Modifier keys to hold",
            },
          },
          required: ["key"],
        },
      },
      {
        name: "screenshot",
        description: "Take a screenshot of the screen",
        inputSchema: {
          type: "object",
          properties: {
            path: { type: "string", description: "Path to save the screenshot" },
          },
          required: ["path"],
        },
      },
      {
        name: "get_mouse_position",
        description: "Get the current mouse cursor position",
        inputSchema: {
          type: "object",
          properties: {},
          required: [],
        },
      },
      {
        name: "get_screen_size",
        description: "Get the screen dimensions",
        inputSchema: {
          type: "object",
          properties: {},
          required: [],
        },
      },
      {
        name: "open_application",
        description: "Open an application by name",
        inputSchema: {
          type: "object",
          properties: {
            name: { type: "string", description: "Application name" },
          },
          required: ["name"],
        },
      },
    ],
  };
});

// Tool implementations using AppleScript (macOS)
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    switch (name) {
      case "mouse_move": {
        const { x, y } = args as { x: number; y: number };
        // Use cliclick for mouse control on macOS
        await execAsync(`cliclick m:${x},${y}`);
        return { content: [{ type: "text", text: `Mouse moved to (${x}, ${y})` }] };
      }

      case "mouse_click": {
        const { x, y, button = "left", clicks = 1 } = args as {
          x?: number;
          y?: number;
          button?: string;
          clicks?: number;
        };
        const clickCmd = button === "right" ? "rc" : clicks === 2 ? "dc" : "c";
        if (x !== undefined && y !== undefined) {
          await execAsync(`cliclick ${clickCmd}:${x},${y}`);
          return { content: [{ type: "text", text: `Clicked at (${x}, ${y})` }] };
        } else {
          await execAsync(`cliclick ${clickCmd}:.`);
          return { content: [{ type: "text", text: `Clicked at current position` }] };
        }
      }

      case "keyboard_type": {
        const { text } = args as { text: string };
        // Escape special characters for AppleScript
        const escaped = text.replace(/"/g, '\\"');
        await execAsync(`osascript -e 'tell application "System Events" to keystroke "${escaped}"'`);
        return { content: [{ type: "text", text: `Typed: ${text}` }] };
      }

      case "keyboard_key": {
        const { key, modifiers = [] } = args as { key: string; modifiers?: string[] };
        const keyMap: Record<string, number> = {
          return: 36, enter: 36, escape: 53, tab: 48, space: 49,
          delete: 51, backspace: 51, up: 126, down: 125, left: 123, right: 124,
          f1: 122, f2: 120, f3: 99, f4: 118, f5: 96, f6: 97,
          f7: 98, f8: 100, f9: 101, f10: 109, f11: 103, f12: 111,
        };

        const keyCode = keyMap[key.toLowerCase()];
        if (keyCode !== undefined) {
          const modStr = modifiers.map(m => `${m} down`).join(", ");
          const usingClause = modifiers.length > 0 ? ` using {${modStr}}` : "";
          await execAsync(`osascript -e 'tell application "System Events" to key code ${keyCode}${usingClause}'`);
        } else {
          const modStr = modifiers.map(m => `${m} down`).join(", ");
          const usingClause = modifiers.length > 0 ? ` using {${modStr}}` : "";
          await execAsync(`osascript -e 'tell application "System Events" to keystroke "${key}"${usingClause}'`);
        }
        return { content: [{ type: "text", text: `Pressed key: ${key}` }] };
      }

      case "screenshot": {
        const { path } = args as { path: string };
        await execAsync(`screencapture -x "${path}"`);
        return { content: [{ type: "text", text: `Screenshot saved to ${path}` }] };
      }

      case "get_mouse_position": {
        const { stdout } = await execAsync(`cliclick p`);
        return { content: [{ type: "text", text: stdout.trim() }] };
      }

      case "get_screen_size": {
        const { stdout } = await execAsync(`osascript -e 'tell application "Finder" to get bounds of window of desktop'`);
        return { content: [{ type: "text", text: `Screen bounds: ${stdout.trim()}` }] };
      }

      case "open_application": {
        const { name: appName } = args as { name: string };
        await execAsync(`open -a "${appName}"`);
        return { content: [{ type: "text", text: `Opened application: ${appName}` }] };
      }

      default:
        return { content: [{ type: "text", text: `Unknown tool: ${name}` }], isError: true };
    }
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    return { content: [{ type: "text", text: `Error: ${errorMessage}` }], isError: true };
  }
});

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("Desktop Control MCP server running on stdio");
}

main().catch(console.error);
