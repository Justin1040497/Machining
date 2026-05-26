# Worktree Policy

Use `git worktree` when a new task should start without disturbing the current working tree.

## Good Use Cases

- The current branch has uncommitted work and the user wants a separate task.
- Two branches need to remain available at the same time.
- A review, hotfix, or experiment should happen while the current branch stays untouched.
- Stashing would hide too much context or make it easy to forget the current task state.

## Directory Rule

Create worktrees under:

```text
worktrees/<task-slug>
```

The repository ignores `worktrees/`, so local worktree files should not be staged from the parent checkout.

## Create a New Worktree Branch

```bash
git fetch origin
git worktree add worktrees/<task-slug> -b <branch-name> origin/main
```

Use this when the new branch should start from the latest remote `main`.

## Open an Existing Branch in a Worktree

```bash
git worktree add worktrees/<task-slug> <branch-name>
```

## Inspect and Clean Up

```bash
git worktree list
git worktree remove worktrees/<task-slug>
git worktree prune
```

## Safety Rules

- Do not create worktrees in tracked source directories.
- Do not run broad formatting from the parent checkout in a way that traverses ignored worktrees.
- Do not delete a worktree until its branch has been merged, pushed, or explicitly abandoned.
- If a worktree contains local uncommitted work, preserve it or ask before removal.
