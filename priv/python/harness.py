"""Entry point for running a composition script.

Invoked by Root.Composition.Runner as: python3 harness.py <script.py>

Reads the composition arguments as a single JSON line from stdin, imports the
script, calls its run(args), and writes exactly one JSON envelope to the real
stdout: {"status": "ok", "result": ...} or {"status": "error", "traceback": ...}.

User code's sys.stdout is redirected to stderr so stray print() calls cannot
corrupt the result channel.
"""

import importlib.util
import json
import os
import sys
import traceback


def main():
    script_path = sys.argv[1]
    args = json.loads(sys.stdin.readline() or "{}")

    result_out = os.fdopen(os.dup(1), "w")
    sys.stdout = sys.stderr

    try:
        spec = importlib.util.spec_from_file_location("composition", script_path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        result = module.run(args)
        result_out.write(json.dumps({"status": "ok", "result": result}) + "\n")
    except BaseException:
        result_out.write(
            json.dumps({"status": "error", "traceback": traceback.format_exc()}) + "\n"
        )
        result_out.flush()
        sys.exit(1)
    result_out.flush()


main()
