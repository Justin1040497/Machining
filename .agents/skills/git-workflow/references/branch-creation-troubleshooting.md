# Branch Creation Troubleshooting

Use this reference when creating a branch fails, especially when Git reports `cannot lock ref`.

## Start With Format Validation

Check whether the proposed branch name is valid before diagnosing Git storage or environment issues:

```bash
git check-ref-format --branch <branch-name>
```

If this fails, choose a branch name that follows `branch-policy.md`.

## Do Not Guess From `cannot lock ref`

`cannot lock ref` can mean different things. Do not immediately say the branch name conflicts. First identify whether this is:

- a real Git ref path conflict, or
- a sandbox, permission, filesystem, or lock-file problem while writing `.git`.

## Real Ref Path Conflict

Git stores branch refs as paths under `.git/refs/heads/`. These cases are real naming conflicts:

- Existing branch: `fix`; attempted branch: `fix/windows-ffprobe-json-escape`.
- Existing branch: `fix/windows-ffprobe-json-escape`; attempted branch: `fix`.

Use targeted checks:

```bash
git branch --list fix
git branch --list 'fix/*'
git for-each-ref --format='%(refname:short)' refs/heads refs/remotes/origin
```

Only treat the failure as a name conflict when a branch and branch namespace are occupying the same ref path. In that case, propose a non-conflicting branch name that still follows the repository naming rules.

## Sandbox Or Permission Failure

If the branch name is valid and no real ref path conflict is found, classify the failure as environment-related when the error mentions any of:

```text
unable to create directory
Permission denied
Operation not permitted
couldn't create
cannot lock ref
.git/refs/heads/
```

For this case, do not keep changing the branch name. Say clearly that the branch name appears valid and no ref path conflict was found, then retry using a command context allowed to write `.git`.

Recommended wording:

```text
The branch name is valid, and I did not find a real ref path conflict. This looks like the current sandbox or permissions cannot write to .git/refs/heads, so I need to retry branch creation with permission to write Git refs.
```

## Diagnostic Order

When branch creation fails:

1. Run `git check-ref-format --branch <branch-name>`.
2. Inspect `git branch --list <prefix>` and `git branch --list '<prefix>/*'`.
3. Inspect local and origin refs with `git for-each-ref`.
4. If a real path conflict exists, pick a different compliant name.
5. If no conflict exists, treat `.git` write errors as sandbox or permission issues and retry with the appropriate permission path.
