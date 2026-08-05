defmodule Testing do
  def load do
    # Root.MCP.Upstream.start("server-everything",
    #   command: "npx",
    #   args: ["-y", "@modelcontextprotocol/server-everything"]
    # )

    Root.MCP.Upstream.start("fs1",
      command: "npx",
      args: ["-y", "@modelcontextprotocol/server-filesystem", "/tmp/foo"]
    )

    Root.MCP.Upstream.start("fs2",
      command: "npx",
      args: ["-y", "@modelcontextprotocol/server-filesystem", "/tmp/bar"]
    )
  end

  def composition do
    script = """
    from root import call_tool, text


    def allowed_dir(server):
        out = text(call_tool(server, "list_allowed_directories", {}))
        return out.strip().splitlines()[-1].strip()


    def entries(server, path):
        out = text(call_tool(server, "list_directory", {"path": path}))
        for line in out.splitlines():
            line = line.strip()
            if line.startswith("[FILE]"):
                yield "file", line[len("[FILE]"):].strip()
            elif line.startswith("[DIR]"):
                yield "dir", line[len("[DIR]"):].strip()


    def copy_tree(src_path, dst_path):
        copied = []
        for kind, name in entries("fs1", src_path):
            src = f"{src_path}/{name}"
            dst = f"{dst_path}/{name}"
            if kind == "dir":
                call_tool("fs2", "create_directory", {"path": dst})
                copied += copy_tree(src, dst)
            else:
                content = text(call_tool("fs1", "read_text_file", {"path": src}))
                call_tool("fs2", "write_file", {"path": dst, "content": content})
                copied.append(dst)
        return copied


    def run(args):
        src_root = allowed_dir("fs1")
        dst_root = allowed_dir("fs2")
        copied = copy_tree(src_root, dst_root)
        print(f"copied {len(copied)} files")
        return {"from": src_root, "to": dst_root, "copied": copied}
    """

    Root.Composition.Runner.run(script, %{})
  end
end
