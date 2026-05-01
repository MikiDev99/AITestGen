# AITestGen

Automatically generate XCTest unit tests for iOS and Swift projects using AI (GPT-4o).

AITestGen analyzes your Swift code, builds a dependency graph (RAG), and generates contextual unit tests that use the real types from your project.

## How it works

1. **Scanning** — finds all `.swift` files in the project, excluding existing tests, generated files, and AppDelegate
2. **RAG Indexing** — builds a local dependency index between types. If `LoginViewModel` uses `User` and `AuthService`, they are automatically included in the context
3. **Interactive selection** — displays available files and asks which ones to test
4. **Generation** — sends the code + dependencies to GPT-4o and writes the XCTest files

## Installation

### Prerequisites
- macOS 13+
- Xcode 15+
- [Mint](https://github.com/yonaskolb/Mint): `brew install mint`
- OpenAI API key: [platform.openai.com](https://platform.openai.com)

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
export OPENAI_API_KEY="sk-..."
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

Follow the interactive menu to choose which files to test. Generated tests are saved in `AIGeneratedTests/` inside your project folder.

### Available options

| Option | Description | Default |
|--------|-------------|---------|
| `--project` | Project directory | Current directory |
| `--model` | GPT model to use | `gpt-4o` |
| `--output` | Output directory | `AIGeneratedTests/` |
| `--all` | Generate tests for all files without prompting | `false` |

### Examples

```bash
# Project in current directory
aitestgen

# Specific project path
aitestgen --project /Users/you/Developer/MyProject

# All files using gpt-4o-mini (cheaper)
aitestgen --all --model gpt-4o-mini

# Custom output folder
aitestgen --output /Users/you/Desktop/Tests
```

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

1. Open Xcode in your project
2. Drag the `AIGeneratedTests/` folder into your test target
3. Build and run tests with `Cmd+U`

Thanks to RAG, generated tests use the real types from your project and compile without modifications in most cases.

## API costs

With `gpt-4o` the cost is approximately $0.005 per file. A project with 10 files costs around $0.05.

To cap your spending, set a usage limit at [platform.openai.com/usage](https://platform.openai.com/usage).

To reduce costs, use `--model gpt-4o-mini`:
```bash
aitestgen --model gpt-4o-mini
```

## Project structure

```
AITestGen/
├── Sources/
│   ├── AITestGenCore/              # Shared logic
│   │   ├── ProjectScanner.swift    # Finds Swift files
│   │   ├── SwiftFileParser.swift   # AST parser via swift-syntax
│   │   ├── DependencyIndex.swift   # RAG dependency index
│   │   ├── InteractiveMenu.swift   # File selection menu
│   │   ├── GPTClient.swift         # OpenAI client
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
