"""
Flights REST API Server

A FastAPI-based REST API server for searching flights using the fast-flights library.
"""

import asyncio
import json
import logging
import sys
from typing import Literal, Optional
from fastapi import FastAPI, HTTPException, Query, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from pydantic import BaseModel, Field, model_validator
import time

from fast_flights import FlightData, Passengers, get_flights, search_airport

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler('api-server.log')
    ]
)

logger = logging.getLogger(__name__)

# Enable logging for fast-flights library
logging.getLogger('fast_flights').setLevel(logging.INFO)
logging.getLogger('fast_flights.core').setLevel(logging.DEBUG)
logging.getLogger('fast_flights.flights_impl').setLevel(logging.DEBUG)
logging.getLogger('fast_flights.search').setLevel(logging.DEBUG)

# Enable HTTP request logging for underlying libraries
logging.getLogger('httpx').setLevel(logging.INFO)
logging.getLogger('httpcore').setLevel(logging.INFO)
logging.getLogger('urllib3').setLevel(logging.INFO)
logging.getLogger('requests').setLevel(logging.INFO)

app = FastAPI(
    title="Flights API",
    description="""REST API for searching flights using Google Flights data.

This API allows you to:
- Search for flights between airports (one-way or round-trip)
- Find airports by name or city
- Filter flights by seat class, number of stops, and passenger counts

**Key Features:**
- Single-leg searches only (A→B for one-way, A→B→A for round-trip)
- Real-time flight data from Google Flights
- Support for multiple passenger types (adults, children, infants)
- Multiple seat classes (economy, premium-economy, business, first)

**Usage Tips:**
- Use airport search endpoint to find valid IATA codes before searching flights
- Dates should be in YYYY-MM-DD format
- Round-trip searches require both outbound and return dates
- Passenger counts are validated (max 9 total, infants on lap ≤ adults)
""",
    version="1.0.0",
)

# Enable CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allows all origins
    allow_credentials=True,
    allow_methods=["*"],  # Allows all methods
    allow_headers=["*"],  # Allows all headers
)


# Request/Response logging middleware
@app.middleware("http")
async def log_requests(request: Request, call_next):
    """Log all incoming requests and responses with full details."""
    start_time = time.time()
    
    # Log request
    logger.info(f"→ {request.method} {request.url.path}")
    logger.info(f"  Request headers: {dict(request.headers)}")
    if request.query_params:
        logger.info(f"  Query params: {dict(request.query_params)}")
    
    # Read body for logging (only for POST/PUT/PATCH)
    body_bytes = b""
    if request.method in ["POST", "PUT", "PATCH"]:
        body_bytes = await request.body()
        if body_bytes:
            try:
                body_json = json.loads(body_bytes)
                logger.info(f"  Request body: {json.dumps(body_json, indent=2)}")
            except:
                body_str = body_bytes.decode('utf-8', errors='replace')
                if len(body_str) > 1000:
                    logger.info(f"  Request body (raw, truncated): {body_str[:1000]}...")
                else:
                    logger.info(f"  Request body (raw): {body_str}")
        
        # Restore body for the endpoint
        async def receive():
            return {"type": "http.request", "body": body_bytes}
        
        request._receive = receive
    
    # Process request
    response = await call_next(request)
    
    # Log response headers
    logger.info(f"← {request.method} {request.url.path} - {response.status_code}")
    logger.info(f"  Response headers: {dict(response.headers)}")
    
    # Read response body for logging
    response_body = b""
    try:
        # Try to read the response body
        if hasattr(response, 'body_iterator'):
            # For streaming responses
            chunks = []
            async for chunk in response.body_iterator:
                chunks.append(chunk)
            response_body = b"".join(chunks)
            
            # Recreate response with the body we read
            from fastapi.responses import Response
            response = Response(
                content=response_body,
                status_code=response.status_code,
                headers=dict(response.headers),
                media_type=getattr(response, 'media_type', None)
            )
        elif hasattr(response, 'body'):
            response_body = response.body
    except Exception as e:
        logger.debug(f"  Could not read response body: {e}")
    
    if response_body:
        try:
            body_json = json.loads(response_body)
            logger.info(f"  Response body: {json.dumps(body_json, indent=2)}")
        except:
            body_str = response_body.decode('utf-8', errors='replace')
            if len(body_str) > 2000:
                logger.info(f"  Response body (truncated): {body_str[:2000]}...")
            else:
                logger.info(f"  Response body: {body_str}")
    
    process_time = time.time() - start_time
    logger.info(f"  Duration: {process_time:.3f}s")
    
    return response


