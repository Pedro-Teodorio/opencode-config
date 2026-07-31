## Core Philosophy

**Key Principles:**

1. **Language**: Always answer in Brazilian Portuguese (pt-BR), regardless of the language of the question.
2. **Agent-First**: Delegate to specialized agents for complex work
3. **Parallel Execution**: Use Task tool with multiple agents when possible
4. **Plan Before Execute**: Use Plan Mode for complex operations
5. **Test-Driven**: Write tests before implementation
6. **Security-First**: Never compromise on security

## Harness MVP

Quando o repo ou um ancestral contiver `harness.json`, use o fluxo vault-first:

| Command | Responsabilidade |
|---------|------------------|
| `/discuss` | Discussão read-only para código; ideas no vault |
| `/spec` | Cria spec, plan e tasks em draft |
| `/approve` | Registra aprovação humana de spec e/ou plan |
| `/build` | Executa tasks aprovadas com TDD, Verify e Evidence |
| `/close` | Fecha a sessão partial ou total e persiste memória |

- Carregue `harness-memory` para discovery, paths, doctor, retrieval e escrita de estado.
- Carregue `harness-sdd` para templates, statuses, approve, cascata, gates, Verify e Evidence.
- Use `obsidian-markdown` somente na prosa humana indicada; active-context e tasks permanecem estritos.
- Toda escrita no vault é filesystem-first. Obsidian CLI é opcional e nunca bloqueia o fluxo.
- Somente o humano aprova spec/plan via `/approve` ou pedido explícito no turno atual.
- As policies do MVP são prompt-enforced; não há plugin ou agent novo do Harness.

## Available Agents

Localizados em `~/.config/opencode/agents/`.

| Agent | Mode | Foco | Quando usar |
|-------|------|------|-------------|
| `discussion` | primary | Tech lead — brainstorm, trade-offs, viabilidade; discute, não implementa | Discussão técnica, design, regras de negócio |
| `architect` | subagent (hidden) | Arquitetura, escalabilidade, decisões técnicas (read-only) | Features novas, refactors grandes, decisões arquiteturais |
| `planner` | subagent | Planos de implementação acionáveis, dependências e riscos | Features complexas, mudanças arquiteturais, refactors |
| `tdd-guide` | subagent | TDD red-green-refactor, cobertura 80%+ | Features, bugs, refactors test-first |
| `code-reviewer` | subagent (hidden) | Review de qualidade, segurança e manutenibilidade (sem editar) | Após escrever/modificar código — obrigatório em mudanças |

**Permissões resumidas:**
- `discussion`: edita só `*.md`; bash negado; pode chamar `architect`, `planner`, `explore`
- `architect`: edit/bash negados; web/docs ok
- `planner`: bash negado; todo/filesystem/docs ok
- `tdd-guide`: edit + bash + todo + filesystem
- `code-reviewer`: edit negado; bash/todo ok

**Uso proativo (sem o usuário pedir):**
1. Feature complexa → `planner`
2. Código escrito/modificado → `code-reviewer`
3. Feature/bug fix → `tdd-guide`
4. Decisão arquitetural → `architect`
5. Brainstorm/trade-offs → `discussion` (primary)

<available_agents>
  <agent>
    <name>discussion</name>
    <mode>primary</mode>
    <description>Tech lead para discussão técnica — brainstorm de arquitetura, design, regras de negócio, trade-offs e viabilidade. Honesto, direto, desafia ideias. Documenta quando pedido, na pasta que o usuário indicar.</description>
    <location>/home/pedro/.config/opencode/agents/discussion.md</location>
  </agent>
  <agent>
    <name>architect</name>
    <mode>subagent</mode>
    <description>Software architecture specialist for system design, scalability, and technical decision-making. Use PROACTIVELY when planning new features, refactoring large systems, or making architectural decisions.</description>
    <location>/home/pedro/.config/opencode/agents/architect.md</location>
  </agent>
  <agent>
    <name>planner</name>
    <mode>subagent</mode>
    <description>Expert planning specialist for complex features and refactoring. Use PROACTIVELY when users request feature implementation, architectural changes, or complex refactoring.</description>
    <location>/home/pedro/.config/opencode/agents/planner.md</location>
  </agent>
  <agent>
    <name>tdd-guide</name>
    <mode>subagent</mode>
    <description>Test-Driven Development specialist enforcing write-tests-first methodology. Use PROACTIVELY when writing new features, fixing bugs, or refactoring code. Ensures 80%+ test coverage.</description>
    <location>/home/pedro/.config/opencode/agents/tdd-guide.md</location>
  </agent>
  <agent>
    <name>code-reviewer</name>
    <mode>subagent</mode>
    <description>Expert code review specialist. Proactively reviews code for quality, security, and maintainability. Use immediately after writing or modifying code. MUST BE USED for all code changes.</description>
    <location>/home/pedro/.config/opencode/agents/code-reviewer.md</location>
  </agent>
