# Refact Setup for The Mineral Guide

This document explains how Refact has been set up for The Mineral Guide project.

## Configuration Files

The following configuration files have been created:

1. `.refact.yaml` - Main Refact configuration file
2. `.refactignore` - Specifies files and directories to be ignored by Refact
3. `.vscode/settings.json` - VS Code settings for Refact (updated)
4. `.vscode/extensions.json` - VS Code extension recommendations (updated)

## Getting Started with Refact

### 1. Install the Refact Extension

Install the Refact extension for VS Code:

1. Open VS Code
2. Go to Extensions (Ctrl+Shift+X)
3. Search for "Refact"
4. Install the "Refact" extension by Refact Studio

### 2. Set Up Your API Key

You need to replace the placeholder API key in the VS Code settings:

1. Sign up for a Refact account at [https://refact.ai/](https://refact.ai/)
2. Get your API key from your Refact account
3. Replace `${REFACT_API_KEY}` in `.vscode/settings.json` with your actual API key

### 3. Verify the Configuration

The Refact extension should now be configured with:

- Your GitHub repository: `Blak-42069/The_Mineral_Guide`
- Your Supabase project: `kkcseqmpgzzrogatdoqi`
- The appropriate file patterns for analysis and completion

## Features Enabled

- **Code Completion**: Refact will provide AI-powered code completions as you type
- **Code Analysis**: Refact will analyze your code for potential issues
- **GitHub Integration**: Refact is connected to your GitHub repository
- **Supabase Integration**: Refact is configured with your Supabase project details

## Excluded Files

The `.refactignore` file excludes:

- Build directories
- Generated files
- Dependencies
- Large binary files
- Logs
- IDE files
- Temporary files

## Troubleshooting

If you encounter issues with Refact:

1. Ensure the extension is properly installed
2. Verify your API key is correctly set in VS Code settings
3. Check the Refact output channel in VS Code for error messages
4. Restart VS Code if necessary

For more help, visit the [Refact documentation](https://docs.refact.ai/).