# ============================================================================
# Request/Response Models
# ============================================================================


class PassengersRequest(BaseModel):
    """Passenger counts for flight search. Total passengers cannot exceed 9."""

    adults: int = Field(
        default=1,
        description="Number of adult passengers (age 12+). Required: at least 1 adult. Maximum: 9 adults.",
        ge=1,
        le=9,
        examples=[1, 2]
    )
    children: int = Field(
        default=0,
        description="Number of child passengers (age 2-11). Maximum: 8 children.",
        ge=0,
        le=8,
        examples=[0, 1, 2]
    )
    infants_in_seat: int = Field(
        default=0,
        description="Number of infants (under 2) traveling in their own seat. Maximum: 8 infants.",
        ge=0,
        le=8,
        examples=[0, 1]
    )
    infants_on_lap: int = Field(
        default=0,
        description="Number of infants (under 2) traveling on an adult's lap. Cannot exceed number of adults. Maximum: 8 infants.",
        ge=0,
        le=8,
        examples=[0, 1]
    )

    @model_validator(mode="after")
    def validate_passengers(self):
        total = self.adults + self.children + self.infants_in_seat + self.infants_on_lap
        if total > 9:
            raise ValueError("Total number of passengers cannot exceed 9")
        if self.infants_on_lap > self.adults:
            raise ValueError("Number of infants on lap cannot exceed number of adults")
        return self


class FlightSearchRequest(BaseModel):
    """Request body for searching flights. Supports single-leg searches only: one-way (A→B) or round-trip (A→B→A)."""

    from_airport: str = Field(
        ...,
        description="Departure airport IATA code (3-letter code, e.g., 'JFK', 'LAX', 'SFO'). Use the airport search endpoint to find valid codes.",
        examples=["JFK", "LAX", "SFO", "TPE"],
        min_length=3,
        max_length=3
    )
    to_airport: str = Field(
        ...,
        description="Arrival airport IATA code (3-letter code, e.g., 'JFK', 'LAX', 'SFO'). Use the airport search endpoint to find valid codes.",
        examples=["LAX", "JFK", "NRT", "CDG"],
        min_length=3,
        max_length=3
    )
    date: str = Field(
        ...,
        description="Outbound departure date in YYYY-MM-DD format. This is the date you want to fly from the departure airport. Example: '2026-02-06' for February 6, 2026.",
        examples=["2026-02-06", "2026-03-15"],
        pattern="^\\d{4}-\\d{2}-\\d{2}$"
    )
    return_date: Optional[str] = Field(
        default=None,
        description="Return departure date in YYYY-MM-DD format. Required when trip='round-trip', must be null or omitted when trip='one-way'. This is the date you want to fly back from the destination airport. Example: '2026-02-13' for February 13, 2026.",
        examples=["2026-02-13", "2026-03-20"],
        pattern="^\\d{4}-\\d{2}-\\d{2}$"
    )
    trip: Literal["one-way", "round-trip"] = Field(
        ...,
        description="Trip type: 'one-way' for a single flight leg (A→B), or 'round-trip' for outbound and return flights (A→B→A). For round-trip, return_date is required.",
        examples=["one-way", "round-trip"]
    )
    airlines: Optional[list[str]] = Field(
        default=None,
        description="⚠️ NOT CURRENTLY SUPPORTED: List of airline codes (2-letter IATA like 'DL', 'AA', 'UA') or alliances ('SKYTEAM', 'STAR_ALLIANCE', 'ONEWORLD'). This parameter is accepted but ignored by the underlying library. Filtering by airlines is not available at this time.",
        examples=[["DL", "AA"], ["STAR_ALLIANCE"], ["SKYTEAM", "ONEWORLD"]]
    )
    max_stops: Optional[int] = Field(
        default=None,
        description="Maximum number of stops allowed for the flight. Use 0 for direct flights only, 1 for flights with at most one stop, etc. Applies to both outbound and return legs. If not specified, flights with any number of stops will be returned.",
        ge=0,
        le=3,
        examples=[0, 1, 2]
    )
    seat: Literal["economy", "premium-economy", "business", "first"] = Field(
        default="economy",
        description="Seat class for the flight. Options: 'economy' (cheapest, standard seating), 'premium-economy' (more legroom and amenities), 'business' (premium service), 'first' (highest class). Default is 'economy'.",
        examples=["economy", "premium-economy", "business", "first"]
    )
    passengers: PassengersRequest = Field(
        default_factory=lambda: PassengersRequest(adults=1),
        description="Passenger counts including adults, children, and infants. Defaults to 1 adult if not specified. Total passengers cannot exceed 9."
    )
    fetch_mode: Literal["common", "local"] = Field(
        default="common",
        description="Data fetching mode. Use 'common' (default) for standard web scraping (fast, lightweight). Use 'local' only if 'common' fails (requires Playwright browser setup). Most users should use 'common'.",
        examples=["common", "local"]
    )

    @model_validator(mode="after")
    def validate_trip(self):
        if self.trip == "one-way":
            if self.return_date is not None:
                raise ValueError("One-way trip should not have a return_date")
        elif self.trip == "round-trip":
            if self.return_date is None:
                raise ValueError("Round-trip requires a return_date")

        return self


