# AGENTS.md

## Project Context

- 这个项目叫 `MCPSpanCLI`，用途是把 MCP server 的能力转换成可挂载的 skill。
- 它更像一个学习型命令行工具和实验场，不是一次性要做成完整产品。
- 目前关注点主要在 Swift 的基础语法、SwiftPM、`ArgumentParser`、命令行入口这些地方。
- 讲解或改动时，优先保证实现简单、可理解、方便继续迭代。


## Learning Style

- 后续解释 Swift 时，优先用 Java 的概念做对照。
- 遇到 `self`、`Self`、`type`、`class`、`protocol` 这些 Swift 术语时，尽量先翻成 Java 里的对应直觉，再解释 Swift 的差异。
- 如果某个 Swift 语法点和 Java 的习惯不一致，先说明“Java 里会怎么想”，再说明 Swift 的真实写法。
- 这个项目当前以学习为主，不需要一次性完整实现，优先帮助我把概念理顺。
- 回复里不要使用“如果你愿意”之类的追问句式，优先直接给出下一步或可选项。

## Release Rules

- 涉及发版、打 tag、发布 release、修改安装说明或 README 里的版本信息时，必须同步检查 `Sources/MCPSpanCLI/BuildInfo.swift` 里的版本号是否一致，不能漏改。
