# VibeVault Subshell Injection Bug - Fix Guide

## Problem Summary

When using `vibevault run sh -c '...'`, secrets injected as environment variables are **not accessible to command substitutions** (`$()`) or subshells within the quoted script. This causes patterns like:

```bash
# ❌ BROKEN: SECRET is empty because $(vibevault get ...) runs in subshell
vibevault run sh -c 'SECRET=$(vibevault get MY_SECRET); echo "$SECRET"'
```

## Root Cause

In `vibevault/src/runner.rs` (or equivalent), environment variables are injected into the **parent shell process**, but command substitutions spawn **child processes** that don't inherit the injected secrets.

### Current Flow (Broken)

```
vibevault run sh -c '...'
    ↓
[Inject secrets into current env]
    ↓
[Spawn sh -c '...']
    ↓
[sh parses 'SECRET=$(...)' as string literal]
    ↓
[sh executes: spawn subshell for $(vibevault get)]
    ↓
[subshell has NO secrets → returns empty]
```

## Fix Location

File: `vibevault/src/commands/run.rs` (or `src/runner.rs`)

Function: `exec_with_secrets()` or `run_command()`

## The Fix

### Option 1: Pre-process Script to Inline Secrets (Recommended)

Before executing `sh -c`, scan the script for `$VAR` patterns and replace with actual secret values:

```rust
// In vibevault/src/commands/run.rs

fn exec_with_secrets(cmd: &str, secrets: HashMap<String, String>) -> Result<()> {
    // 1. Load all secrets from vault
    let vault_secrets = load_secrets_for_current_context()?;
    
    // 2. Pre-process the command script
    // Replace $SECRET_NAME with actual values BEFORE passing to shell
    let processed_cmd = vault_secrets.iter().fold(cmd.to_string(), |acc, (key, value)| {
        // Replace both $KEY and ${KEY} patterns
        acc.replace(&format!("${}", key), value)
           .replace(&format!("${{{}}}", key), value)
    });
    
    // 3. Also set as env vars for backward compatibility
    for (key, value) in &vault_secrets {
        env::set_var(key, value);
    }
    
    // 4. Execute the PRE-PROCESSED command (not original)
    // This ensures even $(echo $SECRET) works because $SECRET is already replaced
    let status = Command::new("sh")
        .arg("-c")
        .arg(&processed_cmd)  // ← Use processed, not original
        .status()?;
    
    Ok(status)
}
```

### Option 2: Export to Shell Environment File

```rust
fn exec_with_secrets(cmd: &str, secrets: HashMap<String, String>) -> Result<()> {
    // 1. Create temp env file with exports
    let mut env_file = tempfile::NamedTempFile::new()?;
    for (key, value) in &secrets {
        writeln!(env_file, "export {}='{}'", key, escape_single_quotes(value))?;
    }
    env_file.flush()?;
    
    // 2. Modify command to source env file first
    let wrapped_cmd = format!(
        "source {} && {}",
        env_file.path().display(),
        cmd
    );
    
    // 3. Execute with env file sourced
    let status = Command::new("sh")
        .arg("-c")
        .arg(&wrapped_cmd)
        .status()?;
    
    // 4. Cleanup happens automatically via Drop
    Ok(status)
}
```

### Option 3: Use execve() with Modified Environment (Unix-only)

```rust
fn exec_with_secrets(cmd: &str, secrets: HashMap<String, String>) -> Result<()> {
    // Build complete environment including secrets
    let mut env_vars: Vec<(String, String)> = std::env::vars().collect();
    env_vars.extend(secrets.into_iter());
    
    // Use std::process::Command with env_clear() + env()
    let mut command = Command::new("sh");
    command.arg("-c").arg(cmd);
    
    // Clear and rebuild env from scratch
    command.env_clear();
    for (key, value) in env_vars {
        command.env(&key, &value);
    }
    
    let status = command.status()?;
    Ok(status)
}
```

## Testing the Fix

Add this test case to `tests/run_test.rs`:

```rust
#[test]
fn test_subshell_secret_access() {
    // Setup: Create a secret
    vault_set("TEST_SUBSHELL_SECRET", "my_secret_value").unwrap();
    
    // Test 1: Direct access (should work)
    let output = Command::new("vibevault")
        .args(&["run", "sh", "-c", "echo $TEST_SUBSHELL_SECRET"])
        .output()
        .expect("Failed to execute");
    
    assert!(output.stdout.contains("my_secret_value"));
    
    // Test 2: Subshell access (the bug case)
    let output = Command::new("vibevault")
        .args(&["run", "sh", "-c", 
               "SECRET=$(echo $TEST_SUBSHELL_SECRET); echo $SECRET"])
        .output()
        .expect("Failed to execute");
    
    // This currently fails - should pass after fix
    assert!(output.stdout.contains("my_secret_value"), 
            "Subshell should inherit secrets");
    
    // Test 3: Nested command substitution
    let output = Command::new("vibevault")
        .args(&["run", "sh", "-c",
               "echo $(echo $TEST_SUBSHELL_SECRET) | cat"])
        .output()
        .expect("Failed to execute");
    
    assert!(output.stdout.contains("my_secret_value"));
}
```

## Backward Compatibility

All three options maintain backward compatibility:

1. **Option 1** (Pre-process): Existing `$VAR` usage still works, now also works in subshells
2. **Option 2** (Env file): Works with all shell patterns, minimal code change
3. **Option 3** (execve): Cleanest but platform-specific

## Recommended: Option 1

Pre-processing is the safest because:
- No temp files to manage
- Works cross-platform (Windows/PowerShell too)
- Predictable behavior - secrets are resolved at invocation time
- Can log which secrets were accessed for audit trails

## Implementation Checklist

- [ ] Modify `exec_with_secrets()` to pre-process command string
- [ ] Add regex/escape handling for special characters in secrets
- [ ] Add test case `test_subshell_secret_access()`
- [ ] Update documentation: `docs/commands/run.md`
- [ ] Version bump: This is a bug fix, patch release (e.g., 0.5.1)
- [ ] Changelog entry: "Fix: Secrets now accessible in subshells and command substitutions"

## Workaround (Until Fix Released)

Users should avoid command substitutions inside `vibevault run`:

```bash
# ❌ DON'T (broken in current version)
vibevault run sh -c 'SECRET=$(vibevault get X); echo "$SECRET"'

# ✅ DO (workaround)
vibevault run sh -c 'echo "$X"'

# ✅ DO (alternative - separate calls)
vibevault run sh -c 'echo "$X"' | consumer_command
```
