mutable struct LocalJob
    o::Py
    LocalJob(o::Py) = new(o)
    LocalJob(device::String; kwargs...) = new(local_job.LocalQuantumJob.create(device; kwargs...))
end
Py(j::LocalJob) = getfield(j, :o)
Base.getproperty(j::LocalJob, s::Symbol)         = pyconvert(Any, getproperty(Py(j), s))
Base.getproperty(j::LocalJob, s::AbstractString) = pyconvert(Any, getproperty(Py(j), s))
Braket.arn(j::LocalJob)    = j.arn
Braket.name(j::LocalJob)   = j.name
Braket.state(j::LocalJob)  = pyconvert(String, Py(j).state())
Braket.cancel(j::LocalJob) = Py(j).cancel()
Braket.result(j::LocalJob) = Py(j).result()
Braket.download_result(j::LocalJob, extract_to=nothing) = Py(j).download_result(extract_to)
Braket.logs(j::LocalJob; wait::Bool=false, poll_interval_seconds::Int=5) = j.logs(wait=wait, poll_interval_seconds=poll_interval_seconds)
