# Performance Optimization

### Model Selection Strategy

**Haiku** (90% of Sonnet capability, 3x cost savings):
- Lightweight agents with frequent invocation
- Pair programming and code generation
- Worker agents in multi-agent systems

**GPT 5.3* (Best coding model):
- Main development work
- Orchestrating multi-agent workflows
- Complex coding tasks

**Gemini 3.1 Pro Preview** (Deepest reasoning):
- Complex architectural decisions
- Maximum reasoning requirements
- Research and analysis tasks

### Context Window Management

Avoid last 20% of context window for:
- Large-scale refactoring
- Feature implementation spanning multiple files
- Debugging complex interactions

## Build Troubleshooting

If build fails:
1. Use **build-error-resolver** agent
2. Analyze error messages
3. Fix incrementally
4. Verify after each fix
