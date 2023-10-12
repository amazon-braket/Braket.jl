@enum QueueType Normal Priority
QueueTypeDict = Dict("Normal"=>Normal, "Priority"=>Priority)
QueueType(s::String) = QueueTypeDict[s]

struct QueueDepthInfo
    quantum_tasks::Dict{QueueType, String}
    jobs::String
end
Base.:(==)(ix::QueueDepthInfo, iy::QueueDepthInfo) = (ix.jobs == iy.jobs && ix.quantum_tasks == iy.quantum_tasks) 

mutable struct QuantumTaskQueueInfo
    queue_type::QueueType
    queue_position::String
    message::String
end
QuantumTaskQueueInfo(queue_type::QueueType) = QuantumTaskQueueInfo(queue_type, "", "")

mutable struct HybridJobQueueInfo
    queue_position::String
    message::String
end
HybridJobQueueInfo() = HybridJobQueueInfo("", "")
