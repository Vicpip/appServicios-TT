"""Small display-formatting helpers shared by the PDF services."""


def fmt_darkness(value: float | int | None, empty: str = "-") -> str:
    """Darkness level as text: ``18`` for whole values, ``18.5`` otherwise."""
    if value is None:
        return empty
    as_float = float(value)
    return str(int(as_float)) if as_float.is_integer() else str(as_float)
