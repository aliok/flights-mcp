# ✈️ Flights API

A REST API server for searching flights using Google Flights data, powered by [fast-flights](https://github.com/AWeirdDev/flights) and FastAPI.

## Setup

```bash
# Install Python 3.11
pyenv install 3.11.9
pyenv local 3.11.9

# Create virtual environment
$(pyenv which python) -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

## Running the Server

```bash
# Option 1: Run directly
python main.py

# Option 2: Run with uvicorn (with hot reload)
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

The server will start at `http://localhost:8000`

## 🎨 Test Web UI

A single-page HTML UI is included for testing the API. Simply open `test_ui.html` in your browser:

```bash
# Open the HTML file in your default browser
open test_ui.html  # macOS
# or
xdg-open test_ui.html  # Linux
# or just double-click test_ui.html
```

The UI includes:
- **Flight Search**: Search for flights with an intuitive form
- **Airport Search**: Find airports by name or city
- **Results Display**: Beautiful, easy-to-read flight results

**Note**: Make sure the API server is running on `http://localhost:8000` for the UI to work.

## 📚 Interactive API Documentation

FastAPI provides built-in interactive documentation:

| UI             | URL                         | Description                                        |
|----------------|-----------------------------|----------------------------------------------------|
| **Swagger UI** | http://localhost:8000/docs  | Interactive API explorer - test endpoints directly |
| **ReDoc**      | http://localhost:8000/redoc | Clean API reference documentation                  |

---

## API Endpoints

### Health Check

Check if the service is running.

**Request:**
```http
GET /api/health
```

**Response:**
```json
{
  "status": "ok"
}
```

**Example:**
```bash
curl http://localhost:8000/api/health
```

---

### Search Airports

Search for airports by name or city.

**Request:**
```http
GET /api/airports/search?q={query}
```

**Query Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `q` | string | Yes | Search query (city or airport name) |

**Response:**
```json
{
  "airports": [
    {
      "code": "TPE",
      "name": "TAIWAN_TAOYUAN_INTERNATIONAL_AIRPORT"
    },
    {
      "code": "TSA",
      "name": "TAIPEI_SONGSHAN_AIRPORT"
    }
  ]
}
```

**Examples:**
```bash
# Search for airports in Taipei
curl "http://localhost:8000/api/airports/search?q=taipei"

# Search for airports in Los Angeles
curl "http://localhost:8000/api/airports/search?q=angeles"

# Search for airports in Kayseri
curl "http://localhost:8000/api/airports/search?q=kayseri"
```

---

### Search Flights

Search for available flights based on criteria.

**Request:**
```http
POST /api/flights/search
Content-Type: application/json
```

**Request Body:**
```json
{
  "from_airport": "TPE",
  "to_airport": "LAX",
  "date": "2025-02-01",
  "return_date": null,
  "trip": "one-way",
  "airlines": ["DL", "AA"],
  "max_stops": 2,
  "seat": "economy",
  "passengers": {
    "adults": 1,
    "children": 0,
    "infants_in_seat": 0,
    "infants_on_lap": 0
  }
}
```

**Request Body Parameters:**

| Field                        | Type    | Required    | Description                                                                                                                            |
|------------------------------|---------|-------------|----------------------------------------------------------------------------------------------------------------------------------------|
| `from_airport`               | string  | Yes         | Departure airport (3-letter IATA code)                                                                                                 |
| `to_airport`                 | string  | Yes         | Arrival airport (3-letter IATA code)                                                                                                   |
| `date`                       | string  | Yes         | Outbound departure date (YYYY-MM-DD)                                                                                                   |
| `return_date`                | string  | Conditional | Return departure date (YYYY-MM-DD). Required for round-trip, must be null for one-way                                                  |
| `trip`                       | string  | Yes         | Trip type: `one-way` or `round-trip`                                                                                                   |
| `airlines`                   | array   | No          | **Note:** Airline filtering is not currently supported by the underlying fast_flights library. This parameter is accepted but ignored. |
| `max_stops`                  | integer | No          | Maximum number of stops. Applies to both outbound and return legs.                                                                     |
| `seat`                       | string  | No          | Seat class: `economy`, `premium-economy`, `business`, `first` (default: `economy`)                                                     |
| `passengers`                 | object  | No          | Passenger counts                                                                                                                       |
| `passengers.adults`          | integer | No          | Number of adults (default: 1, min: 1, max: 9)                                                                                          |
| `passengers.children`        | integer | No          | Number of children (default: 0)                                                                                                        |
| `passengers.infants_in_seat` | integer | No          | Number of infants in seat (default: 0)                                                                                                 |
| `passengers.infants_on_lap`  | integer | No          | Number of infants on lap (default: 0)                                                                                                  |
| `fetch_mode`                 | string  | No          | Fetch mode: `common` (default, standard scraping) or `local` (uses Playwright)                                                         |

**Constraints:**
- Total passengers cannot exceed 9
- Number of infants on lap cannot exceed number of adults
- One-way trips: `return_date` must be `null` or omitted
- Round-trip: `return_date` is required
- Single-leg searches only (A→B for one-way, A→B→A for round-trip)

**Fetch Modes:**
- `common` (default) - Standard web scraping using HTTP requests, fast and lightweight
- `local` - Uses local Playwright browser to render JavaScript (requires additional setup)

**Valid Airlines Values:**
- Any 2-letter IATA airline code (e.g., `DL`, `AA`, `UA`, `BA`)
- Alliance names: `SKYTEAM`, `STAR_ALLIANCE`, `ONEWORLD`

**Response:**
```json
{
  "current_price": "low",
  "flights": [
    {
      "is_best": true,
      "name": "Delta",
      "departure": "2025-02-01 10:30 AM",
      "arrival": "2025-02-01 6:45 PM",
      "arrival_time_ahead": "+0",
      "duration": "12h 15m",
      "stops": 1,
      "delay": null,
      "price": "$542"
    }
  ]
}
```

**Examples:**

```bash
# One-way flight search
curl -X POST "http://localhost:8000/api/flights/search" \
  -H "Content-Type: application/json" \
  -d '{
    "from_airport": "JFK",
    "to_airport": "LAX",
    "date": "2026-02-06",
    "trip": "one-way",
    "seat": "economy",
    "passengers": {
      "adults": 1
    }
  }'

# Round-trip flight search
curl -X POST "http://localhost:8000/api/flights/search" \
  -H "Content-Type: application/json" \
  -d '{
    "from_airport": "JFK",
    "to_airport": "LAX",
    "date": "2026-02-06",
    "return_date": "2026-02-13",
    "trip": "round-trip",
    "seat": "economy",
    "passengers": {
      "adults": 2,
      "children": 1
    }
  }'

# Business class with max stops filter
curl -X POST "http://localhost:8000/api/flights/search" \
  -H "Content-Type: application/json" \
  -d '{
    "from_airport": "SFO",
    "to_airport": "NRT",
    "date": "2026-02-06",
    "trip": "one-way",
    "max_stops": 1,
    "seat": "business",
    "passengers": {
      "adults": 1
    }
  }'

# Family trip with multiple passengers
curl -X POST "http://localhost:8000/api/flights/search" \
  -H "Content-Type: application/json" \
  -d '{
    "from_airport": "JFK",
    "to_airport": "LAX",
    "date": "2026-02-06",
    "trip": "one-way",
    "seat": "economy",
    "passengers": {
      "adults": 2,
      "children": 2,
      "infants_in_seat": 0,
      "infants_on_lap": 0
    }
  }'
```

---

## Common Airport Codes

| Code | Airport                      |
|------|------------------------------|
| JFK  | New York John F. Kennedy     |
| LAX  | Los Angeles International    |
| SFO  | San Francisco International  |
| ORD  | Chicago O'Hare               |
| LHR  | London Heathrow              |
| CDG  | Paris Charles de Gaulle      |
| NRT  | Tokyo Narita                 |
| HND  | Tokyo Haneda                 |
| TPE  | Taiwan Taoyuan International |
| ICN  | Seoul Incheon                |

---

## Error Responses

All endpoints return errors in this format:

```json
{
  "detail": "Error message describing what went wrong"
}
```

**HTTP Status Codes:**
| Code | Description |
|------|-------------|
| 200 | Success |
| 422 | Validation Error (invalid request body) |
| 500 | Internal Server Error |

---

## 🤖 MCP Integration

This API can be exposed via the Model Context Protocol (MCP) using [gen-mcp](https://github.com/genmcp/gen-mcp), allowing AI assistants to interact with the flight search API directly.

### Setup

1. **Download gen-mcp:**
   ```bash
   # Latest release version
   make download-genmcp-release
   
   # Or nightly snapshot
   make download-genmcp-nightly
   ```

2. **Start the API server:**
   ```bash
   python main.py
   ```

3. **Fetch OpenAPI spec:**
   ```bash
   make fetch-openapi
   # Or manually: curl http://localhost:8000/openapi.json > openapi.json
   ```

4. **Generate MCP configuration:**
   ```bash
   make generate-mcpfile
   ```
   This creates `mcpfile.yaml` from the OpenAPI spec with `invocationBases` configured.
   
   **Configure API URL** (optional, defaults to `http://localhost:8000`):
   ```bash
   API_URL=http://localhost:8000 make generate-mcpfile
   ```

5. **Start MCP server:**
   ```bash
   make start-mcp-server
   ```

6. **Stop MCP server:**
   ```bash
   make stop-mcp-server
   ```

### Available Make Targets

| Target                    | Description                                          |
|---------------------------|------------------------------------------------------|
| `download-genmcp-release` | Download latest release version of gen-mcp           |
| `download-genmcp-nightly` | Download nightly snapshot version of gen-mcp         |
| `fetch-openapi`           | Fetch OpenAPI spec from running API server           |
| `generate-mcpfile`        | Generate mcpfile.yaml from OpenAPI spec              |
| `start-mcp-server`        | Start the MCP server                                 |
| `stop-mcp-server`         | Stop the MCP server                                  |
| `view-logs`               | View recent logs from API and MCP servers            |
| `clean-genmcp`            | Remove downloaded gen-mcp binary and generated files |

### Logging

The API server logs all requests, responses, and fast-flights library calls:

- **API Server Logs**: `api-server.log` (also output to stdout)
- **MCP Server Logs**: `.genmcp/mcp-server.log`

**View logs:**
```bash
# View recent logs
make view-logs

# Follow API server logs in real-time
tail -f api-server.log
```

**What gets logged:**
- All HTTP requests and responses (method, path, status, timing)
- Request/response bodies (for debugging)
- Fast-flights library calls (function calls, parameters)
- Google Flights HTTP requests (via httpx/httpcore logging)
- Errors with full stack traces

### Files Generated

- `.genmcp/` - Directory containing the gen-mcp binary (not checked in)
- `mcpfile.yaml` - MCP tool definitions generated from OpenAPI spec (not checked in)
- `openapi.json` - OpenAPI specification (not checked in)

---

## License

MIT
