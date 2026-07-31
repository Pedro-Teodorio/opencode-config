# Agent Orchestration

## Available Agents

Localizados em `~/.config/opencode/agents/`.

| Agent | Mode | Purpose | When to Use |
|-------|------|---------|-------------|
| discussion | primary | Tech lead — brainstorm, trade-offs, viabilidade; discute, não implementa | Discussão técnica, design, regras de negócio |
| architect | subagent (hidden) | Arquitetura, escalabilidade, decisões técnicas (read-only) | Features novas, refactors grandes, decisões arquiteturais |
| planner | subagent | Planos de implementação acionáveis, dependências e riscos | Features complexas, mudanças arquiteturais, refactors |
| tdd-guide | subagent | TDD red-green-refactor, cobertura 80%+ | Features, bugs, refactors test-first |
| code-reviewer | subagent (hidden) | Review de qualidade, segurança e manutenibilidade (sem editar) | Após escrever/modificar código — obrigatório em mudanças |

## Permissions

- `discussion`: edita só `*.md`; bash negado; pode chamar `architect`, `planner`, `explore`
- `architect`: edit/bash negados; web/docs ok
- `planner`: bash negado; todo/filesystem/docs ok
- `tdd-guide`: edit + bash + todo + filesystem
- `code-reviewer`: edit negado; bash/todo ok

## Immediate Agent Usage

Sem o usuário pedir:

1. Feature complexa → **planner**
2. Código escrito/modificado → **code-reviewer**
3. Feature/bug fix → **tdd-guide**
4. Decisão arquitetural → **architect**
5. Brainstorm/trade-offs → **discussion** (primary)

## Typical Flow

```text
discussion → architect / planner → tdd-guide → code-reviewer
```

## Parallel Task Execution

ALWAYS use parallel Task execution for independent operations:

```markdown
# GOOD: Parallel execution
Launch 3 agents in parallel:
1. Agent 1: Architecture review of auth module
2. Agent 2: TDD plan for checkout flow
3. Agent 3: Code review of recent changes

# BAD: Sequential when unnecessary
First agent 1, then agent 2, then agent 3
```

## Multi-Perspective Analysis

For complex problems, split work across existing agents:

- `architect` — design and trade-offs
- `planner` — breakdown and risks
- `tdd-guide` — test seams and coverage
- `code-reviewer` — quality, security, maintainability
- `discussion` — challenge assumptions and align decisions
