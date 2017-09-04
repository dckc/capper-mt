exports (NotNull)

def NotNull.coerce(specimen, ej) as DeepFrozen:
    if (specimen == null) { throw.eject(ej, null)}
    return null
