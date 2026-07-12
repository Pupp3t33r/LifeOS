namespace LifeOS.Money.Api.Domain;

/// The physical dimension of a quantity on a spending or estimate line (ADR-0036). A line
/// carries a magnitude (<see cref="Line.Quantity"/>) plus one of these dimensions; the
/// display unit SYMBOL (kg/lb/L/gal/m/ft) is a pure client rendering of (dimension × the
/// owner's <see cref="UnitSystem"/>) and is never stored or converted by Money.
/// <see cref="Pieces"/> renders no symbol (a bare count); the others render one symbol
/// chosen by the client from the active unit system. Serialized as its underlying integer
/// on the wire (STJ default), like the service's other directly-embedded enums.
public enum UnitDimension {
    Pieces,
    Mass,
    Volume,
    Length,
}
