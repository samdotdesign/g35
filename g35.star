"""
Applet: G35
Summary: Clinton-Washington G
Description: Train arrival times for the Clinton-Washington station of NYC's G train.
Author: samdotdesign
"""

load("cache.star", "cache")
load("encoding/json.star", "json")
load("http.star", "http")
load("render.star", "render")
load("time.star", "time")

MTA_API_URL = "https://mta-api-ochre.vercel.app/by-id/G35"
CACHE_TTL = 600  # Cache data for 10 minutes

# Adjustable padding values
DIRECTION_PADDING = dict(top = 2, right = 0, bottom = 1, left = 2)
TIME_PADDING = dict(top = -2, right = 3, bottom = 0, left = 0)
TIMES_ROW_PADDING = dict(top = 0, right = 0, bottom = 0, left = 2)

def main():
    cached_data = cache.get("train_data")
    api_error = None

    rep = http.get(MTA_API_URL, ttl_seconds = 60)
    if rep.status_code != 200:
        api_error = "HTTP Error: {}".format(rep.status_code)
    else:
        data = rep.json()
        if validate_data(data):
            cache.set("train_data", json.encode(data), ttl_seconds = CACHE_TTL)
            cached_data = json.encode(data)
        else:
            api_error = "Invalid data format"

    if cached_data:
        data = json.decode(cached_data)
    elif api_error:
        return render_error(api_error)
    else:
        return render_error("No data available")

    station_data = data["data"][0]
    northbound = station_data.get("N", [])[:3]  # Get up to 3 northbound trains
    southbound = station_data.get("S", [])[:3]  # Get up to 3 southbound trains

    return render.Root(
        child = render.Column(
            expanded = True,
            main_align = "space_between",
            cross_align = "start",
            children = [
                render.Column(
                    expanded = True,
                    main_align = "start",
                    cross_align = "start",
                    children = [
                        direction_times("COURT SQ", northbound),
                        direction_times("CHURCH AV", southbound),
                    ],
                ),
                render_api_status(api_error),
            ],
        ),
    )

def validate_data(data):
    if type(data) != "dict":
        return False
    if "data" not in data or type(data["data"]) != "list":
        return False
    if len(data["data"]) == 0:
        return False
    if type(data["data"][0]) != "dict":
        return False
    if "N" not in data["data"][0] and "S" not in data["data"][0]:
        return False
    return True

def render_error(message):
    return render.Root(
        child = render.WrappedText(message, color = "#FF0000"),
    )

def render_api_status(error):
    if error:
        return render.Text("!", color = "#FF0000", font = "tb-8")
    else:
        return render.Text("", font = "tb-8")  # Empty text for normal operation

def format_time(train):
    arrival_time = time.parse_time(train["time"])
    minutes_until = int((arrival_time - time.now()).minutes)
    return max(0, minutes_until)  # Ensure non-negative times

def compact_text(text, font = "tb-8", color = "#FFF"):
    words = text.split()
    text_elements = []
    for i, word in enumerate(words):
        text_elements.append(render.Text(word, font = font, color = color))
        if i < len(words) - 1:  # Don't add space after the last word
            text_elements.append(render.Box(width = 2, height = 1))  # 2px wide space
    return render.Row(children = text_elements)

def direction_text(direction):
    return render.Padding(
        pad = (DIRECTION_PADDING["left"], DIRECTION_PADDING["top"], DIRECTION_PADDING["right"], DIRECTION_PADDING["bottom"]),
        child = compact_text(direction, font = "CG-pixel-4x5-mono", color = "#6CBE45"),
    )

def time_text(time):
    return render.Padding(
        pad = (TIME_PADDING["left"], TIME_PADDING["top"], TIME_PADDING["right"], TIME_PADDING["bottom"]),
        child = render.Row(
            children = [
                render.Text(
                    "{}".format(time),
                    color = "#FFF",
                    font = "Dina_r400-6",
                ),
                render.Padding(
                    pad = (0, 1, 0, 0),  # Move 'm' down by 1 pixel
                    child = render.Text(
                        "m",
                        color = "#FFF",
                        font = "tb-8",
                    ),
                ),
            ],
        ),
    )

def direction_times(direction, trains):
    times = [format_time(train) for train in trains if format_time(train) > 0]
    return render.Column(
        children = [
            direction_text(direction),
            render.Padding(
                pad = (TIMES_ROW_PADDING["left"], TIMES_ROW_PADDING["top"], TIMES_ROW_PADDING["right"], TIMES_ROW_PADDING["bottom"]),
                child = render.Row(
                    children = [time_text(t) for t in times],
                ),
            ),
        ],
    )