class FlightResponse(BaseModel):
    """Individual flight search result with details about a specific flight option."""

    is_best: bool = Field(
        description="Whether this flight is marked as one of the best options (typically based on price, duration, or other factors). Multiple flights can be marked as 'best'.",
        examples=[True, False]
    )
    name: str = Field(
        description="Name of the airline operating the flight (e.g., 'Delta', 'American', 'United', 'ZIPAIR Tokyo').",
        examples=["Delta", "American", "United", "ZIPAIR Tokyo"]
    )
    departure: str = Field(
        description="Departure time and date in human-readable format (e.g., '6:00 PM on Thu, Oct 1' or '10:40 AM on Fri, Feb 6').",
        examples=["6:00 PM on Thu, Oct 1", "10:40 AM on Fri, Feb 6"]
    )
    arrival: str = Field(
        description="Arrival time and date in human-readable format (e.g., '9:10 PM on Thu, Oct 1' or '3:00 PM on Sat, Feb 7'). May include next-day indicator if arrival is on a different day.",
        examples=["9:10 PM on Thu, Oct 1", "3:00 PM on Sat, Feb 7"]
    )
    arrival_time_ahead: str = Field(
        description="Indicates if arrival is on a different day. Empty string '' for same-day arrival, '+1' for next day, '+2' for day after next, etc.",
        examples=["", "+1", "+2"]
    )
    duration: str = Field(
        description="Total flight duration in human-readable format (e.g., '6 hr 10 min', '11 hr 15 min', '12 hr 59 min').",
        examples=["6 hr 10 min", "11 hr 15 min", "12 hr 59 min"]
    )
    stops: int = Field(
        description="Number of stops/connections on this flight route. 0 means direct flight (no stops), 1 means one stop, 2 means two stops, etc.",
        examples=[0, 1, 2],
        ge=0
    )
    delay: Optional[str] = Field(
        default=None,
        description="Delay information if the flight has any known delays or issues. null if no delay information is available.",
        examples=[None, "Delayed by 30 minutes"]
    )
    price: str = Field(
        description="Flight price in the local currency format (e.g., 'TRY 6531', '$542', '€450'). Includes currency symbol and amount.",
        examples=["TRY 6531", "$542", "€450"]
    )


class FlightSearchResponse(BaseModel):
    """Response containing flight search results with price indicator and list of available flights."""

    current_price: Optional[str] = Field(
        description="Price indicator showing whether current prices are 'low', 'typical', or 'high' compared to historical averages. null if price indicator is not available.",
        examples=["low", "typical", "high", None]
    )
    flights: list[FlightResponse] = Field(
        description="List of available flights matching the search criteria, sorted by relevance (best options typically appear first). Empty list if no flights are found.",
        examples=[[], [{"is_best": True, "name": "Delta", "departure": "6:00 PM on Thu, Oct 1", "arrival": "9:10 PM on Thu, Oct 1", "arrival_time_ahead": "", "duration": "6 hr 10 min", "stops": 0, "delay": None, "price": "TRY 6531"}]]
    )


class AirportResponse(BaseModel):
    """Airport information with IATA code and full name."""

    code: str = Field(
        description="Airport IATA code (3-letter code, e.g., 'JFK', 'LAX', 'TPE'). Use this code in flight search requests.",
        examples=["JFK", "LAX", "TPE", "NRT"]
    )
    name: str = Field(
        description="Full airport name in uppercase with underscores (e.g., 'NEW_YORK_JOHN_F_KENNEDY_INTERNATIONAL_AIRPORT', 'TAIWAN_TAOYUAN_INTERNATIONAL_AIRPORT'). Replace underscores with spaces for display.",
        examples=["NEW_YORK_JOHN_F_KENNEDY_INTERNATIONAL_AIRPORT", "TAIWAN_TAOYUAN_INTERNATIONAL_AIRPORT"]
    )


