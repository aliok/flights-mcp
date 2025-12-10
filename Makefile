.PHONY: help download-genmcp-release download-genmcp-nightly fetch-openapi generate-mcpfile start-mcp-server stop-mcp-server view-logs clean-genmcp download-gevals-release download-gevals-nightly run-gevals-eval check-gevals-services clean-gevals setup-judge-env

# Default target
help:
	@echo "Available targets:"
	@echo ""
	@echo "MCP Server:"
	@echo "  download-genmcp-release  - Download latest release version of gen-mcp"
	@echo "  download-genmcp-nightly  - Download nightly snapshot version of gen-mcp"
	@echo "  fetch-openapi           - Fetch OpenAPI spec from running API server"
	@echo "  generate-mcpfile        - Generate mcpfile.yaml from OpenAPI spec"
	@echo "  start-mcp-server         - Start the MCP server"
	@echo "  stop-mcp-server         - Stop the MCP server"
	@echo "  view-logs               - View recent logs from API and MCP servers"
	@echo "  clean-genmcp            - Remove downloaded gen-mcp binary and generated files"
	@echo ""
	@echo "gevals Evaluation:"
	@echo "  download-gevals-release - Download latest release version of gevals"
	@echo "  download-gevals-nightly - Download nightly snapshot version of gevals"
	@echo "  setup-judge-env         - Setup LLM judge environment variables"
	@echo "  run-gevals-eval         - Run gevals evaluation (requires services running)"
	@echo "  check-gevals-services   - Check if required services are running"
	@echo "  clean-gevals            - Remove downloaded gevals binary"

download-genmcp-release:
	@bash scripts/download-genmcp-release.sh

download-genmcp-nightly:
	@bash scripts/download-genmcp-nightly.sh

fetch-openapi:
	@bash scripts/fetch-openapi.sh

generate-mcpfile:
	@bash scripts/generate-mcpfile.sh

start-mcp-server:
	@bash scripts/start-mcp-server.sh

stop-mcp-server:
	@bash scripts/stop-mcp-server.sh

view-logs:
	@bash scripts/view-logs.sh

clean-genmcp:
	@echo "Cleaning gen-mcp files..."
	@rm -rf .genmcp
	@rm -f mcpfile.yaml
	@echo "Cleaned."

download-gevals-release:
	@bash scripts/download-gevals-release.sh

download-gevals-nightly:
	@bash scripts/download-gevals-nightly.sh

setup-judge-env:
	@bash scripts/setup-judge-env.sh

run-gevals-eval:
	@bash scripts/run-gevals-eval.sh

check-gevals-services:
	@bash scripts/check-gevals-services.sh

clean-gevals:
	@echo "Cleaning gevals files..."
	@rm -rf .gevals
	@echo "Cleaned."