</available_agents>

<available_skills>
  <skill>
    <name>harness-memory</name>
    <description>Resolve harness.json memory paths, runs doctor, retrieves bounded vault context, and updates active context, logs, and mistake ledger.</description>
    <location>/home/pedro/.config/opencode/skills/harness-memory/SKILL.md</location>
  </skill>
  <skill>
    <name>harness-sdd</name>
    <description>Governs Harness spec, plan, tasks, human approval, cascade, build gates, Verify, Evidence, and close transitions.</description>
    <location>/home/pedro/.config/opencode/skills/harness-sdd/SKILL.md</location>
  </skill>
  <skill>
    <name>api-design</name>
    <description>REST API design patterns including resource naming, status codes, pagination, filtering, error responses, versioning, and rate limiting for production APIs.</description>
    <location>/home/pedro/.config/opencode/skills/api-design/SKILL.md</location>
  </skill>
  <skill>
    <name>backend-patterns</name>
    <description>Backend architecture patterns, API design, database optimization, and server-side best practices for Node.js, Express, and Next.js API routes.</description>
    <location>/home/pedro/.config/opencode/skills/backend-patterns/SKILL.md</location>
  </skill>
  <skill>
    <name>coding-standards</name>
    <description>Baseline cross-project coding conventions for naming, readability, immutability, and code-quality review. Use detailed frontend or backend skills for framework-specific patterns.</description>
    <location>/home/pedro/.config/opencode/skills/coding-standards/SKILL.md</location>
  </skill>
  <skill>
    <name>frontend-design</name>
    <description>Guidance for distinctive, intentional visual design when building new UI or reshaping an existing one. Helps with aesthetic direction, typography, and making choices that don't read as templated defaults.</description>
    <location>/home/pedro/.config/opencode/skills/frontend-design/SKILL.md</location>
  </skill>
  <skill>
    <name>frontend-design-direction</name>
    <description>Set an ECC-specific frontend design direction for production UI work. Use when building or improving websites, dashboards, applications, components, landing pages, visual tools, or any web UI that needs stronger product-specific design judgment.</description>
    <location>/home/pedro/.config/opencode/skills/frontend-design-direction/SKILL.md</location>
  </skill>
  <skill>
    <name>frontend-patterns</name>
    <description>Frontend development patterns for React, Next.js, state management, performance optimization, and UI best practices.</description>
    <location>/home/pedro/.config/opencode/skills/frontend-patterns/SKILL.md</location>
  </skill>
  <skill>
    <name>obsidian-bases</name>
    <description>Create and edit Obsidian Bases (.base files) with views, filters, formulas, and summaries. Use when working with .base files, creating database-like views of notes, or when the user mentions Bases, table views, card views, filters, or formulas in Obsidian.</description>
    <location>/home/pedro/.config/opencode/skills/obsidian-bases/SKILL.md</location>
  </skill>
  <skill>
    <name>obsidian-cli</name>
    <description>Interact with Obsidian vaults using the Obsidian CLI to read, create, search, and manage notes, tasks, properties, and more. Also supports plugin and theme development with commands to reload plugins, run JavaScript, capture errors, take screenshots, and inspect the DOM. Use when the user asks to interact with their Obsidian vault, manage notes, search vault content, perform vault operations from the command line, or develop and debug Obsidian plugins and themes.</description>
    <location>/home/pedro/.config/opencode/skills/obsidian-cli/SKILL.md</location>
  </skill>
  <skill>
    <name>obsidian-markdown</name>
    <description>Create and edit Obsidian Flavored Markdown with wikilinks, embeds, callouts, properties, and other Obsidian-specific syntax. Use when working with .md files in Obsidian, or when the user mentions wikilinks, callouts, frontmatter, tags, embeds, or Obsidian notes.</description>
    <location>/home/pedro/.config/opencode/skills/obsidian-markdown/SKILL.md</location>
  </skill>
  <skill>
    <name>tdd</name>
    <description>Test-driven development. Use when the user wants to build features or fix bugs test-first, mentions "red-green-refactor", or wants integration tests.</description>
    <location>/home/pedro/.config/opencode/skills/tdd/SKILL.md</location>
  </skill>
</available_skills>