class AirportSearchResponse(BaseModel):
    """Response containing list of airports matching the search query."""

    airports: list[AirportResponse] = Field(
        description="List of airports matching the search query, limited to top 10 results. Empty list if no airports are found. Use these airport codes in flight search requests.",
        examples=[[], [{"code": "TPE", "name": "TAIWAN_TAOYUAN_INTERNATIONAL_AIRPORT"}, {"code": "TSA", "name": "TAIPEI_SONGSHAN_AIRPORT"}]]
    )


class HealthResponse(BaseModel):
    """Health check response."""

    status: str = Field(description="Service status")


# ============================================================================
# API Endpoints
# ============================================================================


@app.get("/api/health", response_model=HealthResponse, tags=["Health"], operation_id="health_check")
async def health_check():
    """Check if the service is running."""
    logger.info("Health check requested")
    return HealthResponse(status="ok")


@app.get("/api/airports/search", response_model=AirportSearchResponse, tags=["Airports"], operation_id="search_airports")
async def search_airports_endpoint(
    q: str = Query(
        ...,
        description="Search query for airport name or city. Can search by city name (e.g., 'taipei', 'los angeles'), airport name (e.g., 'kennedy', 'heathrow'), or partial matches. Returns up to 10 matching airports with their IATA codes.",
        min_length=1,
        examples=["taipei", "los angeles", "tokyo", "kayseri", "kennedy"]
    )
):
    """
    Search for airports by name or city.

    Use this endpoint to find valid IATA airport codes before searching for flights.
    Returns a list of matching airports (up to 10) with their 3-letter IATA codes and full names.
    
    **Example Usage:**
    - Search "taipei" → Returns TPE (Taiwan Taoyuan) and TSA (Taipei Songshan)
    - Search "los angeles" → Returns LAX (Los Angeles International)
    - Search "kennedy" → Returns JFK (New York John F. Kennedy)
    
    **Tips:**
    - Use the returned IATA codes in flight search requests
    - Search is case-insensitive
    - Partial matches work (e.g., "angeles" finds Los Angeles)
    """
    logger.info(f"Searching airports with query: {q}")
    try:
        logger.debug(f"Calling fast_flights.search_airport('{q}')")
        results = search_airport(q)
        logger.info(f"Found {len(results)} airport(s) matching '{q}'")
        
        airports = []
        for airport in results[:10]:  # Limit to 10 results
            # Airport enum has name attribute that gives the enum member name
            # and value that gives the IATA code
            airports.append(
                AirportResponse(
                    code=airport.value,
                    name=airport.name,
                )
            )
            logger.debug(f"  Airport: {airport.value} - {airport.name}")
        
        logger.info(f"Returning {len(airports)} airport(s)")
        return AirportSearchResponse(airports=airports)
    except Exception as e:
        logger.error(f"Error searching airports: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Error searching airports: {str(e)}")


