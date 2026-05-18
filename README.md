# AITestGen

Automatically generate XCTest unit tests for iOS and Swift projects using AI (Mistral).

AITestGen analyzes your Swift code, builds a dependency graph (RAG), and generates contextual unit tests that use the real types from your project.

## How it works

1. **Scanning** — finds all `.swift` files in the project, excluding existing tests, generated files, and AppDelegate
2. **RAG Indexing** — builds a local dependency index between types. If `LoginViewModel` uses `User` and `AuthService`, they are automatically included in the context
3. **Interactive selection** — displays available files and asks which ones to test
4. **Generation** — sends the code + dependencies to Mistral and writes the XCTest files

## Installation

### Prerequisites
- macOS 13+
- Xcode 15+
- [Mint](https://github.com/yonaskolb/Mint): `brew install mint`
- Mistral API key: [console.mistral.ai](https://console.mistral.ai)

### Install AITestGen
```bash
mint install MikiDev99/AITestGen
```

### Configure your PATH
Add Mint's bin folder to your PATH so you can run `aitestgen` from anywhere:
```bash
echo 'export PATH="$HOME/.mint/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### Configure your API key
Add this line to your `~/.zshrc` or `~/.bash_profile`:
```bash
export MISTRAL_API_KEY="your-key-here"
```
Then reload your terminal:
```bash
source ~/.zshrc
```

## Usage

```bash
cd /path/to/your/project
aitestgen
```

Follow the interactive menu to choose which files to test. Generated tests are saved inside your project folder.

### Available options

| Option | Description | Default |
|--------|-------------|---------|
| `--project` | Project directory | Current directory |
| `--model` | Mistral model to use | `mistral-large-latest` |
| `--output` | Output directory | Auto-detected test folder |
| `--all` | Generate tests for all files without prompting | `false` |

### Examples

```bash
# Project in current directory
aitestgen

# Specific project path
aitestgen --project /Users/you/Developer/MyProject

# All files using a specific model
aitestgen --all --model mistral-small-latest

# Custom output folder
aitestgen --output /Users/you/Desktop/Tests
```

### Available Mistral models

| Model | Quality | Speed | Cost |
|-------|---------|-------|------|
| `mistral-large-latest` | ⭐⭐⭐ | Slow | Higher |
| `mistral-small-latest` | ⭐⭐ | Fast | Lower |
| `codestral-latest` | ⭐⭐⭐ | Medium | Medium |

> **Tip:** `codestral-latest` is specifically trained on code and may produce better Swift tests.

## Xcode Integration (optional)

You can launch AITestGen directly from Xcode using a keyboard shortcut.

1. Copy the included script:
```bash
cp Scripts/aitestgen-xcode.sh ~/aitestgen-xcode.sh
chmod +x ~/aitestgen-xcode.sh
```

2. In Xcode: **Settings → Behaviors → +**
3. Name: `Generate AI Tests`
4. Assign a shortcut (e.g. `Cmd+Shift+T`)
5. Check **Run** and select `~/aitestgen-xcode.sh`

From that point, press the shortcut with a project open in Xcode and the tool launches automatically in Terminal.

## After generation

1. Tests are written directly into your existing test folder (e.g. `MyProjectTests/`)
2. If no test folder is found, they are saved in `AIGeneratedTests/` — drag it into your test target in Xcode
3. Build and run tests with `Cmd+U`

Thanks to RAG, generated tests use the real types from your project and compile without modifications in most cases.

## API costs

Mistral pricing is significantly lower than OpenAI. Approximate cost per file:

| Model | Cost per file |
|-------|--------------|
| `mistral-large-latest` | ~$0.002 |
| `mistral-small-latest` | ~$0.0005 |
| `codestral-latest` | ~$0.001 |

A project with 10 files costs approximately $0.005–$0.02 total.

## Project structure

```
AITestGen/
├── Sources/
│   ├── AITestGenCore/              # Shared logic
│   │   ├── ProjectScanner.swift    # Finds Swift files
│   │   ├── SwiftFileParser.swift   # AST parser via swift-syntax
│   │   ├── DependencyIndex.swift   # RAG dependency index
│   │   ├── InteractiveMenu.swift   # File selection menu
│   │   ├── LLMClient.swift         # Mistral API client
│   │   └── TestGenerator.swift     # Test generation
│   └── AITestGenTool/              # CLI entry point
│       └── main.swift
├── Scripts/
│   └── aitestgen-xcode.sh          # Xcode Behavior script
├── Tests/
│   └── AITestGenCoreTests/
├── Mintfile
└── Package.swift
```

## License

MIT
