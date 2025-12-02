"""
Flights REST API Server

A FastAPI-based REST API server for searching flights using the fast-flights library.
"""

from typing import Optional
from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel, Field, model_validator

from fast_flights import FlightData, Passengers, get_flights, search_airport

app = FastAPI(
    title="Flights API",
    description="REST API for searching flights using Google Flights data",
    version="1.0.0",
)


# ============================================================================
# Request/Response Models
# ============================================================================


class FlightDataRequest(BaseModel):
    """Flight segment data for search request."""

    date: str = Field(..., description="Departure date in YYYY-MM-DD format", examples=["2025-01-01"])
    from_airport: str = Field(..., description="Departure airport code (3-letter IATA)", examples=["TPE"])
    to_airport: str = Field(..., description="Arrival airport code (3-letter IATA)", examples=["MYJ"])
    airlines: Optional[list[str]] = Field(
        default=None,
        description="List of airline codes (2-letter IATA) or alliances (SKYTEAM, STAR_ALLIANCE, ONEWORLD)",
        examples=[["DL", "AA", "STAR_ALLIANCE"]],
    )
    max_stops: Optional[int] = Field(default=None, description="Maximum number of stops", ge=0)


class PassengersRequest(BaseModel):
    """Passenger counts for search request."""

    adults: int = Field(default=1, description="Number of adult passengers", ge=1, le=9)
    children: int = Field(default=0, description="Number of child passengers", ge=0, le=8)
    infants_in_seat: int = Field(default=0, description="Number of infants in seat", ge=0, le=8)
    infants_on_lap: int = Field(default=0, description="Number of infants on lap", ge=0, le=8)

    @model_validator(mode="after")
    def validate_passengers(self):
        total = self.adults + self.children + self.infants_in_seat + self.infants_on_lap
        if total > 9:
            raise ValueError("Total number of passengers cannot exceed 9")
        if self.infants_on_lap > self.adults:
            raise ValueError("Number of infants on lap cannot exceed number of adults")
        return self


class FlightSearchRequest(BaseModel):
    """Request body for flight search."""

    flight_data: list[FlightDataRequest] = Field(
        ..., description="List of flight segments", min_length=1
    )
    trip: str = Field(
        ..., description="Trip type", examples=["one-way", "round-trip"]
    )
    seat: str = Field(
        default="economy",
        description="Seat class",
        examples=["economy", "premium-economy", "business", "first"],
    )
    passengers: PassengersRequest = Field(
        default_factory=lambda: PassengersRequest(adults=1)
    )

    @model_validator(mode="after")
    def validate_trip(self):
        valid_trips = ["one-way", "round-trip"]
        if self.trip not in valid_trips:
            raise ValueError(f"Trip must be one of: {', '.join(valid_trips)}")

        valid_seats = ["economy", "premium-economy", "business", "first"]
        if self.seat not in valid_seats:
            raise ValueError(f"Seat must be one of: {', '.join(valid_seats)}")

        if self.trip == "round-trip" and len(self.flight_data) < 2:
            raise ValueError("Round-trip requires at least 2 flight segments")

        return self


class FlightResponse(BaseModel):
    """Individual flight result."""

    is_best: bool = Field(description="Whether this is the best flight option")
    name: str = Field(description="Airline name")
    departure: str = Field(description="Departure time")
    arrival: str = Field(description="Arrival time")
    arrival_time_ahead: str = Field(description="Days ahead for arrival")
    duration: str = Field(description="Flight duration")
    stops: int = Field(description="Number of stops")
    delay: Optional[str] = Field(default=None, description="Delay information if any")
    price: str = Field(description="Flight price")


class FlightSearchResponse(BaseModel):
    """Response for flight search."""

    current_price: Optional[str] = Field(description="Current price level (low/typical/high)")
    flights: list[FlightResponse] = Field(description="List of available flights")


class AirportResponse(BaseModel):
    """Airport information."""

    code: str = Field(description="Airport IATA code")
    name: str = Field(description="Airport name")


class AirportSearchResponse(BaseModel):
    """Response for airport search."""

    airports: list[AirportResponse] = Field(description="List of matching airports")


class HealthResponse(BaseModel):
    """Health check response."""

    status: str = Field(description="Service status")


# ============================================================================
# API Endpoints
# ============================================================================


@app.get("/api/health", response_model=HealthResponse, tags=["Health"])
async def health_check():
    """Check if the service is running."""
    return HealthResponse(status="ok")


@app.get("/api/airports/search", response_model=AirportSearchResponse, tags=["Airports"])
async def search_airports_endpoint(
    q: str = Query(..., description="Search query for airport name or city", min_length=1)
):
    """
    Search for airports by name or city.

    Returns a list of matching airports with their IATA codes.
    """
    try:
        results = search_airport(q)
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
        return AirportSearchResponse(airports=airports)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error searching airports: {str(e)}")


@app.post("/api/flights/search", response_model=FlightSearchResponse, tags=["Flights"])
async def search_flights(request: FlightSearchRequest):
    """
    Search for flights based on the provided criteria.

    Supports one-way and round-trip searches with various seat classes
    and passenger configurations.
    """
    try:
        # Convert request to fast-flights format
        flight_data_list = []
        for fd in request.flight_data:
            flight_data_kwargs = {
                "date": fd.date,
                "from_airport": fd.from_airport,
                "to_airport": fd.to_airport,
            }
            if fd.airlines:
                flight_data_kwargs["airlines"] = fd.airlines
            if fd.max_stops is not None:
                flight_data_kwargs["max_stops"] = fd.max_stops

            flight_data_list.append(FlightData(**flight_data_kwargs))

        passengers = Passengers(
            adults=request.passengers.adults,
            children=request.passengers.children,
            infants_in_seat=request.passengers.infants_in_seat,
            infants_on_lap=request.passengers.infants_on_lap,
        )

        # Perform the search
        result = get_flights(
            flight_data=flight_data_list,
            trip=request.trip,
            seat=request.seat,
            passengers=passengers,
            fetch_mode="fallback",
        )

        # Convert result to response format
        flights = []
        for flight in result.flights:
            flights.append(
                FlightResponse(
                    is_best=flight.is_best,
                    name=flight.name,
                    departure=flight.departure,
                    arrival=flight.arrival,
                    arrival_time_ahead=flight.arrival_time_ahead,
                    duration=flight.duration,
                    stops=flight.stops,
                    delay=getattr(flight, "delay", None),
                    price=flight.price,
                )
            )

        return FlightSearchResponse(
            current_price=result.current_price,
            flights=flights,
        )

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error searching flights: {str(e)}")


# ============================================================================
# Main Entry Point
# ============================================================================

if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)

