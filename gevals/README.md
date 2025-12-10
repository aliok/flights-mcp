# Flights MCP Evaluation with gevals

This directory contains evaluation configurations for testing the Flights MCP server using the [gevals](https://github.com/genmcp/gevals) framework.

## Prerequisites

1. **LLM Judge Configuration** (Required): The evaluation uses an LLM judge for semantic verification of task completion. You must configure the judge credentials before running evaluations.

   ```bash
   # Option 1: Using environment variables (recommended)
   export JUDGE_BASE_URL="your-judge-api-url"
   export JUDGE_API_KEY="your-api-key"
   export JUDGE_MODEL_NAME="your-model-name"
   
   # Option 2: Using .env file
   # Copy .env.example to .env and fill in your credentials
   cp .env.example .env
   # Edit .env with your credentials
   source .env
   ```

   **Note**: Judge credentials are sensitive and should never be committed to the repository. Use environment variables or a `.env` file (which is gitignored).

2. **gevals binary**: Download using make target (recommended) or manually
   ```bash
   # Using make (recommended)
   make download-gevals-release
   
   # Or manually download from [releases](https://github.com/genmcp/gevals/releases)
   curl -L https://github.com/genmcp/gevals/releases/download/v0.0.1/gevals-darwin-amd64.zip -o gevals.zip
   unzip gevals.zip
   chmod +x gevals-darwin-amd64
   mv gevals-darwin-amd64 gevals
   ```

3. **API Server Running**: The API server must be running on `http://localhost:8000`.

See the project root README for instructions.
   

4. **MCP Server Setup and Running**: The gen-mcp server must be running on `http://localhost:8080`.

See the project root README for instructions.
      
The MCP server will be available at `http://localhost:8080/mcp`.


5. **Claude Code**:
   - Install Claude Code CLI
   - Ensure it's in your PATH

## LLM Judge

The evaluation is configured to use an LLM judge for semantic verification of task completion. This provides more sophisticated verification than simple text matching.

### How It Works

The LLM judge uses semantic matching to verify task completion:

- **`contains` mode**: Checks if the agent's response semantically contains the expected information
- **`exact` mode**: Checks if the response is semantically equivalent to the expected answer

Example from task files:
```yaml
steps:
  verify:
    contains: "airport code TPE"  # LLM judge checks if response contains this semantically
```

The judge evaluates whether the agent's response includes the required information, even if phrased differently.

### Configuration

The LLM judge is configured in `eval.yaml` using environment variables:
- `JUDGE_BASE_URL`: The base URL for the judge API
- `JUDGE_API_KEY`: Your API key for authentication
- `JUDGE_MODEL_NAME`: The model name to use for judging

These variables must be set before running evaluations. The evaluation will fail if they are not configured.

## Directory Structure

```
gevals/
├── README.md              # This file
├── eval.yaml              # Main evaluation configuration
├── mcp-config.yaml        # MCP server configuration for gevals
├── agents/                # Agent configuration files
│   └── claude-code.yaml
└── tasks/                 # Test tasks
    └── search-airports/
```

## Running Evaluations

### Using Make Targets (Recommended)

```bash
# Download gevals binary (first time only)
make download-gevals-release

# Setup judge environment variables (required)
# Make sure JUDGE_BASE_URL, JUDGE_API_KEY, and JUDGE_MODEL_NAME are set
export JUDGE_BASE_URL="your-judge-api-url"
export JUDGE_API_KEY="your-api-key"
export JUDGE_MODEL_NAME="your-model-name"

# Check if services are running
make check-gevals-services

# Run all evaluations
make run-gevals-eval
```

### Direct Usage

```bash
# Ensure judge environment variables are set first
export JUDGE_BASE_URL="your-judge-api-url"
export JUDGE_API_KEY="your-api-key"
export JUDGE_MODEL_NAME="your-model-name"

# Run all tasks with Claude Code agent
./gevals eval gevals/eval.yaml

# Or using the helper script
./gevals/run-eval.sh
```

### Output

Results are saved to `gevals-flights-mcp-evaluation-out.json` by default.

View results:
```bash
cat gevals-flights-mcp-evaluation-out.json | jq
```