@app.post("/api/flights/search", response_model=FlightSearchResponse, tags=["Flights"], operation_id="search_flights")
async def search_flights(request: FlightSearchRequest):
    """
    Search for flights between airports based on the provided criteria.

    **Supported Trip Types:**
    - **One-way**: Single flight leg from departure to arrival airport (A→B)
    - **Round-trip**: Outbound flight (A→B) and return flight (B→A) on specified dates
    
    **Important Constraints:**
    - Single-leg searches only (no multi-city trips)
    - For round-trip, return_date is required and must reverse the route
    - Airport codes must be valid 3-letter IATA codes (use airport search endpoint to find them)
    - Dates must be in YYYY-MM-DD format
    - Total passengers cannot exceed 9
    - Infants on lap cannot exceed number of adults
    
    **Response:**
    Returns a list of available flights with details including:
    - Airline name, departure/arrival times, duration, stops, and price
    - Price indicator (low/typical/high) compared to historical averages
    - Best flight options marked with is_best flag
    
    **Example Workflow:**
    1. Search for airports: GET /api/airports/search?q=taipei
    2. Use airport codes in flight search: POST /api/flights/search with from_airport="TPE", to_airport="LAX"
    
    **Note:** Airline filtering (airlines parameter) is not currently supported and will be ignored.
    """
    logger.info("Flight search requested")
    logger.info(f"  Trip type: {request.trip}")
    logger.info(f"  Seat class: {request.seat}")
    logger.info(f"  Fetch mode: {request.fetch_mode}")
    logger.info(f"  Passengers: {request.passengers.adults} adults, {request.passengers.children} children, "
                f"{request.passengers.infants_in_seat} infants (seat), {request.passengers.infants_on_lap} infants (lap)")
    
    try:
        # Convert request to fast-flights format
        flight_data_list = []
        
        # Outbound leg
        logger.info(f"  Outbound: {request.from_airport} → {request.to_airport} on {request.date}")
        outbound_kwargs = {
            "date": request.date,
            "from_airport": request.from_airport,
            "to_airport": request.to_airport,
        }
        if request.airlines:
            logger.warning(f"    Airlines filter not supported by fast_flights library: {request.airlines}")
        if request.max_stops is not None:
            logger.info(f"    Max stops: {request.max_stops}")
            outbound_kwargs["max_stops"] = request.max_stops
        
        flight_data_list.append(FlightData(**outbound_kwargs))
        
        # Return leg (for round-trip)
        if request.trip == "round-trip" and request.return_date:
            logger.info(f"  Return: {request.to_airport} → {request.from_airport} on {request.return_date}")
            return_kwargs = {
                "date": request.return_date,
                "from_airport": request.to_airport,
                "to_airport": request.from_airport,
            }
            if request.max_stops is not None:
                return_kwargs["max_stops"] = request.max_stops
            
            flight_data_list.append(FlightData(**return_kwargs))

        passengers = Passengers(
            adults=request.passengers.adults,
            children=request.passengers.children,
            infants_in_seat=request.passengers.infants_in_seat,
            infants_on_lap=request.passengers.infants_on_lap,
        )

        # Perform the search
        logger.info(f"Calling fast_flights.get_flights() with fetch_mode='{request.fetch_mode}'")
        logger.debug(f"  Flight data: {[{'date': fd.date, 'from': fd.from_airport, 'to': fd.to_airport} for fd in flight_data_list]}")
        logger.debug(f"  Passengers: adults={request.passengers.adults}, children={request.passengers.children}, "
                    f"infants_in_seat={request.passengers.infants_in_seat}, infants_on_lap={request.passengers.infants_on_lap}")
        
        search_start_time = time.time()
        
        # Run in thread pool if using local mode (Playwright), otherwise run directly
        if request.fetch_mode == "local":
            def _search_flights():
                logger.info("Executing get_flights in thread pool (local mode)")
                return get_flights(
                    flight_data=flight_data_list,
                    trip=request.trip,
                    seat=request.seat,
                    passengers=passengers,
                    fetch_mode=request.fetch_mode,
                )
            result = await asyncio.to_thread(_search_flights)
        else:
            logger.info("Executing get_flights directly (common mode)")
            result = get_flights(
                flight_data=flight_data_list,
                trip=request.trip,
                seat=request.seat,
                passengers=passengers,
                fetch_mode=request.fetch_mode,
            )
        
        search_duration = time.time() - search_start_time
        logger.info(f"fast_flights.get_flights() completed in {search_duration:.3f}s")
        logger.info(f"Found {len(result.flights)} flight(s)")
        logger.info(f"Current price indicator: {result.current_price}")

        # Convert result to response format
        flights = []
        for idx, flight in enumerate(result.flights):
            # Handle stops field - sometimes it can be "Unknown" string instead of int
            stops_value = flight.stops
            if isinstance(stops_value, str) and stops_value.lower() == "unknown":
                stops_value = 0
            elif not isinstance(stops_value, int):
                try:
                    stops_value = int(stops_value)
                except (ValueError, TypeError):
                    stops_value = 0
            
            logger.debug(f"  Flight {idx + 1}: {flight.name} - {flight.departure} → {flight.arrival} - {flight.price} ({stops_value} stops)")
            flights.append(
                FlightResponse(
                    is_best=flight.is_best,
                    name=flight.name,
                    departure=flight.departure,
                    arrival=flight.arrival,
                    arrival_time_ahead=flight.arrival_time_ahead,
                    duration=flight.duration,
                    stops=stops_value,
                    delay=getattr(flight, "delay", None),
                    price=flight.price,
                )
            )

        logger.info(f"Returning {len(flights)} flight(s) in response")
        return FlightSearchResponse(
            current_price=result.current_price,
            flights=flights,
        )

    except Exception as e:
        logger.error(f"Error searching flights: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Error searching flights: {str(e)}")


# ============================================================================
# Main Entry Point
# ============================================================================

if __name__ == "__main__":
    import uvicorn
    
    logger.info("Starting Flights API server on http://0.0.0.0:8000")
    logger.info("Logs will be written to api-server.log and stdout")
    
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8000,
        log_config=None,  # Use our custom logging
        access_log=True,
    )

