abstract type ErrorMitigation end

struct DeBias <: ErrorMitigation end

ir(db::DeBias) = [Debias(StructTypes.defaults(Debias)[:type])]
