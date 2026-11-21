# BDD: app shows secrets written by the CLI

Feature: running app reflects external vault writes
  Scenario: CLI adds a secret while the app is open
    Given the app is running and has loaded the secret list
    When another process runs `vibevault add NAME`
    Then the app's secret list contains NAME within a bounded time (<= 5s) without restart or manual action

  Scenario: write path announces the change
    When VaultService adds/updates/deletes a secret
    Then a DistributedNotification `dev.vibevault.vault-changed` is posted so open apps reload immediately

Tests: apps/VibeVaultAppTests/ExternalVaultWriteRefreshTests.swift
Run: swift test --filter ExternalVaultWriteRefreshTests
