# AITestGen

Automatically generate XCTest unit tests and analyze crash logs for iOS and Swift projects using AI.

AITestGen analyzes your Swift code, builds a dependency graph (RAG), and generates contextual unit tests that use the real types from your project. It can also analyze Firebase Crashlytics crash logs to identify root causes and suggest fixes.

## How it works

### Unit Test Generation
1. **Scanning** — finds all `.swift` files in the project, excluding existing tests, generated files, and AppDelegate
2. **RAG Indexing** — builds a local dependency index between types. If `LoginViewModel` uses `User` and `AuthService`, they are automatically included in the context
3. **Interactive selection** — displays available files and asks which ones to test
4. **Generation** — sends the code + dependencies to the AI model and writes the XCTest files

### Crash Analysis
1. **Parsing** — reads a Firebase Crashlytics crash log and extracts the crashed thread
2. **RAG lookup** — finds the source files involved in the crash inside your project
3. **Analysis** — sends the stack trace + source code to the AI model
4. **Output** — returns root cause, affected files with line numbers, and a concrete fix

## Installation

### Prerequisites
- macOS 13+
- Xcode 15+
- [Mint](https://github.com/yonaskolb/Mint): `brew install mint`
- An API key from [NVIDIA NIM](https://build.nvidia.com/models)

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

### Generate unit tests
```bash
cd /path/to/your/project
aitestgen
```

Follow the interactive menu to choose which files to test. Generated tests are written directly into your existing test folder (e.g. `MyProjectTests/`). If no test folder is found, they are saved in `AIGeneratedTests/`.

### Analyze a crash log
```bash
cd /path/to/your/project
aitestgen crash --crash-log /path/to/crash.txt
```

Export the crash log as `.txt` from Firebase Crashlytics and pass it with `--crash-log`. The tool will identify the root cause and suggest a fix. After the analysis, run `aitestgen` to generate tests for the affected files.

## Available options

### aitestgen (unit test generation)

| Option | Description | Default |
|--------|-------------|---------|
| `--project` | Project directory | Current directory |
| `--model` | AI model to use | `mistral-large-latest` |
| `--output` | Output directory | Auto-detected test folder |
| `--all` | Generate tests for all files without prompting | `false` |

### aitestgen crash (crash analysis)

| Option | Description | Default |
|--------|-------------|---------|
| `--crash-log` | Path to the crash log .txt file | Required |
| `--project` | Project directory | Current directory |
| `--model` | AI model to use | `mistral-large-latest` |

## Examples

```bash
# Generate tests for current project
aitestgen

# Generate tests for a specific project
aitestgen --project /Users/you/Developer/MyProject

# Generate tests for all files using a specific model
aitestgen --all --model moonshotai/kimi-k2.6

# Analyze a crash log
aitestgen crash --crash-log ~/Downloads/crash.txt

# Analyze a crash log for a specific project
aitestgen crash --crash-log ~/Downloads/crash.txt --project /Users/you/Developer/MyProject
```

### Available models

You can use any model available on [NVIDIA NIM](https://build.nvidia.com/models). Pass the model name via `--model`.

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

## After generation

1. Tests are written directly into your existing test folder (e.g. `MyProjectTests/`)
2. If no test folder is found, they are saved in `AIGeneratedTests/` — drag it into your test target in Xcode
3. Build and run tests with `Cmd+U`

## Project structure

```
AITestGen/
├── Sources/
│   ├── AITestGenCore/              # Shared logic
│   │   ├── ProjectScanner.swift    # Finds Swift files
│   │   ├── SwiftFileParser.swift   # AST parser via swift-syntax
│   │   ├── DependencyIndex.swift   # RAG dependency index
│   │   ├── InteractiveMenu.swift   # File selection menu
│   │   ├── LLMClient.swift         # AI API client
│   │   ├── TestGenerator.swift     # Test generation
│   │   ├── CrashLogParser.swift    # Crash log parser
│   │   └── CrashAnalyzer.swift     # Crash analysis
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
