# Root MCP

Root is a meta MCP server that allows users to add MCP servers to it, and it
behaves as a gateway to these RPCs. There are [plenty of alternatives for
this](https://composio.dev/mcp-gateway) already, however.

Root takes this a bit further by allowing an LLM to create compositions of
tools once, and let clients reuse them.

Using a lot of MCPs has a few drawbacks.

1. Each tool takes up space in the
   context[[1]](https://www.apideck.com/blog/mcp-server-eating-context-window-cli-alternative)
2. The composition of outputs and inputs of MCPs is non-determinstic. The
   compostion lives in your agent's memory and there is no way to verify it's
   logic, or reuse it.
3. Frequent compositions of tools will require repeated token usage, while this
   logic can be trivially exported into a script that can be reused later.

By allowing an agent to configure an MCP server, we can collapse multiple tools
into a single tool reduce context size. By manifesting the composition logic as
code, the composition can be reviewed by humans, and reused with a guarantee
that it will behave the same on each invocation. And finally, since the MCP runs
the code outside of the model, no tokens are spent on doing the actual
composition.

To facilitate this, Root exposes two modes to the LLM: user mode and editor mode.

## User Mode

In user mode, Root behaves exactly as you would expect an MCP Gateway to behave.
It exposes a bunch of tools your LLM can use.

## Editor Mode

In editor mode, Root allows your client to wire up compositions of MCP servers.
The idea is as follows.

In editor mode, the LLM has access to all the sub MCPs that are loaded into Root. The editor can then inspect these, and the user can define how these tools have to be chained together. The LLM generates Python code that defines this behavior, and uploads it to Root, creating a new tool.

Any user mode session will have access to the newly created tool.