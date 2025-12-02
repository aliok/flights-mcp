.PHONY: help download-genmcp-release download-genmcp-nightly fetch-openapi generate-mcpfile start-mcp-server stop-mcp-server view-logs clean-genmcp

# Default target
help:
	@echo "Available targets:"
	@echo "  download-genmcp-release  - Download latest release version of gen-mcp"
	@echo "  download-genmcp-nightly  - Download nightly snapshot version of gen-mcp"
	@echo "  fetch-openapi           - Fetch OpenAPI spec from running API server"
	@echo "  generate-mcpfile        - Generate mcpfile.yaml from OpenAPI spec"
	@echo "  start-mcp-server         - Start the MCP server"
	@echo "  stop-mcp-server         - Stop the MCP server"
	@echo "  clean-genmcp            - Remove downloaded gen-mcp binary and generated files"

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

