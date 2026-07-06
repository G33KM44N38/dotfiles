#!/usr/bin/env node
const fs = require('node:fs');
const path = require('node:path');

const prefix = process.env.PI_CODING_AGENT_PREFIX || '/opt/homebrew/Cellar/pi-coding-agent';
const versions = fs.existsSync(prefix)
  ? fs.readdirSync(prefix).filter((name) => /^\d+\.\d+\.\d+/.test(name)).sort()
  : [];
const version = versions.at(-1);

if (!version) {
  console.error(`pi-coding-agent install not found under ${prefix}`);
  process.exit(1);
}

const markdownPath = path.join(
  prefix,
  version,
  'libexec/lib/node_modules/@earendil-works/pi-coding-agent/node_modules/@earendil-works/pi-tui/dist/components/markdown.js',
);

let source = fs.readFileSync(markdownPath, 'utf8');

const before = `            case "code": {\n                const indent = this.theme.codeBlockIndent ?? "  ";\n                lines.push(this.theme.codeBlockBorder(\`\`\`\${token.lang || ""}\`));\n                if (this.theme.highlightCode) {\n                    const highlightedLines = this.theme.highlightCode(token.text, token.lang);\n                    for (const hlLine of highlightedLines) {\n                        lines.push(\`\${indent}\${hlLine}\`);\n                    }\n                }\n                else {\n                    // Split code by newlines and style each line\n                    const codeLines = token.text.split("\\n");\n                    for (const codeLine of codeLines) {\n                        lines.push(\`\${indent}\${this.theme.codeBlock(codeLine)}\`);\n                    }\n                }\n                lines.push(this.theme.codeBlockBorder("\`\`\`"));\n                if (nextTokenType && nextTokenType !== "space") {\n                    lines.push(""); // Add spacing after code blocks (unless space token follows)\n                }\n                break;\n            }\n`;

const after = `            case "code": {\n                const indent = this.theme.codeBlockIndent ?? "  ";\n                const label = token.lang ? \` \${token.lang} \` : "";\n                lines.push(this.theme.codeBlockBorder(\`╭─\${label}\`));\n                if (this.theme.highlightCode) {\n                    const highlightedLines = this.theme.highlightCode(token.text, token.lang);\n                    for (const hlLine of highlightedLines) {\n                        lines.push(\`\${indent}\${hlLine}\`);\n                    }\n                }\n                else {\n                    // Split code by newlines and style each line\n                    const codeLines = token.text.split("\\n");\n                    for (const codeLine of codeLines) {\n                        lines.push(\`\${indent}\${this.theme.codeBlock(codeLine)}\`);\n                    }\n                }\n                lines.push(this.theme.codeBlockBorder("╰─"));\n                if (nextTokenType && nextTokenType !== "space") {\n                    lines.push(""); // Add spacing after code blocks (unless space token follows)\n                }\n                break;\n            }\n`;

if (source.includes(after)) {
  console.log(`${markdownPath} already patched`);
  process.exit(0);
}

if (!source.includes(before)) {
  console.error(`${markdownPath} does not match expected markdown renderer block`);
  process.exit(1);
}

source = source.replace(before, after);
fs.writeFileSync(markdownPath, source);
console.log(`patched ${markdownPath}`);
