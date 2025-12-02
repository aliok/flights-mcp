# Repository Summary
Repository: AWeirdDev/flights (ref: main)
Total files included: 6
Ignored files: 36
Approximate token count: 5011

# Directory Structure
├── README.md
└── docs
├── airports.md
├── fallbacks.md
├── filters.md
├── index.md
└── local.md

================================================
FILE: README.md
================================================
Try out the dev version: [**Pypi (`3.0rc0`)**](https://pypi.org/project/fast-flights/3.0rc0/)

<br /><br /><br />
<div align="center">

# ✈️ fast-flights

The fast and strongly-typed Google Flights scraper (API) implemented in Python. Based on Base64-encoded Protobuf string.

[**Documentation**](https://aweirddev.github.io/flights) • [Issues](https://github.com/AWeirdDev/flights/issues) • [PyPi](https://pypi.org/project/fast-flights)

```haskell
$ pip install fast-flights
```

</div>

## Basics
**TL;DR**: To use `fast-flights`, you'll first create a filter (for `?tfs=`) to perform a request.
Then, add `flight_data`, `trip`, `seat`, `passengers` to use the API directly.

```python
from fast_flights import FlightData, Passengers, Result, get_flights

result: Result = get_flights(
    flight_data=[
        FlightData(date="2025-01-01", from_airport="TPE", to_airport="MYJ")
    ],
    trip="one-way",
    seat="economy",
    passengers=Passengers(adults=2, children=1, infants_in_seat=0, infants_on_lap=0),
    fetch_mode="fallback",
)

print(result)

# The price is currently... low/typical/high
print("The price is currently", result.current_price)
```

**Properties & usage for `Result`**:

```python
result.current_price

# Get the first flight
flight = result.flights[0]

flight.is_best
flight.name
flight.departure
flight.arrival
flight.arrival_time_ahead
flight.duration
flight.stops
flight.delay?  # may not be present
flight.price
```

**Useless enums**: Additionally, you can use the `Airport` enum to search for airports in code (as you type)! See `_generated_enum.py` in source.

```python
Airport.TAIPEI
              ╭─────────────────────────────────╮
              │ TAIPEI_SONGSHAN_AIRPORT         │
              │ TAPACHULA_INTERNATIONAL_AIRPORT │
              │ TAMPA_INTERNATIONAL_AIRPORT     │
              ╰─────────────────────────────────╯
```

## What's new
- `v2.0` – New (much more succinct) API, fallback support for Playwright serverless functions, and [documentation](https://aweirddev.github.io/flights)!
- `v2.2` - Now supports **local playwright** for sending requests.

## Cookies & consent
The EU region is a bit tricky to solve for now, but the fallback support should be able to handle it.

## Contributing
Contributing is welcomed! I probably won't work on this project unless there's a need for a major update, but boy howdy do I love pull requests.

***

## How it's made

The other day, I was making a chat-interface-based trip recommendation app and wanted to add a feature that can search for flights available for booking. My personal choice is definitely [Google Flights](https://flights.google.com) since Google always has the best and most organized data on the web. Therefore, I searched for APIs on Google.

> 🔎 **Search** <br />
> google flights api

The results? Bad. It seems like they discontinued this service and it now lives in the Graveyard of Google.

> <sup><a href="https://duffel.com/blog/google-flights-api" target="_blank">🧏‍♂️ <b>duffel.com</b></a></sup><br />
> <sup><i>Google Flights API: How did it work & what happened to it?</i></b>
>
> The Google Flights API offered developers access to aggregated airline data, including flight times, availability, and prices. Over a decade ago, Google announced the acquisition of ITA Software Inc. which it used to develop its API. **However, in 2018, Google ended access to the public-facing API and now only offers access through the QPX enterprise product**.

That's awful! I've also looked for free alternatives but their rate limits and pricing are just 😬 (not a good fit/deal for everyone).

<br />

However, Google Flights has their UI – [flights.google.com](https://flights.google.com). So, maybe I could just use Developer Tools to log the requests made and just replicate all of that? Undoubtedly not! Their requests are just full of numbers and unreadable text, so that's not the solution.

Perhaps, we could scrape it? I mean, Google allowed many companies like [Serpapi](https://google.com/search?q=serpapi) to scrape their web just pretending like nothing happened... So let's scrape our own.

> 🔎 **Search** <br />
> google flights ~~api~~ scraper pypi

Excluding the ones that are not active, I came across [hugoglvs/google-flights-scraper](https://pypi.org/project/google-flights-scraper) on Pypi. I thought to myself: "aint no way this is the solution!"

I checked hugoglvs's code on [GitHub](https://github.com/hugoglvs/google-flights-scraper), and I immediately detected "playwright," my worst enemy. One word can describe it well: slow. Two words? Extremely slow. What's more, it doesn't even run on the **🗻 Edge** because of configuration errors, missing libraries... etc. I could just reverse [try.playwright.tech](https://try.playwright.tech) and use a better environment, but that's just too risky if they added Cloudflare as an additional security barrier 😳.

Life tells me to never give up. Let's just take a look at their URL params...

```markdown
https://www.google.com/travel/flights/search?tfs=CBwQAhoeEgoyMDI0LTA1LTI4agcIARIDVFBFcgcIARIDTVlKGh4SCjIwMjQtMDUtMzBqBwgBEgNNWUpyBwgBEgNUUEVAAUgBcAGCAQsI____________AZgBAQ&hl=en
```

| Param | Content | My past understanding |
|-------|---------|-----------------------|
| hl    | en      | Sets the language.    |
| tfs   | CBwQAhoeEgoyMDI0LTA1LTI4agcIARID… | What is this???? 🤮🤮 |

I removed the `?tfs=` parameter and found out that this is the control of our request! And it looks so base64-y.

If we decode it to raw text, we can still see the dates, but we're not quite there — there's too much unwanted Unicode text.

Or maybe it's some kind of a **data-storing method** Google uses? What if it's something like JSON? Let's look it up.

> 🔎 **Search** <br />
> google's json alternative

> 🐣 **Result**<br />
> Solution: The Power of **Protocol Buffers**
>
> LinkedIn turned to Protocol Buffers, often referred to as **protobuf**, a binary serialization format developed by Google. The key advantage of Protocol Buffers is its efficiency, compactness, and speed, making it significantly faster than JSON for serialization and deserialization.

Gotcha, Protobuf! Let's feed it to an online decoder and see how it does:

> 🔎 **Search** <br />
> protobuf decoder

> 🐣 **Result**<br />
> [protobuf-decoder.netlify.app](https://protobuf-decoder.netlify.app)

I then pasted the Base64-encoded string to the decoder and no way! It DID return valid data!

![annotated, Protobuf Decoder screenshot](https://github.com/AWeirdDev/flights/assets/90096971/77dfb097-f961-4494-be88-3640763dbc8c)

I immediately recognized the values — that's my data, that's my query!

So, I wrote some simple Protobuf code to decode the data.

```protobuf
syntax = "proto3"

message Airport {
    string name = 2;
}

message FlightInfo {
    string date = 2;
    Airport dep_airport = 13;
    Airport arr_airport = 14;
}

message GoogleSucks {
    repeated FlightInfo = 3;
}
```

It works! Now, I won't consider myself an "experienced Protobuf developer" but rather a complete beginner.

I have no idea what I wrote but... it worked! And here it is, `fast-flights`.

***

<div align="center">

(c) 2024-2025 AWeirdDev, and other awesome people

</div>


================================================
FILE: docs/airports.md
================================================
# Airports

To search for an airport, you could use the `search_airports()` API:

```python
airport = search_airports("taipei")[0]
airport
# Airport.TAIPEI_SONGSHAN_AIRPORT
```

If you're unfamiliar with those 3-letter airport codes (such as "MYJ" for Matsuyama, "TPE" for Taipei, "LAX" for Los Angeles, etc.), you could pass in an `Airport` enum to a `FlightData` object:

```python
taipei = search_airports("taipei")[0]
los = search_airports("los angeles")[0]

filter = create_filter(
    flight_data=[
        FlightData(
            date="2025-01-01",
            from_airport=taipei,
            to_airport=los
        )
    ],
    ...
)
```

I love airports. Navigating them was like an adventure when I was a kid. I really thought that airports have everything in them, I even drew an entire airport containing (almost) a city at this point... naively.


================================================
FILE: docs/fallbacks.md
================================================
# Fallbacks
Just in case anything goes wrong, we've added falbacks extending Playwright serverless functions:

```python
get_flights(
    ..., 
    fetch_mode="fallback"  # common/fallback/force-fallback
)

# ...or:

get_fights_from_filter(
    filter, 
    mode="fallback"  # common/fallback/force-fallback
)
```

There are a few modes for fallbacks:

- `common` – This uses the standard scraping process.
- `fallback` – Enables a fallback support if the standard process fails.
- `force-fallback` – Forces using the fallback.

Some flight request data are displayed upon client request, meaning it's not possible for traditional web scraping. Therefore, if we used [Playwright](https://try.playwright.tech), which uses Chromium (a browser), and fetched the inner HTML, we could make the original scraper work again! Magic :sparkles:


================================================
FILE: docs/filters.md
================================================
# :material-filter: Filters
Filters are used to generate the `tfs` query parameter. In short, you make queries with filters.

With the new API, there's no need to use the `create_filter()` function, as you can use `get_flights()` and add the filter parameters directly.

```python
get_flights(..., fetch_mode="fallback")

# is equivalent to:

filter = create_filter(...)
get_flights_from_filter(filter, mode="fallback")
```

## FlightData
This specifies the general flight data: the date, departure & arrival airport, and the maximum number of stops (untested).

```python
data = FlightData(
    date="2025-01-01", 
    from_airport="TPE", 
    to_airport="MYJ", 
    airlines=["DL", "AA", "STAR_ALLIANCE"], # optional
    max_stops=10  # optional
)
```

Note that for `round-trip` trips, you'll need to specify more than one `FlightData` object for the `flight_data` parameter.

The values in `airlines` has to be a valid 2 letter IATA airline code, case insensitive. They can also be one of `SKYTEAM`, `STAR_ALLIANCE` or `ONEWORLD`. Note that the server side currently ignores the `airlines` parameter added to the `FlightData`s of all the flights which is not the first flight. In other words, if you have two `FlightData`s for a `round-trip` trip: JFK-MIA and MIA-JFK, and you add `airlines` parameter to both `FlightData`s, only the first `airlines` will be considered for the whole search. So technically `airlines` could be a better fit as a parameter for `TFSData` but adding to `FlightData` is the correct usage because if the backend changes and brings more flexibility to filter with different airlines for different flight segments in the future, which it should, this will come in handy.

## Trip
Either one of:

- `round-trip`
- `one-way`
- :material-alert: `multi-city` (unimplemented)

...can be used.

If you're using `round-trip`, see [FlightData](#flightdata).

## Seat
Now it's time to see who's the people who got $$$ dollar signs in their names. Either one of:

- `economy`
- `premium-economy`
- `business`
- `first`

...can be used, sorted from the least to the most expensive.

## Passengers
A family trip? No problem. Just tell us how many adults, children & infants are there.

There are some checks made, though:

- The sum of `adults`, `children`, `infants_in_seat` and `infants_on_lap` must not exceed `9`.
- You must have at least one adult per infant on lap (which frankly, is easy to forget).

```python
passengers = Passengers(
    adults=2,
    children=1,
    infants_in_seat=0,
    infants_on_lap=0
)
```

## Example
Here's a simple example on how to create a filter:

```python
filter: TFSData = create_filter(
    flight_data=[
        FlightData(
            date="2025-01-01",
            from_airport="TPE",
            to_airport="MYJ",
        )
    ],
    trip="round-trip",
    passengers=Passengers(adults=2, children=1, infants_in_seat=0, infants_on_lap=0),
    seat="economy",
    max_stops=1,
)

filter.as_b64()  # Base64-encoded (bytes)
filter.to_string()  # Serialize to string
```


================================================
FILE: docs/index.md
================================================
# :material-airplane-search: Fast Flights
A fast, robust Google Flights scraper (API) for Python. (Probably)

`fast-flights` uses Base64-encoded [Protobuf](https://developers.google.com/protocol-buffers) strings to generate the **`tfs` query parameter**, which stores all the information for a lookup request. We then parse the HTML content and extract the info we need using `selectolax`.

```sh
pip install fast-flights
```

## Getting started
Here's `fast-flights` in 3 steps:

1. **Import** the package
2. Add the **filters**
3. **Search** for flights

How simple is that? (...and beginner-friendly, too!)

```python
from fast_flights import FlightData, Passengers, Result, get_flights

result: Result = get_flights(
    flight_data=[
        FlightData(date="2025-01-01", from_airport="TPE", to_airport="MYJ")# (1)!
    ],
    trip="one-way",# (2)!
    seat="economy",# (3)!
    passengers=Passengers(adults=2, children=1, infants_in_seat=0, infants_on_lap=0),# (4)!
    fetch_mode="fallback",#(5)!
)

print(result)
```

1. :material-airport: This specifies the (desired) date of departure for the outbound flight. Make sure to change the date!
2. :fontawesome-solid-person-walking-luggage: This specifies the trip type (`round-trip` or `one-way`). Note that `multi-city` is **not yet** supported. Note that if you're having a `round-trip`, you need to add more than one item of flight data (in other words, 2+).
3. :material-seat: Money-spending time! This specifies the seat type, which is `economy`, `premium-economy`, `business`, or `first`.
4. :fontawesome-solid-people-line: Nice interface, eh? This specifies the number of a specific passenger type.
5. :fontawesome-solid-person-falling: Sometimes, the data is built on demand on the client-side, while the core of `fast-flights` is built around scrapers from the ground up. We support fallbacks that run Playwright serverless functions to fetch for us instead. You could either specify `common` (default), `fallback` (recommended), or `force-fallback` (100% serverless Playwright). You do not need to install Playwright in order for this to work.

## How it's made

The other day, I was making a chat-interface-based trip recommendation app and wanted to add a feature that can search for flights available for booking. My personal choice is definitely [Google Flights](https://flights.google.com) since Google always has the best and most organized data on the web. Therefore, I searched for APIs on Google.

> 🔎 **Search** <br />
> google flights api

The results? Bad. It seems like they discontinued this service and it now lives in the Graveyard of Google.

> <sup><a href="https://duffel.com/blog/google-flights-api" target="_blank">🧏‍♂️ <b>duffel.com</b></a></sup><br />
> <sup><i>Google Flights API: How did it work & what happened to it?</i></b>
>
> The Google Flights API offered developers access to aggregated airline data, including flight times, availability, and prices. Over a decade ago, Google announced the acquisition of ITA Software Inc. which it used to develop its API. **However, in 2018, Google ended access to the public-facing API and now only offers access through the QPX enterprise product**.

That's awful! I've also looked for free alternatives but their rate limits and pricing are just 😬 (not a good fit/deal for everyone).

<br />

However, Google Flights has their UI – [flights.google.com](https://flights.google.com). So, maybe I could just use Developer Tools to log the requests made and just replicate all of that? Undoubtedly not! Their requests are just full of numbers and unreadable text, so that's not the solution.

Perhaps, we could scrape it? I mean, Google allowed many companies like [Serpapi](https://google.com/search?q=serpapi) to scrape their web just pretending like nothing happened... So let's scrape our own.

> 🔎 **Search** <br />
> google flights <s>api</s> scraper pypi

Excluding the ones that are not active, I came across [hugoglvs/google-flights-scraper](https://pypi.org/project/google-flights-scraper) on Pypi. I thought to myself: "aint no way this is the solution!"

I checked hugoglvs's code on [GitHub](https://github.com/hugoglvs/google-flights-scraper), and I immediately detected "playwright," my worst enemy. One word can describe it well: slow. Two words? Extremely slow. What's more, it doesn't even run on the **🗻 Edge** because of configuration errors, missing libraries... etc. I could just reverse [try.playwright.tech](https://try.playwright.tech) and use a better environment, but that's just too risky if they added Cloudflare as an additional security barrier 😳.

Life tells me to never give up. Let's just take a look at their URL params...

```markdown
https://www.google.com/travel/flights/search?tfs=CBwQAhoeEgoyMDI0LTA1LTI4agcIARIDVFBFcgcIARIDTVlKGh4SCjIwMjQtMDUtMzBqBwgBEgNNWUpyBwgBEgNUUEVAAUgBcAGCAQsI____________AZgBAQ&hl=en
```

| Param | Content | My past understanding |
|-------|---------|-----------------------|
| hl    | en      | Sets the language.    |
| tfs   | CBwQAhoeEgoyMDI0LTA1LTI4agcIARID… | What is this???? 🤮🤮 |

I removed the `?tfs=` parameter and found out that this is the control of our request! And it looks so base64-y.

If we decode it to raw text, we can still see the dates, but we're not quite there — there's too much unwanted Unicode text.

Or maybe it's some kind of a **data-storing method** Google uses? What if it's something like JSON? Let's look it up.

> 🔎 **Search** <br />
> google's json alternative

> 🐣 **Result**<br />
> Solution: The Power of **Protocol Buffers**
>
> LinkedIn turned to Protocol Buffers, often referred to as **protobuf**, a binary serialization format developed by Google. The key advantage of Protocol Buffers is its efficiency, compactness, and speed, making it significantly faster than JSON for serialization and deserialization.

Gotcha, Protobuf! Let's feed it to an online decoder and see how it does:

> 🔎 **Search** <br />
> protobuf decoder

> 🐣 **Result**<br />
> [protobuf-decoder.netlify.app](https://protobuf-decoder.netlify.app)

I then pasted the Base64-encoded string to the decoder and no way! It DID return valid data!

![annotated, Protobuf Decoder screenshot](https://github.com/AWeirdDev/flights/assets/90096971/77dfb097-f961-4494-be88-3640763dbc8c)

I immediately recognized the values — that's my data, that's my query!

So, I wrote some simple Protobuf code to decode the data.

```protobuf
syntax = "proto3"

message Airport {
    string name = 2;
}

message FlightInfo {
    string date = 2;
    Airport dep_airport = 13;
    Airport arr_airport = 14;
}

message GoogleSucks {
    repeated FlightInfo = 3;
}
```

It works! Now, I won't consider myself an "experienced Protobuf developer" but rather a complete beginner.

I have no idea what I wrote but... it worked! And here it is, `fast-flights`.


## Contributing

Feel free to contribute! Though I won't be online that often, I'll try my best to answer all the whats, hows & WTFs.

:heart: Acknowledgements:

- @d2x made their first contribution in #7
- @PTruscott made their first contribution in #19
- @artiom-matvei made their first contribution in #20
- @esalonico fixed v2.0 currency issues in #25
- @NickJLange helped add a LICENSE file in #38
- @Lim0H (#39) and @andreaiorio (#41) fixed `primp` client issues.
- @kiinami (#43) added local Playwright support



================================================
FILE: docs/local.md
================================================
# Local Playwright

In case the Playwright serverless functions are down or you prefer not to use them, you can run the Playwright server locally and request against that.

1. Install this package with the dependencies needed for Playwright:

```bash
pip install fast-flights[local]
```

2. Install the Playwright browser:

```bash
python -m playwright install chromium # or `python -m playwright install` if you want to install all browsers
```

3. Now you can use the `fetch_mode="local"` parameter in `get_flights`:

```python
get_flights(
    ...,
    fetch_mode="local"  # common/fallback/force-fallback/local
)

# ...or:

get_fights_from_filter(
    filter,
    mode="local"  # common/fallback/force-fallback/local
)
```


